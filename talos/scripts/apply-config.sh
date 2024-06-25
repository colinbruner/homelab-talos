#!/bin/bash -e

###
# This applies a configuration file directly to a Talos control or worker node.
# The node is expected to be in a 'Ready' state in 'Maintenance' stage awiting configuration
###

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

usage() { echo "Usage: $0 [-t <control|worker>] [-e <endpoint>] [-n <name>]" 1>&2; exit 1; }

while getopts ":t:e:n:" o; do
    case "${o}" in
        t)
            t=${OPTARG}
            ((t == "control" || t == "worker")) || usage
            ;;
        e)
            e=${OPTARG}
            ;;
        n)
            n=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${t}" ] || [ -z "${e}" ] || [ -z "${n}" ]; then
    usage
fi

NODE_TYPE=$t
NODE_IP=$e
NODE_NAME=$n

if [[ $NODE_TYPE == "control" ]]; then
  talosctl apply-config \
    --insecure \
    -n $NODE_IP \
    --file ${OUTPUT_DIR}/${NODE_NAME}.yaml
else
  talosctl apply-config \
    --insecure \
    -n $NODE_IP \
    --file ${WORKER_OUTPUT_DIR}/${NODE_NAME}.yaml
fi