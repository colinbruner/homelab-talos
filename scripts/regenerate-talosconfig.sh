#!/bin/bash
set -euo pipefail

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. "${SCRIPTPATH}"/lib/consts.sh

TALOS_DIR="${HOME}/.talos"
TALOS_CONFIG_FILE="${TALOS_DIR}/config"

usage() {
  echo "Usage: $0 [-e <endpoint>]" 1>&2
  echo "" 1>&2
  echo "  -e  Cluster endpoint: IP or hostname (default: ${DEFAULT_CLUSTER_ENDPOINT})" 1>&2
  echo "" 1>&2
  echo "Regenerates config/talosconfig from config/secrets.yaml and installs it" 1>&2
  echo "to ~/.talos/config." 1>&2
  exit 1
}

ENDPOINT="${DEFAULT_CLUSTER_ENDPOINT}"

while getopts ":e:" o; do
  case "${o}" in
  e)
    ENDPOINT=${OPTARG}
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

# Pre-flight: ensure talosctl is available
if ! command -v talosctl &>/dev/null; then
  echo "Error: talosctl not found in PATH" 1>&2
  exit 1
fi

# Pre-flight: ensure secrets file exists
if [[ ! -f "${SECRETS_FILE}" ]]; then
  echo "Error: secrets file not found at ${SECRETS_FILE}" 1>&2
  exit 1
fi

echo "Regenerating talosconfig..."
echo "  Endpoint: ${ENDPOINT}"
echo "  Secrets:  ${SECRETS_FILE}"
echo "  Output:   ${TALOSCONFIG_FILE}"

talosctl gen config \
  --with-secrets="${SECRETS_FILE}" \
  --with-docs=false \
  --with-examples=false \
  --output-types talosconfig \
  --output "${TALOSCONFIG_FILE}" \
  --force \
  "${DEFAULT_CLUSTER_NAME}" \
  "https://${ENDPOINT}:6443"

echo "Setting endpoint to ${ENDPOINT}..."
talosctl --talosconfig="${TALOSCONFIG_FILE}" config endpoint "${ENDPOINT}"

echo "Installing to ${TALOS_CONFIG_FILE}..."
mkdir -p "${TALOS_DIR}"
cp "${TALOSCONFIG_FILE}" "${TALOS_CONFIG_FILE}"

echo ""
talosctl config info
