#!/bin/bash

###
# Files
###
OUTPUT_DIR="${SCRIPTPATH}/../config"
WORKER_OUTPUT_DIR="${SCRIPTPATH}/../config/workers"

TEMPLATES_DIR="${SCRIPTPATH}/../templates"
PATCHES_DIR="${SCRIPTPATH}/../patches"
VALUES_DIR="${SCRIPTPATH}/../values"

SECRETS_FILE="${OUTPUT_DIR}/secrets.yaml"
TALOSCONFIG_FILE="${OUTPUT_DIR}/talosconfig"
KUBECONFIG_FILE="${OUTPUT_DIR}/kubeconfig"

###
# Defaults
###
# These are cluster defaults when not provided.
DEFAULT_CLUSTER_NAME="homelab"
DEFAULT_CLUSTER_ENDPOINT="talos.bruner.lab"