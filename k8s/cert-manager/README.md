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

## Requesting a Certificate
Adding the following configuration to an ingress object will create a certificate with SANs matching the `hosts` array. NGINX will automatically pick up and serve this certificate for ingress into this endpoint.
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
...
spec:
  tls:
  - hosts:
    - grafana.colinbruner.com
    secretName: grafana-tls
...
```

## Troubleshooting
Understanding the flow of cert manager is important. There are innner working diagrams at the bottom of the page [here](https://cert-manager.io/docs/usage/certificate/) as well as just good docs and diagrams explaining the process.

With my limited knowledge, upon creating the referenced ingress object above, it's something like:
```
certificate -> certificaterequest -> order -> challenge
```
Where a `certificate` creates a `certificaterequest` which places an `order` which spawns a `challenge`. Upon the `challenge` (DNS, in my case) being complete, the `order` can be fulfilled and the `certificaterequest` granted and `certificate` obtained.

The following are useful troubleshooting steps to gather error output when certificate is not showing as ready.
```bash
$ kubectl get cert
$ kubectl get certificaterequest
$ kubectl get order
$ kubectl get challenge

$ cmctl status certificate <cert>
```