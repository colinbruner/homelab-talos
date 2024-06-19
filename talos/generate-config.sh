#!/bin/bash -e

###
# Bootstrap a single control plane Talos server
###

# Input
NODE_IP=${1} # NOTE: This is the IP Address the inital node comes online as
CLUSTER_NAME=${2:-homelab}

# Consts
OUTPUT_DIR="./config"
SECRETS_FILE="secrets.yaml"

mkdir -p $OUTPUT_DIR

function sanity() {
  if [[ -z $NODE_IP ]]; then
    echo "ERROR: Please include NODE_IP as first argument. Exiting."
    exit 1
  fi

  if [[ -f ${OUTPUT_DIR}/* ]] ; then
    echo "WARNING: Detected configuration files already exist in ${OUTPUT_DIR}. Please verify and rerun."
    exit 2
  fi
}

sanity

# Generate secrets seperately from config
talosctl gen secrets -o $OUTPUT_DIR/$SECRETS_FILE

# Generate configuration
talosctl gen config \
  --output $OUTPUT_DIR \
  --with-secrets="$OUTPUT_DIR/$SECRETS_FILE" \
  $CLUSTER_NAME \
  https://$NODE_IP:6443