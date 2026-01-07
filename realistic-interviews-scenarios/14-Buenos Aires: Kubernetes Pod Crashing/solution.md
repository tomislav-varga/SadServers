# Solution for Buenos Aires: Kubernetes Pod Crashing
## Description:
There are two pods: "logger" and "logshipper" living in the default namespace. Unfortunately, logshipper has an issue (crashlooping) and is forbidden to see what logger is trying to say. Could you help fix Logshipper?

Do not change the K8S definition of the logshipper pod. Use "sudo".

Because k8s takes a minute or two to change the pod state initially, the check for the scenario is made to fail in the first two minutes. 

## Problem Analysis
Checking the status of the pod using `kubectl describe pods logshipper-597f84bf4f-6ssjq` reveals that the logshipper pod is in a CrashLoopBackOff state.
```bash
Events:
  Type     Reason          Age                   From               Message
  ----     ------          ----                  ----               -------
  Normal   Scheduled       638d                  default-scheduler  Successfully assigned default/logshipper-597f84bf4f-6ssjq to node1
  Normal   Pulled          638d (x5 over 638d)   kubelet            Container image "logshipper:v3" already present on machine
  Normal   Created         638d (x5 over 638d)   kubelet            Created container logshipper
  Normal   Started         638d (x5 over 638d)   kubelet            Started container logshipper
  Warning  BackOff         638d (x9 over 638d)   kubelet            Back-off restarting failed container logshipper in pod logshipper-597f84bf4f-6ssjq_default(5256275f-86c4-4a44-bb49-0123cb010748)
  Normal   SandboxChanged  2m50s                 kubelet            Pod sandbox changed, it will be killed and re-created.
  Normal   Pulled          79s (x4 over 2m49s)   kubelet            Container image "logshipper:v3" already present on machine
  Normal   Created         79s (x4 over 2m49s)   kubelet            Created container logshipper
  Normal   Started         79s (x4 over 2m49s)   kubelet            Started container logshipper
  Warning  BackOff         23s (x12 over 2m46s)  kubelet            Back-off restarting failed container logshipper in pod logshipper-597f84bf4f-6ssjq_default(5256275f-86c4-4a44-bb49-0123cb010748)
  ```
The logs of the pod show that it is crashing because of an error in the logshipper container. The error message is "Exception when calling CoreV1 Api->read_namespaced_pod_log: (403) 
Reason: Forbidden". This error is due to the lack of permissions to access the logs.
```bash
sudo kubectl logs logshipper-597f84bf4f-6ssjq
Exception when calling CoreV1Api->read_namespaced_pod_log: (403)
Reason: Forbidden
HTTP response headers: HTTPHeaderDict({'Audit-Id': '1a4c980e-35b2-4c0e-b202-7f0e275c343e', 'Cache-Control': 'no-cache, private', 'Content-Type': 'application/json', 'X-Content-Type-Options': 'nosniff', 'Date': 'Wed, 07 Jan 2026 03:17:36 GMT', 'Content-Length': '352'})
HTTP response body: {"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure","message":"pods \"logger-6f7fb76c9f-4jk77\" is forbidden: User \"system:serviceaccount:default:logshipper-sa\" cannot get resource \"pods/log\" in API group \"\" in the namespace \"default\"","reason":"Forbidden","details":{"name":"logger-6f7fb76c9f-4jk77","kind":"pods"},"code":403}
```
### Root Cause
**Insufficient RBAC Permissions**: The service account `logshipper-sa` does not have the necessary permissions to read pod logs in the default namespace.

## Solution
To resolve the issue, we need to create a Role with the necessary permissions and bind it to the `logshipper-sa` service account using a RoleBinding.
1. Create a Role that allows reading pod logs:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: logshipper-role
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
````
2. Create a RoleBinding to bind the Role to the `logshipper-sa` service account:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: logshipper-binding
  namespace: default
subjects:
  - kind: ServiceAccount
    name: logshipper-sa
    namespace: default
roleRef:
  kind: Role
  name: logshipper-role
  apiGroup: rbac.authorization.k8s.io
```
3. Apply the Role and RoleBinding using kubectl:
```bash
sudo kubectl apply -f logshipper-role.yaml
sudo kubectl apply -f logshipper-binding.yaml
```
4. Delete the crashing logshipper pod to allow it to be recreated with the new permissions:
```bash
sudo kubectl delete pod logshipper-597f84bf4f-6ssjq
```
## Verification
After applying these configurations, the logshipper pod should have the necessary permissions to read the logs from the logger pod. You can verify this by checking the status of the logshipper pod again:
```bash
sudo kubectl get pods -l app=logshipper --no-headers -o json | jq -r '.items[] | "\(.status.containerStatuses[0].ready)"'
```
It should return `true`, indicating that the logshipper pod is running successfully without crashing.