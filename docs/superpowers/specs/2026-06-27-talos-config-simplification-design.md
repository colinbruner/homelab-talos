# Talos Config Simplification — Design

**Date:** 2026-06-27
**Status:** Approved
**Author:** Colin Bruner (with Claude)

## Problem

The repo generates per-node Talos machine configs using `ytt` (a YAML templating
tool with its own schema, `#@`/`#!` annotation syntax, and a Go binary
dependency). In practice, **the only values that vary per node are the hostname
and a single IP address** (`certSANs` is just that IP with the `/24` stripped).
Everything else — nameservers, gateway, NTP, kubelet args, the control-plane
endpoint, the `HostnameConfig` document — is static and identical across all
nodes of a given type. The `json-patch.yaml` templates are empty and unused.

Carrying a full templating engine to substitute two values adds friction: a
schema file to maintain, non-standard annotation syntax, an extra tool to
install, and config files that editors and YAML schema validators can't
understand because they aren't valid YAML on their own.

The documentation has also drifted: it describes the ytt system, contains a
copy-paste bug, and states cluster topology that no longer matches reality.

## Goal

Define Talos configurations in a way that is **clean, simple, and easy to read,
understand, and maintain** — without ytt. Bring the documentation back in sync
with the actual cluster and the new system.

## Non-Goals

- Changing the cluster topology, networking, or any runtime behavior. The
  generated machine configs must be functionally equivalent to today's.
- Changing the bootstrap, apply, upgrade, or download scripts beyond what is
  required to remove ytt.
- Migrating the IP scheme or hostnames.

## Approach: Static YAML + tiny per-node patches

Let Talos do the merging. Hand-author plain Talos machine-config YAML and let
`talosctl gen config` stack the patches in order. No templating engine, no
schema — the only required tool is `talosctl`.

### Why this works (verified)

`talosctl gen config` applies multiple `--config-patch-*` flags as sequential
strategic-merge patches. The merge semantics were verified against the actual
toolchain (`talosctl v1.13.2`) before adopting this design:

- **Keyed lists merge by key.** A `machine.network.interfaces` entry defined in
  a shared patch (with `deviceSelector: { busPath: "0*" }`, `mtu`, `routes`) and
  an entry in a per-node patch (same `deviceSelector`, plus `addresses`) collapse
  into a **single** interface entry with all fields combined. The output
  contained exactly one `busPath`.
- **Scalar lists append.** `machine.certSANs` and `cluster.apiServer.certSANs`
  defined as `[talos.bruner.lab]` in the shared patch plus `[<node-ip>]` in the
  node patch produced `[talos.bruner.lab, <node-ip>]` — exactly the desired
  result.
- **Multi-document patches merge by kind.** A `HostnameConfig` document placed in
  the per-node patch is added to the generated multi-document config.

> Note: the repo's old `docs/patching.md` claimed "arrays are always appended."
> That is incorrect for keyed lists like `interfaces` and is corrected as part of
> this work.

### New directory layout

`patches/` is repurposed from **generated output** to **hand-authored source**:

```
patches/
  common-control.yaml   # static, shared by all control nodes
  common-worker.yaml    # static, shared by all worker nodes
  firewall.yaml         # moved from templates/firewall.yaml (already plain YAML)
  nodes/
    control-01.yaml
    control-02.yaml
    control-03.yaml
    worker-01.yaml
    worker-02.yaml
    worker-03.yaml
    worker-04.yaml
    worker-05.yaml
    worker-06.yaml
```

Deleted entirely: `templates/`, `values/` (including `values/schema.yml` and
`values/README.md`), and the `ytt` dependency.

### File contents

**`patches/common-worker.yaml`** — the static content from today's
`templates/worker/strategic-patch.yaml`, minus the per-node fields, as plain
YAML:

```yaml
machine:
  kubelet:
    extraArgs:
      # Enables metrics-server to recognize kubelet certificates.
      rotate-server-certificates: true
  network:
    nameservers:
      - 192.168.10.1
      - 9.9.9.9
    interfaces:
      - deviceSelector:
          busPath: "0*"
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

**`patches/common-control.yaml`** — the worker common content plus the
control-only bits from `templates/control/strategic-patch.yaml`:

```yaml
machine:
  certSANs:
    - talos.bruner.lab
  kubelet:
    extraArgs:
      rotate-server-certificates: true
  network:
    nameservers:
      - 192.168.10.1
      - 9.9.9.9
    interfaces:
      - deviceSelector:
          busPath: "0*"
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

**`patches/nodes/worker-03.yaml`** — only the per-node values (~10 lines):

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

**`patches/nodes/control-01.yaml`** — same shape plus the node IP added to both
certSAN lists (preserving current behavior; the IP appears three times, plain
and explicit):

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

