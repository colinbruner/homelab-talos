# Talos Config Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ytt-based Talos config generator with hand-authored static YAML + tiny per-node patches that `talosctl` merges, and bring the docs back in sync.

**Architecture:** Two static per-type "common" patches plus a ~10-line per-node patch are stacked by `talosctl gen config` (which performs strategic merge). `ytt`, the schema, and all templates/values are removed. The change is behavior-preserving, verified by diffing generated machine configs against a pre-change golden baseline.

**Tech Stack:** Bash, `talosctl` (v1.13.2 confirmed), plain YAML. No ytt.

## Global Constraints

- **LF line endings only** (`\n`), never CRLF. macOS dev environment.
- **Behavior-preserving:** generated machine configs must be functionally identical to the current ytt output. The only acceptable diffs are cosmetic (comments, key ordering). This is the acceptance gate (Task 4).
- **Only required tool is `talosctl`.** Do not introduce a new templating dependency.
- **Preserve current certSAN behavior:** control nodes list `talos.bruner.lab` (from common) + their own bare IP (from node patch) in both `machine.certSANs` and `cluster.apiServer.certSANs`. Workers set no certSANs.
- **Node → IP mapping** (from `CLAUDE.md` topology):

  | Node | IP/CIDR | Bare IP |
  |------|---------|---------|
  | control-01 | 192.168.10.21/24 | 192.168.10.21 |
  | control-02 | 192.168.10.22/24 | 192.168.10.22 |
  | control-03 | 192.168.10.23/24 | 192.168.10.23 |
  | worker-01 | 192.168.10.31/24 | 192.168.10.31 |
  | worker-02 | 192.168.10.32/24 | 192.168.10.32 |
  | worker-03 | 192.168.10.33/24 | 192.168.10.33 |
  | worker-04 | 192.168.10.34/24 | 192.168.10.34 |
  | worker-05 | 192.168.10.35/24 | 192.168.10.35 |
  | worker-06 | 192.168.10.36/24 | 192.168.10.36 |

- **Scratchpad dir** (for the golden baseline; persists across tasks this session):
  `/private/tmp/claude-501/-Users-colinbruner-code-colinbruner-homelab-talos/c4df4dec-a334-4390-a979-cc49d010caf0/scratchpad`
- Branch: `simplify-talos-config` (already created; the spec is committed there).

---

### Task 1: Capture golden baseline (safety net)

Generate every node's machine config with the **current ytt-based** script and stash the output. Later tasks diff against this to prove the change is behavior-preserving. No repo files change; no commit.

**Files:** none modified (writes only to scratchpad).

**Interfaces:**
- Produces: baseline configs at `<scratchpad>/baseline/<node>.yaml` for all 9 nodes, used by Task 4.

- [ ] **Step 1: Confirm prerequisites**

Run:
```bash
cd /Users/colinbruner/code/colinbruner/homelab-talos
test -f config/secrets.yaml && echo "secrets OK" || echo "MISSING secrets"
which ytt talosctl
```
Expected: `secrets OK` and both binaries resolve. (ytt must still be present here — we are running the *old* generator for the baseline.)

- [ ] **Step 2: Generate all node configs with the current script and copy to baseline**

Run:
```bash
SP="/private/tmp/claude-501/-Users-colinbruner-code-colinbruner-homelab-talos/c4df4dec-a334-4390-a979-cc49d010caf0/scratchpad"
rm -rf "$SP/baseline" && mkdir -p "$SP/baseline"
for n in control-01 control-02 control-03 worker-01 worker-02 worker-03 worker-04 worker-05 worker-06; do
  ./scripts/generate-config.sh -n "$n" >/dev/null 2>&1 || { echo "FAILED generating $n"; exit 1; }
done
cp config/control-01.yaml config/control-02.yaml config/control-03.yaml "$SP/baseline/"
cp config/workers/worker-0*.yaml "$SP/baseline/"
ls "$SP/baseline"
```
Expected: 9 files listed: `control-01.yaml control-02.yaml control-03.yaml worker-01.yaml … worker-06.yaml`.

