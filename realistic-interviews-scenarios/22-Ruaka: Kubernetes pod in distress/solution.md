# Solution for Ruaka: Kubernetes pod in distress
## Description
A developer wants to deploy an open-source tool on Kubernetes. The tool unfortunately has limited documentation.

They built a helm chart and a container image. When the application is deployed, for some reason the server in Kubernetes doesn't seem to work but when the binary is started on their laptop/machine it works perfectly.

The application server is deployed by Helm. The command they used is: helm upgrade --install ruaka charts/ruaka.

Debug and help the developer find the issue. NOTE: Do not change or delete any current Helm field value in the chart, only add if needed.

Remember to give enough time to k8S after you apply a change before checking the solution.

Test: kubectl get pod shows the ruaka application pod up and running, while no Helm fields have been taken out from the applicaiton chart. 

## Problem Analysis
To analyze the problem, we first check the status of the pod using `kubectl get pods` and `kubectl describe pod <pod-name>`. We find that the liveness and readiness probes are failing with a `503 Service Unavailable` status code. This indicates that the application is not responding to the health checks resulting in the pod being restarted repeatedly.

```bash
Normal   Created                 74s (x2 over 87s)     kubelet            Created container ruaka
Normal   Killing                 74s                   kubelet            Container ruaka failed liveness probe, will be restarted
Normal   Started                 73s (x2 over 87s)     kubelet            Started container ruaka
Warning  Unhealthy               67s (x10 over 86s)    kubelet            Readiness probe failed: HTTP probe failed with statuscode: 503
Warning  Unhealthy               64s (x5 over 84s)     kubelet            Liveness probe failed: HTTP probe failed with statuscode: 503
```

Looking at the Helm chart values, we see that the liveness and readiness probes are defined as follows:
```yaml
livenessProbe:
  periodSeconds: 5
  terminationGracePeriodSeconds: 3
  httpGet:
    path: /healthz
    port: http

readinessProbe:
  periodSeconds: 5
  httpGet:
    path: /
    port: http
```
The liveness probe does not have an `initialDelaySeconds` configured, which means it starts checking the health of the application immediately after the container starts. The readiness probe also does not have an `initialDelaySeconds` configured. Since the application takes some time to initialize, the probes fail with a `503 Service Unavailable` status code before the application is ready to serve requests.
### Root Cause
**Missing Initial Delay for Probes**: The liveness and readiness probes do not have an `initialDelaySeconds` configured, which means they start checking the health of the application immediately after the container starts. Since the application takes some time to initialize, the probes fail with a `503 Service Unavailable` status code.

## Solution
First, let's add an `initialDelaySeconds`to the liveness probe in the values.yaml file to give the application enough time to start before the probe starts checking its health. We can set it to 30 seconds and see if the liveness probe starts passing.
```yaml
livenessProbe:
  periodSeconds: 5
  terminationGracePeriodSeconds: 3
  initialDelaySeconds: 30
  httpGet:
    path: /healthz
    port: http
```
The pod is in a running state but the readiness probe is still failing.
```bash
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  55s                default-scheduler  Successfully assigned default/ruaka-75b9697778-zjdwg to node1
  Normal   Pulled     54s                kubelet            Container image "localhost:5000/ruaka:v0.0.3" already present on machine
  Normal   Created    54s                kubelet            Created container ruaka
  Normal   Started    54s                kubelet            Started container ruaka
  Warning  Unhealthy  35s (x6 over 53s)  kubelet            Readiness probe failed: HTTP probe failed with statuscode: 503
```
Looking at the logs of the application, we see that the application is to ready to serve after a 21 second delay. This means that the readiness probe is starting to check the health of the application before it is ready to serve requests, which is why it is failing with a `503 Service Unavailable` status code.
```bash
k logs ruaka-6677659499-tm7ct
2026-02-13 03:35:37 connecting to the database...
2026-02-13 03:35:38 connected to database.
2026-02-13 03:35:38 listening on port :3333.
2026-02-13 03:35:44 load server configurations...
2026-02-13 03:35:54 warming up the cache...
2026-02-13 03:35:56 cache warmed with 215 entries.
2026-02-13 03:35:58 initialization complete, server ready.
2026-02-13 03:35:59 ruaka server is ready to serve! 🚀
```
We can add an `initialDelaySeconds` to the readiness probe as well to give the application enough time to initialize before the probe starts checking its health. We can set it to 25 seconds and see if the readiness probe starts passing.
```yaml
readinessProbe:
  periodSeconds: 5
  initialDelaySeconds: 25
  httpGet:
    path: /
    port: http
```
After applying the changes, we need to wait for the pod to restart and check the status of the probes again. We should see that both the liveness and readiness probes are passing, and the pod is in a healthy state.
```bash
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  47s   default-scheduler  Successfully assigned default/ruaka-9fbc78499-5g6jb to node1
  Normal  Pulled     46s   kubelet            Container image "localhost:5000/ruaka:v0.0.3" already present on machine
  Normal  Created    46s   kubelet            Created container ruaka
  Normal  Started    46s   kubelet            Started container ruaka
```
## Verification
Runnning the `check.sh` script returns `OK`. The pod is now in a healthy state with both the liveness and readiness probes passing successfully.