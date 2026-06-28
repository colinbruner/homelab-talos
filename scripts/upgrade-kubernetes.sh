#!/bin/bash
set -euo pipefail

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

usage() {
    echo "Usage: $0 -v <version> [-e <endpoint>] [-d] [-y]" 1>&2
    echo "" 1>&2
    echo "  -v  Kubernetes version (e.g. 1.32.0) — required" 1>&2
    echo "  -e  Single control-plane node (IP or hostname) to run the upgrade from (default: ${DEFAULT_CONTROL_NODE})" 1>&2
    echo "  -d  Dry-run mode (preview changes only)" 1>&2
    echo "  -y  Skip confirmation prompt (non-interactive mode)" 1>&2
    echo "" 1>&2
    echo "Environment variables:" 1>&2
    echo "  K8S_UPGRADE_YES=1  Same as -y (skip confirmation)" 1>&2
    exit 1
}

# Non-interactive mode: flag or env var
AUTO_APPROVE="${K8S_UPGRADE_YES:-0}"
DRY_RUN=0
NODE_ENDPOINT="${DEFAULT_CONTROL_NODE}"

while getopts ":v:e:dy" o; do
    case "${o}" in
        v)
            v=${OPTARG}
            ;;
        e)
            NODE_ENDPOINT=${OPTARG}
            ;;
        d)
            DRY_RUN=1
            ;;
        y)
            AUTO_APPROVE=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${v:-}" ]; then
    usage
fi

# Strip leading 'v' if provided — talosctl upgrade-k8s expects bare semver
v="${v#v}"

# Validate version format (X.Y.Z)
if ! [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must match format X.Y.Z (e.g. 1.32.0), got: '${v}'" 1>&2
    exit 1
fi

# Pre-flight: ensure talosctl is available
if ! command -v talosctl &>/dev/null; then
    echo "Error: talosctl not found in PATH" 1>&2
    exit 1
fi

VERSION=$v

# Build command as an array for safe execution
CMD=(talosctl --nodes "${NODE_ENDPOINT}" upgrade-k8s --to "${VERSION}")
if [[ "$DRY_RUN" == "1" ]]; then
    CMD+=(--dry-run)
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
