#!/bin/bash

###
# Files
###
OUTPUT_DIR="${SCRIPTPATH}/../config"
WORKER_OUTPUT_DIR="${SCRIPTPATH}/../config/workers"

PATCHES_DIR="${SCRIPTPATH}/../patches"
NODES_DIR="${PATCHES_DIR}/nodes"

SECRETS_FILE="${OUTPUT_DIR}/secrets.yaml"
FIREWALL_TEMPLATE="${PATCHES_DIR}/firewall.yaml"
TALOSCONFIG_FILE="${OUTPUT_DIR}/talosconfig"
KUBECONFIG_FILE="${OUTPUT_DIR}/kubeconfig"

###
# Defaults
###
# These are cluster defaults when not provided.
DEFAULT_CLUSTER_NAME="homelab"
DEFAULT_CLUSTER_ENDPOINT="talos.bruner.lab"
DEFAULT_KUBERNETES_VERSION="1.35.1"
