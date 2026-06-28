#!/bin/bash
# shellcheck disable=SC2034  # sourced library; variables are consumed by scripts that source it

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
# Single control-plane node used to orchestrate cluster-wide operations such as
# `talosctl upgrade-k8s`. Must be ONE node: passing a DNS name that resolves to all
# three control IPs makes upgrade-k8s hang. control-01 is the cluster's first control node.
DEFAULT_CONTROL_NODE="192.168.10.21"
DEFAULT_KUBERNETES_VERSION="1.36.2"
# Talos OS version — single source of truth for upgrade-talos.sh defaults and CI.
DEFAULT_TALOS_VERSION="v1.13.5"
