#!/bin/bash -e

###
# Generates base configurations for a Talos Cluster
###

# Consts
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

mkdir -p $WORKER_OUTPUT_DIR
mkdir -p $PATCHES_DIR

usage() { echo "Usage: $0 [-t <control|worker>] [-n <name>] [-e <endpoint>] [-c <cluster>]" 1>&2; exit 1; }

function generate_controller() {
  if [[ ! -f $SECRETS_FILE ]]; then
    # sanity baked into this command, requires --force to overwrite an existing secrets file.
    talosctl gen secrets -o $SECRETS_FILE
  fi

  # Generate Controlplane 
  # NOTE: when multiple output types are selected, the output path must be a directory.. this prevents naming the controlplane.yaml file
  talosctl gen config \
    --with-secrets="$SECRETS_FILE" \
    --with-docs=false \
    --with-examples=false \
    --output-types controlplane \
    --config-patch-control-plane @${NODE_PATCH} \
    --output ${OUTPUT_DIR}/${NODE_NAME}.yaml \
    $CLUSTER_NAME \
    https://$ENDPOINT:6443

  if [[ ! -f $TALOSCONFIG_FILE ]]; then
    # Generate Talosconfig
    talosctl gen config \
      --with-secrets="$SECRETS_FILE" \
      --with-docs=false \
      --with-examples=false \
      --output-types talosconfig \
      --config-patch-control-plane @${NODE_PATCH} \
      --output $TALOSCONFIG_FILE \
      $CLUSTER_NAME \
      https://$ENDPOINT:6443
}

function generate_worker() {
  talosctl gen config \
    --with-secrets="$SECRETS_FILE" \
    --with-docs=false \
    --with-examples=false \
    --output-types worker \
    --config-patch-worker @${NODE_PATCH} \
    --output ${WORKER_OUTPUT_DIR}/${NODE_NAME}.yaml \
    $CLUSTER_NAME \
    https://$ENDPOINT:6443
}

###
# parse args
###
while getopts ":t:e:n:c:" o; do
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
        c)
            c=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${t}" ] || [ -z "${n}" ] || [ -z "${e}" ]; then
    usage
fi

###
# main
###
function generate_patch() {
  ytt \
    -f ${VALUES_DIR}/schema.yml \
    -f ${TEMPLATES_DIR}/network.yaml \
    --data-values-file ${VALUES_DIR}/${NODE_NAME}.yaml \
    --output-files ${PATCHES_DIR}
}

# Input
NODE_TYPE=$t
NODE_NAME=$n
ENDPOINT=$e
CLUSTER_NAME=${c:-"homelab"}

NODE_PATCH=${PATCHES_DIR}/network.yaml # NOTE: This generates a file based off template name passed in 'generate_patch'
generate_patch $NODE_TYPE

if [[ $NODE_TYPE == "control" ]]; then
  generate_controller
else
  generate_worker
fi