- [ ] **Step 3: Record a checksum manifest for later comparison**

Run:
```bash
SP="/private/tmp/claude-501/-Users-colinbruner-code-colinbruner-homelab-talos/c4df4dec-a334-4390-a979-cc49d010caf0/scratchpad"
( cd "$SP/baseline" && shasum *.yaml | tee "$SP/baseline.sha" )
```
Expected: 9 sha lines printed and saved. (Informational; Task 4 uses full diff, not just shas.)

No commit for this task.

---

### Task 2: Create static source patches + per-node patches + fix .gitignore

Author the new source of truth as plain YAML and make `patches/` a committed source tree.

**Files:**
- Create: `patches/common-control.yaml`
- Create: `patches/common-worker.yaml`
- Create: `patches/firewall.yaml` (content moved verbatim from `templates/firewall.yaml`)
- Create: `patches/nodes/control-01.yaml`, `…/control-02.yaml`, `…/control-03.yaml`
- Create: `patches/nodes/worker-01.yaml` … `patches/nodes/worker-06.yaml`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `patches/common-control.yaml`, `patches/common-worker.yaml`, `patches/firewall.yaml`, `patches/nodes/<node>.yaml` — consumed by the rewritten `generate-config.sh` in Task 3 and `consts.sh`’s `FIREWALL_TEMPLATE`.

- [ ] **Step 1: Create `patches/common-worker.yaml`**

```yaml
# Static configuration shared by ALL worker nodes.
# Per-node values (address, hostname) live in patches/nodes/<node>.yaml.
machine:
  kubelet:
    extraArgs:
      # Enables metrics-server to recognize kubelet certificates.
      # https://www.talos.dev/v1.7/kubernetes-guides/configuration/deploy-metrics-server/
      rotate-server-certificates: true
  network:
    nameservers:
      - 192.168.10.1
      - 9.9.9.9
    interfaces:
      - deviceSelector:
          busPath: "0*" # selects the single hardware NIC
        mtu: 1500
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.10.1
  time:
    servers:
      - time.cloudflare.com
cluster:
  controlPlane:
    endpoint: https://talos.bruner.lab:6443
```

- [ ] **Step 2: Create `patches/common-control.yaml`**

```yaml
# Static configuration shared by ALL control plane nodes.
# Per-node values (address, certSANs IP, hostname) live in patches/nodes/<node>.yaml.
machine:
  certSANs:
    - talos.bruner.lab
  kubelet:
    extraArgs:
      # Enables metrics-server to recognize kubelet certificates.
      # https://www.talos.dev/v1.7/kubernetes-guides/configuration/deploy-metrics-server/
      rotate-server-certificates: true
  network:
    nameservers:
      - 192.168.10.1
      - 9.9.9.9
    interfaces:
      - deviceSelector:
          busPath: "0*" # selects the single hardware NIC
        mtu: 1500
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.10.1
  time:
    servers:
      - time.cloudflare.com
cluster:
  controlPlane:
    # Must be identical on every node. Talos derives the kube-apiserver
    # --service-account-issuer / --api-audiences from this value, so a per-node
    # endpoint causes cross-apiserver SA-token 401s. Use the shared DNS endpoint.
    endpoint: https://talos.bruner.lab:6443
  apiServer:
    certSANs:
      - talos.bruner.lab
```

- [ ] **Step 3: Create `patches/firewall.yaml`** (verbatim copy of `templates/firewall.yaml`)

