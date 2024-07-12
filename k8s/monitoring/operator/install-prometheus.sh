#!/bin/bash -e

# Docs: https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md

###
# Helm
###
#PROM_CHART_VERSION=61.3.1
#
#helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#helm repo update
#helm install kube-prometheus \
#  --values ./values/prom.yaml \
#  prometheus-community/kube-prometheus-stack

###
# The below code clones 'kube-prometheus' and installs all components excluding 
# 'grafana', which is installed separately.

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

pushd $SCRIPTPATH/
git clone https://github.com/prometheus-operator/kube-prometheus.git tmp; pushd tmp

function createCRDs() {
  # assumes root of cloned directory
  for file in manifests/setup/0*.yaml; do
    local crdResource=$(yq ".metadata.name" $file)
    # check if crd exists
    kubectl get $crdResource &>/dev/null
    if [[ $? != 0 ]]; then
      kubectl create -f $file
    else
      echo "CRD: '$crdResource' already exists. Continuing..."
    fi
  done
}

function applyRegexManifests() {
  local regexPath=$1
  # assumes root of cloned directory
  for file in $regexPath; do
    kubectl apply -f $file; 
  done
}

function cleanUp() {
  popd
  rm -rf $SCRIPTPATH/tmp/
}

###
# Main
###
trap cleanUp EXIT

createCRDs

applyRegexManifests "manifests/alertmanager-*.yaml"
applyRegexManifests "manifests/blackboxExporter-*.yaml"
applyRegexManifests "manifests/kube*.yaml"
applyRegexManifests "manifests/prometheus*.yaml"
