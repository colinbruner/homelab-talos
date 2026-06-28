#!/bin/bash
set -euo pipefail

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

IMAGE="ghcr.io/siderolabs/installer"

usage() {
    echo "Usage: $0 -t <control|worker> -n <node-ip> -v <version> [-y] [-w]" 1>&2
    echo "" 1>&2
    echo "  -t  Node type: control or worker" 1>&2
    echo "  -n  Node IP address (e.g. 192.168.10.31)" 1>&2
    echo "  -v  Talos version (e.g. v1.9.4)" 1>&2
    echo "  -y  Skip confirmation prompt (non-interactive mode)" 1>&2
    echo "  -w  No-wait mode: omit --wait/--debug (for slow nodes that drop the watch with too_many_pings); poll node status manually afterward" 1>&2
    echo "" 1>&2
    echo "Environment variables:" 1>&2
    echo "  TALOS_UPGRADE_YES=1  Same as -y (skip confirmation)" 1>&2
    exit 1
}

# Non-interactive mode: flag or env var
AUTO_APPROVE="${TALOS_UPGRADE_YES:-0}"
NO_WAIT=0

while getopts ":t:n:v:yw" o; do
    case "${o}" in
        t)
            t=${OPTARG}
            ;;
        n)
            n=${OPTARG}
            ;;
        v)
            v=${OPTARG}
            ;;
        y)
            AUTO_APPROVE=1
            ;;
        w)
            NO_WAIT=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${t:-}" ] || [ -z "${n:-}" ] || [ -z "${v:-}" ]; then
    usage
fi

# Validate node type
if [[ "$t" != "control" && "$t" != "worker" ]]; then
    echo "Error: node type must be 'control' or 'worker', got: '${t}'" 1>&2
    exit 1
fi

# Validate IP format
if ! [[ "$n" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: invalid IP address format: '${n}'" 1>&2
    exit 1
fi

# Validate version format
if ! [[ "$v" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must match format vX.Y.Z (e.g. v1.9.4), got: '${v}'" 1>&2
    exit 1
fi

# Pre-flight: ensure talosctl is available
if ! command -v talosctl &>/dev/null; then
    echo "Error: talosctl not found in PATH" 1>&2
    exit 1
fi

NODE_TYPE=$t
NODE_IP=$n
IMAGE_VERSION=$v

# Build command as an array for safe execution
CMD=(talosctl upgrade --nodes "${NODE_IP}" --image "${IMAGE}:${IMAGE_VERSION}")
if [[ "$NO_WAIT" != "1" ]]; then
    CMD+=(--wait --debug)
fi
if [[ "$NODE_TYPE" == "control" ]]; then
    # NOTE: --preserve is required for control plane upgrades
    CMD+=(--preserve)
fi

echo "Will run the following command:"
echo "${CMD[*]}"

if [[ "$AUTO_APPROVE" == "1" ]]; then
    echo "(non-interactive mode: auto-approved)"
else
    read -r -p "Continue? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Upgrade cancelled."
            exit 1
            ;;
    esac
fi

"${CMD[@]}"
if [[ "$NO_WAIT" == "1" ]]; then
    echo "No-wait upgrade issued for ${NODE_IP}. Poll status with:"
    echo "  kubectl get nodes -o wide | grep ${NODE_IP}"
fi