```yaml
---
# Block all ingress by default. Explicit allow rules below define permitted traffic.
apiVersion: v1alpha1
kind: NetworkDefaultActionConfig
ingress: block
---
# Allow all TCP from trusted LAN — covers Talos API, Kubernetes API, etcd, kubelet, etc.
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: allow-lan-tcp
portSelector:
  ports:
    - 1-65535
  protocol: tcp
ingress:
  - subnet: 192.168.10.0/24
  - subnet: 192.168.1.0/24
---
# Allow all UDP from trusted LAN — covers Flannel VXLAN (8472), DNS, etc.
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: allow-lan-udp
portSelector:
  ports:
    - 1-65535
  protocol: udp
ingress:
  - subnet: 192.168.10.0/24
  - subnet: 192.168.1.0/24
---
# Allow node-exporter scraping from pod CIDR (Prometheus -> host port 9100)
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: allow-node-exporter-pods
portSelector:
  ports:
    - 9100
  protocol: tcp
ingress:
  - subnet: 10.244.0.0/16
```

- [ ] **Step 4: Create the three control node files**

`patches/nodes/control-01.yaml` (substitute IP per the mapping table for `-02`/`-03`):
```yaml
machine:
  certSANs:
    - 192.168.10.21
  network:
    interfaces:
      - deviceSelector:
          busPath: "0*"
        addresses:
          - 192.168.10.21/24
cluster:
  apiServer:
    certSANs:
      - 192.168.10.21
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: control-01
auto: "off"
```

`patches/nodes/control-02.yaml` — identical but `192.168.10.22` (×3) and `hostname: control-02`.
`patches/nodes/control-03.yaml` — identical but `192.168.10.23` (×3) and `hostname: control-03`.

- [ ] **Step 5: Create the six worker node files**

`patches/nodes/worker-01.yaml` (substitute IP/hostname per the mapping table for `-02`…`-06`):
```yaml
machine:
  network:
    interfaces:
      - deviceSelector:
          busPath: "0*"
        addresses:
          - 192.168.10.31/24
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: worker-01
auto: "off"
```

`worker-02` → `192.168.10.32/24`, `hostname: worker-02`; `worker-03` → `.33`; `worker-04` → `.34`; `worker-05` → `.35`; `worker-06` → `.36`.

- [ ] **Step 6: Rewrite `.gitignore`** so `patches/` source is committed

Replace the entire file contents with:
```gitignore
.DS_Store**

# Generated Talos machine configs and secrets
config/*

# patches/ holds hand-authored Talos config source (committed).
# Ignore stray generated per-node directories left by the old ytt workflow.
patches/*/
!patches/nodes/
```

- [ ] **Step 7: Verify the source files are valid YAML and tracked correctly**

Run:
```bash
cd /Users/colinbruner/code/colinbruner/homelab-talos
for f in patches/common-control.yaml patches/common-worker.yaml patches/firewall.yaml patches/nodes/*.yaml; do
  talosctl validate --help >/dev/null 2>&1; python3 -c "import yaml,sys;list(yaml.safe_load_all(open('$f')))" && echo "OK $f"
done
git add -A --dry-run patches/ .gitignore | grep -E 'patches/(common|firewall|nodes)' | head
```
Expected: every file prints `OK …`, and the dry-run shows `patches/common-control.yaml`, `patches/common-worker.yaml`, `patches/firewall.yaml`, and `patches/nodes/*.yaml` as additions (the old generated subdirs like `patches/control-01/` must NOT appear).

- [ ] **Step 8: Commit**

```bash
git add -A patches/ .gitignore
git commit -m "feat: add static Talos config source patches; commit patches/ as source

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Rewrite generate-config.sh and consts.sh (drop ytt)

**Files:**
- Modify: `scripts/lib/consts.sh`
- Modify: `scripts/generate-config.sh`

**Interfaces:**
- Consumes: `patches/common-<type>.yaml`, `patches/firewall.yaml`, `patches/nodes/<node>.yaml` (Task 2).
- Produces: `config/<control>.yaml` and `config/workers/<worker>.yaml` — same output paths the existing `apply-config.sh` already reads via `OUTPUT_DIR`/`WORKER_OUTPUT_DIR`.

- [ ] **Step 1: Replace `scripts/lib/consts.sh`** with:

```bash
#!/bin/bash

