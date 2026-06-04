# Solution for Bengaluru: Kubernetes StatefulSet least known characteristic
## Description:
There's a Kubernetes cluster (created with "k3d") with two worker nodes and two pods on the node k3d-cluster-agent-0: a Deployment demo-deployment-... and a StatefulSet demo-statefulset-0. Their manifests are identical except for the different kind of K8s resource.

Make the node hosting the pods unavailable (it "goes down" or "crashes" without being deleted from k8s), for example with: docker stop k3d-mycluster-agent-0.

After waiting for about a minute (tolerationSeconds in the manifest is 30s, we shorten the K8S 5 minutes default so you don't have to wait so much, plus a grace period), both pods are marked as Terminating. While the Deployment pod is evicted and deployed onto the remaining available node k3d-cluster-agent-1, the StatefulSet demo-statefulset-0 is not (Why?).

Make the StatefulSet pod demo-statefulset-0 run on the available node.

## Problem Analysis
