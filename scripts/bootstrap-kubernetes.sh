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

# Bootstrap k8s on Control Node
# https://www.talos.dev/v1.7/introduction/getting-started/#kubernetes-bootstrap
talosctl bootstrap \
  --talosconfig "$TALOSCONFIG_FILE" \
  -e "$NODE_IP" \
  -n "$NODE_IP"