###
# Files
###
OUTPUT_DIR="${SCRIPTPATH}/../config"
WORKER_OUTPUT_DIR="${SCRIPTPATH}/../config/workers"

PATCHES_DIR="${SCRIPTPATH}/../patches"
NODES_DIR="${PATCHES_DIR}/nodes"

SECRETS_FILE="${OUTPUT_DIR}/secrets.yaml"
FIREWALL_TEMPLATE="${PATCHES_DIR}/firewall.yaml"
TALOSCONFIG_FILE="${OUTPUT_DIR}/talosconfig"
KUBECONFIG_FILE="${OUTPUT_DIR}/kubeconfig"

###
# Defaults
###
# These are cluster defaults when not provided.
DEFAULT_CLUSTER_NAME="homelab"
DEFAULT_CLUSTER_ENDPOINT="talos.bruner.lab"
DEFAULT_KUBERNETES_VERSION="1.35.1"
```

(`TEMPLATES_DIR` and `VALUES_DIR` removed; `FIREWALL_TEMPLATE` now points at `patches/firewall.yaml`; `NODES_DIR` added.)

- [ ] **Step 2: Replace `scripts/generate-config.sh`** with:

```bash
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
```

- [ ] **Step 3: Smoke-test the new generator on one node of each type**

Run:
```bash
cd /Users/colinbruner/code/colinbruner/homelab-talos
./scripts/generate-config.sh -n control-01 && echo "control OK"
./scripts/generate-config.sh -n worker-01 && echo "worker OK"
```
Expected: both print `creating: …` then `control OK` / `worker OK`, no errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-config.sh scripts/lib/consts.sh
git commit -m "refactor: generate configs from static patches instead of ytt

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Verify parity against the golden baseline (ACCEPTANCE GATE)

Prove the new pipeline produces functionally identical machine configs. **Do not proceed past this task if functional diffs exist** — fix the source patches/script and re-run.

**Files:** none modified (reads scratchpad + regenerates into gitignored `config/`).

**Interfaces:**
- Consumes: `<scratchpad>/baseline/*.yaml` (Task 1), new generator (Task 3), new patches (Task 2).

- [ ] **Step 1: Regenerate all nodes with the new pipeline**

Run:
```bash
cd /Users/colinbruner/code/colinbruner/homelab-talos
SP="/private/tmp/claude-501/-Users-colinbruner-code-colinbruner-homelab-talos/c4df4dec-a334-4390-a979-cc49d010caf0/scratchpad"
rm -rf "$SP/after" && mkdir -p "$SP/after"
for n in control-01 control-02 control-03 worker-01 worker-02 worker-03 worker-04 worker-05 worker-06; do
  ./scripts/generate-config.sh -n "$n" >/dev/null 2>&1 || { echo "FAILED $n"; exit 1; }
done
cp config/control-01.yaml config/control-02.yaml config/control-03.yaml "$SP/after/"
cp config/workers/worker-0*.yaml "$SP/after/"
echo "regenerated"
```
Expected: `regenerated`.

- [ ] **Step 2: Diff baseline vs after for every node**

Run:
```bash
SP="/private/tmp/claude-501/-Users-colinbruner-code-colinbruner-homelab-talos/c4df4dec-a334-4390-a979-cc49d010caf0/scratchpad"
for n in control-01 control-02 control-03 worker-01 worker-02 worker-03 worker-04 worker-05 worker-06; do
  echo "===== $n ====="
  diff "$SP/baseline/$n.yaml" "$SP/after/$n.yaml" && echo "IDENTICAL"
done
```
Expected: ideally `IDENTICAL` for all 9. If any diff appears, inspect it.

- [ ] **Step 3: Classify any diffs**

For each node showing a diff, confirm it is **cosmetic only** (comment lines, blank lines, key ordering). Spot-check the load-bearing fields are present and correct:
```bash
SP="/private/tmp/claude-501/-Users-colinbruner-code-colinbruner-homelab-talos/c4df4dec-a334-4390-a979-cc49d010caf0/scratchpad"
for n in control-01 worker-01; do
  echo "=== $n ==="
  grep -E "hostname:|addresses:|192.168.10|endpoint:|rotate-server-certificates|talos.bruner.lab" "$SP/after/$n.yaml" | sort -u
done
```
Expected: each node has its correct `/24` address, the shared endpoint `https://talos.bruner.lab:6443`, `rotate-server-certificates`, its `HostnameConfig` hostname, and (control only) `talos.bruner.lab` + node IP in certSANs.

**GATE:** If any *functional* difference exists (different IP, missing field, wrong endpoint, missing firewall doc, missing HostnameConfig), STOP and fix Task 2/Task 3 source, then repeat Steps 1–3. No commit until parity holds.

- [ ] **Step 4: Record the result** (no repo change)

State explicitly in the task report whether all nodes were IDENTICAL or which had cosmetic-only diffs, with the diff snippets as evidence.

---

### Task 5: Remove the ytt toolchain and stale artifacts

**Files:**
- Delete: `templates/` (entire directory: `control/`, `worker/`, `firewall.yaml`)
- Delete: `values/` (entire directory: schema + node value files + README)
- Delete on disk: stale generated patch dirs under `patches/` from the old workflow (e.g. `patches/control-0*/`, `patches/worker-0*/`) — these are gitignored, so this is filesystem cleanup only.

**Interfaces:** none produced/consumed.

- [ ] **Step 1: Confirm nothing still references the directories being removed**

Run:
```bash
cd /Users/colinbruner/code/colinbruner/homelab-talos
grep -rn -E "templates/|values/|ytt|TEMPLATES_DIR|VALUES_DIR|STRATEGIC_PATCH_TEMPLATE|JSON_PATCH" scripts/ resources/ 2>/dev/null
```
Expected: **no output**. If anything prints, fix that reference before deleting (docs are handled in Tasks 6–7 and may still mention ytt — only `scripts/` and `resources/` must be clean here).

- [ ] **Step 2: Remove templates/ and values/ from git**

Run:
```bash
git rm -rf templates values
```
(`-f` is required: `templates/control/strategic-patch.yaml` has uncommitted working-tree modifications that are being discarded along with the file.)
Expected: lists `templates/...` and `values/...` files being removed.

- [ ] **Step 3: Clean stale generated patch dirs off disk** (gitignored; not in git)

Run:
```bash
find patches -mindepth 1 -maxdepth 1 -type d ! -name nodes -print -exec rm -rf {} +
ls -la patches patches/nodes
```
Expected: only `common-control.yaml`, `common-worker.yaml`, `firewall.yaml`, and `nodes/` remain in `patches/`; `patches/nodes/` holds the 9 node files.

- [ ] **Step 4: Confirm the generator still works after deletions**

Run:
```bash
./scripts/generate-config.sh -n worker-02 && echo "still OK"
```
Expected: `creating: …` then `still OK`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove ytt templates, values, and schema

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Rewrite core config documentation

**Files:**
- Replace: `docs/config.md`
- Modify: `docs/patching.md`

**Interfaces:** none.

- [ ] **Step 1: Replace `docs/config.md`** with:

````markdown
# Config

Talos machine configs are assembled from plain, hand-authored YAML patches.
There is no templating engine — `talosctl gen config` stacks the patches and
Talos performs the merge. See [patching](./patching.md) for the merge rules.

## Layout

```
patches/
  common-control.yaml   # static config shared by all control plane nodes
  common-worker.yaml    # static config shared by all worker nodes
  firewall.yaml         # host ingress firewall rules (applied to every node)
  nodes/
    control-01.yaml     # per-node: address, certSANs IP, hostname
    ...
    worker-06.yaml      # per-node: address, hostname
