#!/bin/bash -e

###
# This applies a configuration file directly to a Talos control or worker node.
# The node is expected to be in a 'Ready' state in 'Maintenance' stage awiting configuration
###

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

usage() { echo "Usage: $0 [-e <endpoint>] [-n <name>] [-b]" 1>&2; exit 1; }

EXTRA_ARGS=""
while getopts ":t:e:n:b" o; do
    case "${o}" in
        e)
            e=${OPTARG}
            ;;
        n)
            n=${OPTARG}
            ;;
        b)
            # During initial bootstrapping, --insecure must be passed
            EXTRA_ARGS="--insecure "
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${e}" ] || [ -z "${n}" ]; then
    usage
fi

NODE_IP=$e
NODE_NAME=$n

if [[ $NODE_NAME =~ control* ]]; then
  TARGET_OUTPUT_DIR="${OUTPUT_DIR}"
elif [[ $NODE_NAME =~ worker* ]]; then
  TARGET_OUTPUT_DIR="${WORKER_OUTPUT_DIR}"
else
  echo "Node name must start with 'control' or 'worker'. Got: ${NODE_NAME}"
  exit 1
fi

talosctl apply-config \
  -n $NODE_IP \
  $EXTRA_ARGS \
  --file ${TARGET_OUTPUT_DIR}/${NODE_NAME}.yaml
