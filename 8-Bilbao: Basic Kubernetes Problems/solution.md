# Description
There's a Kubernetes Deployment with an Nginx pod and a Load Balancer declared in the manifest.yml file. The pod is not coming up. Fix it so that you can access the Nginx container through the Load Balancer.
# Solution
The manifest has two issues preventing the pod from being scheduled:
(1. The nodeSelector is looking for a label (disk=ssd) that doesn't exist on any node in the cluster.) # Initial thought was to add the label to a node, but instead we removed the nodeSelector to allow scheduling on any available node.
2. The memory request for the container is set to 2000Mi, which is too high for the available node capacity.
## Inspect the pod status
```bash
kubectl get pods     # check if the pod is running
kubectl describe pod nginx-pod-xxxxx    # describe the pod to see events and errors
```
## Inspect the deployment status
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
## Check node status
```bash
kubectl get nodes    # check if the nodes are ready
kubectl describe node <node-name>    # describe the node to see if there are any issues
```
## Deployment Manifest Review
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
            memory: 2000Mi # The initial request was too high for the node capacity
      nodeSelector:
        # disk: ssd --- Initially, the nodeSelector was looking for a label that didn't exist on any node
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