```

## How generation works

`scripts/generate-config.sh -n <node>` derives the node type from its name and
runs:

```
talosctl gen config ... \
  --config-patch-<type> @patches/common-<type>.yaml \
  --config-patch-<type> @patches/firewall.yaml \
  --config-patch-<type> @patches/nodes/<node>.yaml
```

Patches apply in order as strategic merges. Keyed lists such as
`machine.network.interfaces` merge by key — the shared interface block and the
per-node address collapse into one entry — while scalar lists such as `certSANs`
append. See [patching](./patching.md).

## Per-node files

A worker file contains only what varies — address and hostname:

```yaml
machine:
  network:
    interfaces:
      - deviceSelector:
          busPath: "0*"
        addresses:
          - 192.168.10.33/24
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: worker-03
auto: "off"
```

A control file additionally lists its IP in `machine.certSANs` and
`cluster.apiServer.certSANs`.

## Adding a node

1. Copy an existing file in `patches/nodes/` of the same type; update the
   address and hostname (and the certSANs IP for control nodes).
2. Run `./scripts/generate-config.sh -n <node>`.
````

- [ ] **Step 2: Fix the wrong merge-semantics sentence in `docs/patching.md`**

Replace the paragraph that currently reads:
> Strategic merging allows merging 1 yaml configuration file into another. For non-array values, this typically results in the merging value `overwriting` the existing value. For array values, the merginv values are `appended` to the end of the array.

with:
```markdown
Strategic merging merges one YAML document into another. Scalar values in the
merging document overwrite the existing value. List behavior depends on the
field: Talos merges *keyed* lists (e.g. `machine.network.interfaces`, matched on
`deviceSelector`/`interface`) element-by-element, while plain scalar lists (e.g.
`certSANs`, `nameservers`) are appended. This is why a shared interface block and
a per-node address combine into a single interface entry.
```

- [ ] **Step 3: Fix the duplicated JSON-patch example in `docs/patching.md`**

The "JSON Patches (RFC6902)" section currently shows the *same* command as the strategic section. Replace that code block with one that actually demonstrates a JSON patch:

````markdown
```bash
# Target controlplane IP Address
NODE_IP=192.168.1.10

