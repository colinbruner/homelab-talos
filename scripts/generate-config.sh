#!/bin/bash -e

###
# Generates Talos machine configs for a single node by stacking static common
# patches with a tiny per-node patch. No templating engine required.
###

# Consts
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

. ${SCRIPTPATH}/lib/consts.sh

mkdir -p $WORKER_OUTPUT_DIR

usage() { echo "Usage: $0 -n <name> [-e <endpoint>] [-c <cluster>] [-k <kubernetes-version>]" 1>&2; exit 1; }

function generate_controller() {
  if [[ ! -f $SECRETS_FILE ]]; then
    # sanity baked into this command, requires --force to overwrite an existing secrets file.
    echo "creating: ${SECRETS_FILE}"
    talosctl gen secrets -o $SECRETS_FILE 2>/dev/null
  fi

  # Generate Controlplane
  # NOTE: when multiple output types are selected, the output path must be a directory.
  echo "creating: $OUTPUT_DIR/$NODE_NAME.yaml"
  talosctl gen config \
    --with-secrets="$SECRETS_FILE" \
    --with-docs=false \
    --with-examples=false \
    --kubernetes-version=$KUBERNETES_VERSION \
    --output-types controlplane \
    --config-patch-control-plane @${COMMON_PATCH} \
    --config-patch-control-plane @${FIREWALL_TEMPLATE} \
    --config-patch-control-plane @${NODE_PATCH} \
    --output ${OUTPUT_DIR}/${NODE_NAME}.yaml \
    $EXTRA_ARGS \
    $CLUSTER_NAME \
    https://$ENDPOINT:6443

  if [[ ! -f $TALOSCONFIG_FILE ]]; then
    echo "creating: ${TALOSCONFIG_FILE}"
    # Generate Talosconfig
    talosctl gen config \
      --with-secrets="$SECRETS_FILE" \
      --with-docs=false \
      --with-examples=false \
      --output-types talosconfig \
      --output $TALOSCONFIG_FILE \
      $CLUSTER_NAME \
      https://$ENDPOINT:6443

    echo "adding endpoint '${ENDPOINT} configuration to: ${TALOSCONFIG_FILE}"
    talosctl --talosconfig=$TALOSCONFIG_FILE config endpoint $ENDPOINT
  fi
}

function generate_worker() {
  echo "creating: ${WORKER_OUTPUT_DIR}/${NODE_NAME}.yaml"
  talosctl gen config \
    --with-secrets="$SECRETS_FILE" \
    --with-docs=false \
    --with-examples=false \
    --kubernetes-version=$KUBERNETES_VERSION \
    --output-types worker \
    --config-patch-worker @${COMMON_PATCH} \
    --config-patch-worker @${FIREWALL_TEMPLATE} \
    --config-patch-worker @${NODE_PATCH} \
    --output ${WORKER_OUTPUT_DIR}/${NODE_NAME}.yaml \
    $EXTRA_ARGS \
    $CLUSTER_NAME \
    https://$ENDPOINT:6443 2>/dev/null
}

###
# parse args
###
EXTRA_ARGS="--force "
while getopts ":e:n:c:k:" o; do
    case "${o}" in
        e) e=${OPTARG} ;;
        n) n=${OPTARG} ;;
        c) c=${OPTARG} ;;
        k) k=${OPTARG} ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${n}" ] ; then
  usage
fi

###
# main
###
NODE_NAME=$n
if [[ $NODE_NAME =~ ^control ]]; then
  NODE_TYPE="control"
  COMMON_PATCH="${PATCHES_DIR}/common-control.yaml"
elif [[ $NODE_NAME =~ ^worker ]]; then
  NODE_TYPE="worker"
  COMMON_PATCH="${PATCHES_DIR}/common-worker.yaml"
else
  echo "Node name must start with 'control' or 'worker'. Got: ${NODE_NAME}"
  exit 1
fi

NODE_PATCH="${NODES_DIR}/${NODE_NAME}.yaml"
if [[ ! -f $NODE_PATCH ]]; then
  echo "Node patch not found: ${NODE_PATCH}"
  exit 1
fi

ENDPOINT=${e:-$DEFAULT_CLUSTER_ENDPOINT} # NOTE: DNS name or IP of the cluster endpoint
CLUSTER_NAME=${c:-$DEFAULT_CLUSTER_NAME}
KUBERNETES_VERSION=${k:-$DEFAULT_KUBERNETES_VERSION}

if [[ $NODE_TYPE == "control" ]]; then
  generate_controller
else
  generate_worker
fi
