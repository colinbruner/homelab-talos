# Ingress NGINX

Community version, based on NGINX Open Source, maintained by the Kubernetes community with a commitment from NGINX teams
- github: https://github.com/kubernetes/ingress-nginx
- docs: https://kubernetes.github.io/ingress-nginx/

## Install
The following commands will install the NGINX Ingress controller via helm

```bash
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

$ helm repo update

$ helm install ingress-nginx \
  ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace ingress-nginx
```