Node-to-IP mapping (from `CLAUDE.md` topology), used to fill the node files:

| Node | IP |
|------|----|
| control-01 | 192.168.10.21 |
| control-02 | 192.168.10.22 |
| control-03 | 192.168.10.23 |
| worker-01 | 192.168.10.31 |
| worker-02 | 192.168.10.32 |
| worker-03 | 192.168.10.33 |
| worker-04 | 192.168.10.34 |
| worker-05 | 192.168.10.35 |
| worker-06 | 192.168.10.36 |

### Script changes

**`scripts/generate-config.sh`** — remove the `generate_patch()` ytt step and all
template/values references. Resolve node type from the node name (existing
logic), then generate directly:

```
talosctl gen config \
  --with-secrets="$SECRETS_FILE" \
  --with-docs=false --with-examples=false \
  --kubernetes-version="$KUBERNETES_VERSION" \
  --output-types <controlplane|worker> \
  --config-patch-<control-plane|worker> @patches/common-<control|worker>.yaml \
  --config-patch-<control-plane|worker> @patches/firewall.yaml \
  --config-patch-<control-plane|worker> @patches/nodes/<node>.yaml \
  --output <output> \
  --force "$CLUSTER_NAME" "https://$ENDPOINT:6443"
```

The `talosconfig` generation block in `generate_controller()` is unchanged.

**`scripts/lib/consts.sh`** — drop `TEMPLATES_DIR` and `VALUES_DIR`. Repoint
`FIREWALL_TEMPLATE` to `patches/firewall.yaml`. Add path helpers for the common
and node patches as needed. `PATCHES_DIR` is retained but now points at the
source tree.

### Adding a new node (new workflow)

1. Create `patches/nodes/<name>.yaml` with the node's IP and hostname (copy an
   existing file of the same type; change two/three values).
2. Run `./scripts/generate-config.sh -n <name>`.
3. Boot the VM in Talos maintenance mode.
4. Run `./scripts/apply-config.sh -n <name> -e <ip>`.

## Documentation cleanup

| File | Action |
|------|--------|
| `docs/config.md` | Rewrite to describe the static-YAML + node-patch model; remove all ytt references. |
| `docs/patching.md` | Fix the two identical strategic/JSON code examples (copy-paste bug — the JSON section must show an actual RFC6902 patch). Correct the "arrays are always appended" claim: keyed lists (e.g. `interfaces`) merge by key; scalar lists (e.g. `certSANs`) append. |
| `README.md` | Fix "single control node + three worker nodes" → 3 control + 6 workers. Fix the directory descriptions (`patches/` is now source, not generated; `templates/`/`values/` removed). Cross-link `scripts/regenerate-talosconfig.sh` from the regenerate section. |
| `values/README.md` | Delete (directory removed). |
| `CLAUDE.md` | Update the "Configuration System" and "Adding a New Node" sections to the new model. Remove `ytt` from "Tools Required". Update repo-structure tree (`templates/`, `values/` gone; `patches/` is source). |
| `docs/upgrading.md` | Light refresh of stale example IPs/versions. |
| `patches/worker-07..09` | Delete — stale generated artifacts with no topology entry or source file. |
| `TODO` | Keep the real control-01 `.20 → .21` migration item; drop the "pki directory, only half done" cruft line. |
| `docs/examples/`, `examples/bootstrap-commands` | Review during implementation; delete if stale, otherwise leave. |
| `.claude/skills/talos-worker-upgrade.md` | Check for ytt / generate-config references; fix only if they exist. |

## Verification

The change is behavior-preserving, so the acceptance test is a **diff of
generated output**:

1. Before changes, generate all node configs with the current ytt-based script
   and save them.
2. After changes, regenerate all node configs with the new script.
3. Diff the two sets. The only acceptable differences are cosmetic (key
   ordering, comment lines). There must be no functional differences: addresses,
   hostnames, certSANs, endpoint, nameservers, routes, kubelet args, firewall
   rules, and the `HostnameConfig` document must all match.

Secondary checks:

- `grep -ri ytt` across the repo returns only historical/spec references, not
  live tooling.
- `templates/` and `values/` no longer exist.
- `README.md` and `CLAUDE.md` topology matches the 3-control / 6-worker cluster.

## Risks & Mitigations

- **Merge semantics differ on a future talosctl version.** Mitigated by the
  output-diff verification step, which would catch any regression. The behavior
  is also stable, documented Talos strategic-merge semantics, not an
  implementation quirk.
- **Per-node IP duplication in control files (3×).** Accepted: it is explicit,
  plain YAML, and trivially greppable. The alternative (deriving it) reintroduces
  templating, which is what we are removing.
