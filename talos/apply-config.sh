#!/bin/bash -e

NODE_IP=${1}                    # The IP Address of the node to configure
CONFIG_FILE="${2:-worker.yaml}" # The config file within outputs directory to pass to the node

# Consts
OUTPUT_DIR="./config"

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
  --file ${OUTPUT_DIR}/${CONFIG_FILE}
