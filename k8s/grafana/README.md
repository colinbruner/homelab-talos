# Grafana Labs

## Install

### Operator
https://grafana.github.io/grafana-operator/docs/installation/kustomize/
```bash
# Grafana
$ kubectl create -f https://github.com/grafana/grafana-operator/releases/latest/download/kustomize-cluster_scoped.yaml

# Prometheus
$ kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml
```

### Application
```bash
# Create secrets
$ kubectl apply -f 1password.yaml

# Create grafana deployment
$ kubectl apply -f grafana.yaml

# Create ingress
$ kubectl apply -f ingress.yaml
```

## Dashboards
- https://github.com/DevOps-Nirvana/Grafana-Dashboards

## Cert Manager
The following is used to validate and approve cert-manager requests. A `certificaterequest` and `cert` object upon applying the [ingress.yaml](ingress.yaml) file.

```bash
$ cmctl status certificate grafana-tls
```
