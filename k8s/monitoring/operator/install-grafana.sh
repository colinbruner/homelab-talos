#!/bin/bash -e

GRAFANA_CHART_VERSION="v5.10.0"

# Switch to default ns
kubens monitoring

# Install/Upgrade Grafana
helm upgrade -i grafana-operator oci://ghcr.io/grafana/helm-charts/grafana-operator \
  --version $GRAFANA_CHART_VERSION

# Switch back to previous ns
kubens -