# Grafana Labs

## Install Operators
Operators are cluster scoped and installed in the default namespace. This organizes monitoring operators into a single 'default' namespace and allows for targeted namespace deployments of the actual applications.

Before installing, we need to create the monitoring namespace and initial secrets.
```bash
# Creates k8s namespace 'monitoring' for the following operators and pods to be deployed
$ kubectl -f apply manifests/namespace.yaml
# Creates Grafana app admin username/password as k8s secrets synced from 1Password
$ kubectl apply -f manifests/1password.yaml
```

### Grafana Operator
Running the following script will install the Grafana operator within the `default` namespace.
```bash
$ ./operator/install-grafana.sh
```
https://grafana.github.io/grafana-operator/docs/installation/helm/

### Prometheus Operator
Running the following script will install the Prometheus operator within the `default` namespace.
```bash
$ ./operator/install-prometheus.sh
```
https://prometheus-operator.dev/docs/api-reference/api/

## Configuring Monitoring Cluster
While we get a lot "for free" from the initial setup of Grafana and Prometheus operators, we still want to configure the cluster a bit further.
```bash
# Switch namespace to monitoring
$ kubens monitoring
###
# Configure Grafana
###
$ kubectl apply -f manifests/grafana.yaml
$ kubectl apply -f manifests/grafana-ingress.yaml
$ kubectl apply -f manifests/grafana-datasources.yaml
```

## Dashboards
- https://github.com/DevOps-Nirvana/Grafana-Dashboards

## Cert Manager
The following is used to validate and approve cert-manager requests. A `certificaterequest` and `cert` object upon applying the [ingress.yaml](ingress.yaml) file.

```bash
$ cmctl status certificate grafana-tls
```