# An RFC6902 patch gives explicit control over array elements — e.g. replacing
# addresses rather than appending. patch.json:
# [
#   { "op": "replace",
#     "path": "/machine/network/interfaces/0/addresses",
#     "value": ["192.168.1.20/24"] }
# ]

talosctl patch mc \
  --talosconfig config/talosconfig \
  -e $NODE_IP \
  -n $NODE_IP \
  --patch @patch.json
```
````

- [ ] **Step 4: Verify no ytt references remain in these two docs**

Run:
```bash
grep -ni "ytt\|template\|schema\|values/" docs/config.md docs/patching.md
```
Expected: no output (or only incidental, non-ytt uses of the word "template" in prose — review each).

- [ ] **Step 5: Commit**

```bash
git add docs/config.md docs/patching.md
git commit -m "docs: rewrite config guide for static-patch model; fix patching errors

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Sync reference docs and clean up stragglers

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `docs/upgrading.md`
- Modify: `docs/bootstrap.md`
- Modify: `TODO`
- Delete: `examples/bootstrap-commands` (references nonexistent scripts/flags)
- Verify only (expect no change): `.claude/skills/talos-worker-upgrade.md`, `docs/examples/`

**Interfaces:** none.

- [ ] **Step 1: Fix `README.md`**

- Change the topology sentence "I've documented the initial bootstrapping of a single control node + three worker nodes…" to read "three control plane nodes and six worker nodes, all running as VMs on Proxmox."
- In the "Directories" list: remove the `templates` entry; change the `patches` entry to: "[patches](./patches/): hand-authored Talos config source — `common-control.yaml`, `common-worker.yaml`, `firewall.yaml`, and per-node files under `nodes/`."; remove any `values`/`templates` lines.
- In the "Regenerating Kubeconfig & Talosconfig" section, add a sentence pointing at the script: "This is automated by [`scripts/regenerate-talosconfig.sh`](./scripts/regenerate-talosconfig.sh); the manual steps below are for reference."

