#!/bin/bash
set -euo pipefail

###
# Applies the host ingress firewall configuration to a single Talos node.
#
# Enables a default-block firewall policy with explicit allow rules for:
#   - All TCP/UDP from cluster LAN (192.168.10.0/24)
#   - All TCP/UDP from management LAN (192.168.1.0/24)
#   - TCP 9100 from pod CIDR (10.244.0.0/16) for node-exporter scraping
#
# Uses --mode=try: config applies for 90s then auto-reverts unless confirmed.
# To confirm, re-run this script (or re-apply manually) within that window.
###

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. "${SCRIPTPATH}"/lib/consts.sh

usage() {
  echo "Usage: $0 -n <node-ip> [-e <endpoint-ip>] [-y]" 1>&2
  echo "" 1>&2
  echo "  -n  Node IP address to configure (e.g. 192.168.10.31)" 1>&2
  echo "  -e  Endpoint IP to connect through (default: same as -n)" 1>&2
  echo "  -y  Skip confirmation prompt (non-interactive mode)" 1>&2
  exit 1
}

AUTO_APPROVE=0

while getopts ":n:e:y" o; do
  case "${o}" in
  n)
    n=${OPTARG}
    ;;
  e)
    e=${OPTARG}
    ;;
  y)
    AUTO_APPROVE=1
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "${n:-}" ]; then
  usage
fi

if ! [[ "$n" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid IP address format: '${n}'" 1>&2
  exit 1
fi

if ! command -v talosctl &>/dev/null; then
  echo "Error: talosctl not found in PATH" 1>&2
  exit 1
fi

if [[ ! -f "${TALOSCONFIG_FILE}" ]]; then
  echo "Error: talosconfig not found at ${TALOSCONFIG_FILE}" 1>&2
  exit 1
fi

NODE_IP=$n
ENDPOINT_IP=${e:-$n}

CMD=(talosctl patch mc
  --talosconfig "${TALOSCONFIG_FILE}"
  --endpoints "${ENDPOINT_IP}"
  --nodes "${NODE_IP}"
  --patch "@${FIREWALL_TEMPLATE}"
  --mode try)

echo "Will run the following command:"
echo "${CMD[*]}"
echo ""
echo "Firewall rules being applied:"
echo "  - Default: block all ingress"
echo "  - Allow: all TCP/UDP from 192.168.10.0/24 (cluster LAN)"
echo "  - Allow: all TCP/UDP from 192.168.1.0/24 (management LAN)"
echo "  - Allow: TCP 9100 from 10.244.0.0/16 (pod CIDR)"
echo ""
echo "NOTE: --mode=try applies for 90s then auto-reverts."
echo "      If connectivity is maintained, confirm by re-running this command."

if [[ "$AUTO_APPROVE" == "1" ]]; then
  echo "(non-interactive mode: auto-approved)"
else
  read -r -p "Continue? [y/N] " response
  case "$response" in
  [yY][eE][sS] | [yY])
    ;;
  *)
    echo "Cancelled."
    exit 1
    ;;
  esac
fi

"${CMD[@]}"

echo ""
echo "Config applied in try mode. You have 90 seconds to confirm."
echo "To confirm (make permanent), re-run:"
echo "  talosctl patch mc --talosconfig ${TALOSCONFIG_FILE} --nodes ${NODE_IP} --patch @${FIREWALL_TEMPLATE}"
echo ""
echo "To verify firewall is active (ingress chain with drop policy = active):"
echo "  talosctl --talosconfig ${TALOSCONFIG_FILE} -n ${NODE_IP} get nftableschains"
