# Cert Manager
depends on:
- 1password operator

## Install

```bash
# Install Repo
$ helm repo add jetstack https://charts.jetstack.io --force-update

# Deploy
$ helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.1 \
  --set crds.enabled=true
```

## LetsEncrypt Integration
We create a k8s secret in 1password containing a cloudflare API token used to manipulate our target DNS zone.

```bash
# Deploy 1password -> k8s secret
$ kubectl apply -f secret.yaml

$ kubectl apply -f letsencrypt-staging.yaml
$ kubectl apply -f letsencrypt-prod.yaml
```

## Troubleshooting
The following are useful troubleshooting steps to gather error output when certificate is not showing as ready.
```bash
$ kubectl get cert
$ kubectl get certificaterequest
$ kubectl get order
$ kubectl get challenge

$ cmctl status certificate grafana-tls
```