- [ ] **Step 2: Fix `CLAUDE.md`**

- **Repository Structure tree:** remove the `templates/` and `values/` lines; change the `patches/` comment to "Hand-authored Talos config source (common + per-node + firewall)".
- **Configuration System section:** replace the "Values → Templates → Patches → Machine Config" subsection and its numbered list with a description of the new model: static `patches/common-{control,worker}.yaml` + `patches/firewall.yaml` + tiny `patches/nodes/<node>.yaml`, stacked by `talosctl gen config`. No ytt, no schema.
- **Adding a New Node:** replace with: (1) copy an existing `patches/nodes/<name>.yaml` of the same type and edit its address/hostname (and certSANs IP for control); (2) `./scripts/generate-config.sh -n <name>`; (3) boot VM in Maintenance mode; (4) `./scripts/apply-config.sh`.
- **Tools Required:** remove the `ytt` line.
- **Conventions:** change "Patches are always generated, never hand-edited directly (edit templates instead)" to "Config patches in `patches/` are hand-authored source; edit them directly. `config/` is generated output."

- [ ] **Step 3: Refresh `docs/upgrading.md`**

Update the stale example IPs and versions to match the current cluster: use `192.168.10.21` (a control IP) and `192.168.10.31` (a worker IP) in the example commands instead of `192.168.1.20` / `192.168.1.32`. Fix the worker example header that mislabels a worker command as `-t control`. Leave the upgrade guidance text itself intact.

- [ ] **Step 4: Fix `docs/bootstrap.md`**

Run first:
```bash
grep -n -- "-t control\|-t worker\|download-kubeconfig\|single control\|ytt\|templates/\|values/" docs/bootstrap.md
```
For each hit: drop the obsolete `-t <type>` flag from `generate-config.sh`/`apply-config.sh` invocations (type is derived from the node name), correct `download-kubeconfig.sh` to `download-config.sh`, and reword any "single control node" phrasing to the 3-control/6-worker topology. If a hit is inside prose that's still accurate, leave it.

- [ ] **Step 5: Trim `TODO`**

Remove the leading "pki directory, only half done" cruft line. Keep the "## Remaining work" / "control-01 IP migration" section intact (it is a real open item).

- [ ] **Step 6: Delete the stale example**

```bash
git rm examples/bootstrap-commands
rmdir examples 2>/dev/null || true
```

- [ ] **Step 7: Verify the skill and docs/examples need no change**

Run:
```bash
grep -ni "ytt\|generate-config\|templates/\|values/" .claude/skills/talos-worker-upgrade.md docs/examples/* 2>/dev/null
```
Expected: no ytt/generate-config/templates/values references requiring edits. (The skill is about upgrades; `docs/examples/` are generic Talos patch illustrations and stay as-is.) If something appears, note it but do not expand scope beyond fixing an outright wrong reference.

- [ ] **Step 8: Final repo-wide ytt sweep**

Run:
```bash
grep -rni "ytt" . --exclude-dir=.git --exclude-dir=docs/superpowers 2>/dev/null
```
Expected: no live references (spec/plan under `docs/superpowers/` are excluded as historical record).

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "docs: sync README/CLAUDE/bootstrap/upgrading to static-patch model; drop stale example

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Done criteria

- `ytt`, `templates/`, and `values/` are gone; `grep -rni ytt` (excluding `docs/superpowers/`) is clean.
- `patches/` is committed source: `common-control.yaml`, `common-worker.yaml`, `firewall.yaml`, `nodes/<9 files>`.
- New machine configs are functionally identical to the pre-change baseline (Task 4 gate passed).
- `README.md` and `CLAUDE.md` describe the 3-control / 6-worker cluster and the static-patch model; `docs/config.md` and `docs/patching.md` are accurate.
