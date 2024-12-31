# Installing
The following directories all have somewhat different installation methods, review README.md in each directory.

Trying to keep installs sane between
- kustomize
- helm

I'd love to get everything under kustomize, however some Helm charts dont 'includeCRDs' properly (cert-manager)

# System Components

Install order below works:
- metrics-server: components and install for kubelet metrics server
- 1password: 1password operator for mirroring 1password to native k8s secrets
- metal-lb: DHCP based LB for handing out IP Addresses to LoadBalancer objects
- ingress-nginx: Community driven NGINX install on k8s for frontend
- cert-manager: LetsEncrypt integration for certificates

## Monitoring
Grafana Prometheus for easy monitoring dashboards and metrics scraping.

- monitoring: contains installation logic for both.. this is a bit more custom (jsonnet)

## Argo
Install Argo Workflows, perhaps CD in the future?
