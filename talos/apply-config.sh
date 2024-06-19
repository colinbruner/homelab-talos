#!/bin/bash -e

NODE_IP=${1} # NOTE: This is the IP Address the inital node comes online as

# Consts
OUTPUT_DIR="./config"
CONTROLPLANE_FILE="controlplane.yaml"

function sanity() {
  if [[ -z $NODE_IP ]]; then
    echo "ERROR: Please include NODE_IP as first argument. Exiting."
    exit 1
  fi
}
sanity

talosctl apply-config \
    --insecure \
    -n $NODE_IP \
    --file ${OUTPUT_DIR}/${CONTROLPLANE_FILE}