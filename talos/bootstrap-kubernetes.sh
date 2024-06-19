#!/bin/bash -e

# Inputs
NODE_IP=${1} # NOTE: This is the IP Address the inital node comes online as
CLUSTER_NAME=${2:-homelab}

# Consts
OUTPUT_DIR="./config"
SECRETS_FILE="secrets.yaml"

function sanity() {
  if [[ -z $NODE_IP ]]; then
    echo "ERROR: Please include NODE_IP as first argument. Exiting."
    exit 1
  fi
}
sanity

# Bootstrap k8s on Control Node
# https://www.talos.dev/v1.7/introduction/getting-started/#kubernetes-bootstrap
talosctl bootstrap --talosconfig talosconfig -e $NODE_IP -n $NODE_IP
