#!/bin/bash

VERSION="v1.16.2"

# Install Helm Chart for cert-manager deployment and CRDs
helm repo add jetstack https://charts.jetstack.io --force-update
echo "Installing Cert-Manager via Helm. This takes sometime to complete..."
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version $VERSION \
  --set crds.enabled=true
