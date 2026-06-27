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
