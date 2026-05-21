# Solution for Bilbao: Basic Kubernetes Problems
## Description
There's a Kubernetes Deployment with an Nginx pod and a Load Balancer declared in the manifest.yml file. The pod is not coming up. Fix it so that you can access the Nginx container through the Load Balancer.

## Problem Analysis
The manifest has two issues preventing the pod from being scheduled:
1. The nodeSelector is looking for a label (disk=ssd) that doesn't exist on any node in the cluster. 
Initial thought was to add the label to a node, but instead it's better to remove the nodeSelector to allow scheduling on any available node.
2. The memory request for the container is set to 2000Mi, which is too high for the available node capacity.
```bash
kubectl get deployments    # check if the deployment is created
kubectl describe deployment nginx-deployment    # describe the deployment to see if there are any issues
Name:             nginx-deployment-67699598cc-vb6cf
Namespace:        default
Priority:         0
Service Account:  default
Node:             <none>
Labels:           app=nginx
                  pod-template-hash=67699598cc
Annotations:      <none>
Status:           Pending
IP:
IPs:              <none>
Controlled By:    ReplicaSet/nginx-deployment-67699598cc
Containers:
  nginx:
    Image:      localhost:5000/nginx
    Port:       80/TCP
    Host Port:  0/TCP
    Limits:
      cpu:     100m
      memory:  2000Mi
    Requests:
      cpu:        100m
      memory:     2000Mi
    Environment:  <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-4lz5n (ro)
Conditions:
  Type           Status
  PodScheduled   False
Volumes:
  kube-api-access-4lz5n:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   Guaranteed
Node-Selectors:              disk=ssd
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  45s   default-scheduler  0/2 nodes are available: 1 Insufficient memory, 1 node(s) had untolerated taint {node.kubernetes.io/unreachable: }. preemption: 0/2 nodes are available: 1 No preemption victims found for incoming pod, 1 Preemption is not helpful for scheduling..
```
As seen in the events, one node has insufficient memory and the other node is unreachable due to a taint. This means that the pod cannot be scheduled on either node.

## Solution
To fix the issues, we need to:
1. Remove the nodeSelector from the manifest to allow scheduling on any available node.
2. Lower the memory request to a value that fits within the node's capacity, for example 500Mi.
To edit the manifest, we can run:
```bash
vim manifest.yml
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: localhost:5000/nginx
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: 2000Mi
            cpu: 100m
          requests:
            cpu: 100m
            memory: 500Mi  # The initial request of 2000Mi was too high for the node capacity. 
                            # The node has only 2048Mi total memory, so we need to lower this, e.g., to 500Mi.
      nodeSelector:
        # disk: ssd # The nodeSelector was looking for a label that didn't exist on any node
                    # Assigning to a node without the label made scheduling possible

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  clusterIP: 10.43.216.196
  type: LoadBalancer
```
After saving the changes, we can verify that the pod is now running:
```bash
kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-75db6cdd55-bfhkd   1/1     Running   0          3m36s
```
Finally, we can test access to the Nginx container with the curl command:
```bash
curl 10.43.216.196
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
The output confirms that we can access the Nginx container through the Load Balancer.
