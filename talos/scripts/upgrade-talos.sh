#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

usage() { echo "Usage: $0 [-t <control|worker>] [-n <node-ip>]" 1>&2; exit 1; }

while getopts ":t:n:v:" o; do
    case "${o}" in
        t)
            t=${OPTARG}
            ((t == "control" || t == "worker")) || usage
            ;;
        n)
            n=${OPTARG}
            ;;
        v)
            v=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${t}" ] || [ -z "${n}" ] || [ -z "${n}" ]; then
    usage
fi

## Args
NODE_TYPE=$t
NODE_IP=$n
IMAGE="ghcr.io/siderolabs/installer"
IMAGE_VERSION=$v

CMD="talosctl upgrade --wait --debug --nodes ${NODE_IP} --image ${IMAGE}:${IMAGE_VERSION}"
if [[ $NODE_TYPE == "control" ]]; then
    # NOTE: This is required for a single control node deployment
    CMD+=" --preserve"
fi

echo "Will run the following command:"
echo $CMD
read -r -p "Continue? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        $CMD
        ;;
    *)
        exit 1
        ;;
esac
