# NGINX Ingress
The following is to deploy the nginx-ingress operator, not ingress-nginx.

## NGINX Ingress
NGINX Ingress is developed and maintained by NGINX team
- github: https://github.com/nginxinc/kubernetes-ingress
- docs: https://docs.nginx.com/nginx-ingress-controller/

### Install
```bash
# Set Version
$ NGINX_VERSION=v3.6.1
$ git clone https://github.com/nginxinc/kubernetes-ingress.git --branch $NGINX_VERSION

$ cd kubernetes-ingress

# Create NS/SA/RBAC
$ kubectl apply -f deployments/common/ns-and-sa.yaml
$ kubectl apply -f deployments/rbac/rbac.yaml

# Create ConfigMap/IngressClass
$ kubectl apply -f deployments/common/nginx-config.yaml
$ kubectl apply -f deployments/common/ingress-class.yaml

# Create CRDs
$ kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/$NGINX_VERSION/deploy/crds.yaml

# Deploy NGINX
$ kubectl apply -f deployments/deployment/nginx-ingress.yaml

# Deploy LoadBalancer Service
$ kubectl apply -f deployments/service/loadbalancer.yaml
```

## Links
- https://github.com/kubernetes/ingress-nginx/blob/main/docs/deploy/index.md
- https://github.com/kubernetes/ingress-nginx/blob/main/docs/deploy/baremetal.md
- https://github.com/morrismusumi/kubernetes/tree/main/clusters/homelab-k8s/apps/metallb-plus-nginx-ingress

