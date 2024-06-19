#!/bin/bash

# Inputs
NODE_IP=${1}
KUBECONFIG_FILE=${2:-kubeconfig}

# Consts
OUTPUT_DIR="./config"

function sanity() {
  if [[ -z $NODE_IP ]]; then
    echo "ERROR: Please include NODE_IP as first argument. Exiting."
    exit 1
  fi
}
sanity

# Download Kubeconfig
# NOTE: This downloads the kubeconfig to a file named $KUBECONFIG_FILE
talosctl \
    --talosconfig=$OUTPUT_DIR/talosconfig \
    --nodes $NODE_IP \
    --endpoints $NODE_IP \
    kubeconfig ${OUTPUT_DIR}/${KUBECONFIG_FILE}