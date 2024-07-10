# Metrics Server
Referenced: https://www.talos.dev/v1.7/kubernetes-guides/configuration/deploy-metrics-server/

I'd prefer to download these files and check them in to my own repo. This makes referencing diffs easier and me feel a bit safer from the security side of things.

Ultimately, I'd probably self-host these from an internal HTTP endpoint and reference in Talos configurations via cluster.extraManifests

## Download
```bash
$ curl -O https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml
$ curl -O https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Install
```bash
$ kubectl apply -f standalone-install.yaml
$ kubectl apply -f components.yaml
```
