#!/bin/bash -e

# Consts
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. "${SCRIPTPATH}"/lib/consts.sh

usage() {
  echo "Usage: $0 [-e <endpoint>]" 1>&2
  exit 1
}

while getopts ":e:" o; do
  case "${o}" in
  e)
    e=${OPTARG}
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "${e}" ]; then
  usage
fi

NODE_IP=$e

# Download Kubeconfig
# NOTE: This downloads the kubeconfig to a file named $KUBECONFIG_FILE
talosctl \
  --talosconfig="$TALOSCONFIG_FILE" \
  --nodes="$NODE_IP" \
  --endpoints="$NODE_IP" \
  kubeconfig "${KUBECONFIG_FILE}"
