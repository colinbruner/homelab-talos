#!/bin/bash

IMAGE="ghcr.io/siderolabs/installer"
IMAGE_VERSION="v1.7.7"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

usage() { echo "Usage: $0 [-t <control|worker>] [-n <node-ip>]" 1>&2; exit 1; }

while getopts ":t:n:" o; do
    case "${o}" in
        t)
            t=${OPTARG}
            ((t == "control" || t == "worker")) || usage
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

if [ -z "${t}" ] || [ -z "${n}" ]; then
    usage
fi

NODE_TYPE=$t
NODE_IP=$n

CMD="talosctl upgrade --wait --debug --nodes ${NODE_IP} --image ${IMAGE}:${IMAGE_VERSION}"
if [[ $NODE_TYPE == "control" ]]; then
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
