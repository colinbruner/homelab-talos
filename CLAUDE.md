# CLAUDE.md — Talos Homelab Cluster

## Project Purpose

This repository manages a **Talos Linux Kubernetes cluster** running on Proxmox VMs. It covers the full lifecycle: config generation, node provisioning, bootstrapping, and upgrades. Configuration uses hand-authored static YAML patches stacked by `talosctl gen config`, making it straightforward to add or reconfigure nodes.

---

## Cluster Topology

| Role          | Hostname     | IP                                    |
|---------------|-------------|---------------------------------------|
| Control Plane | control-01  | 192.168.10.21                         |
| Control Plane | control-02  | 192.168.10.22                         |
| Control Plane | control-03  | 192.168.10.23                         |
| Worker        | worker-01   | 192.168.10.31   |
| Worker        | worker-02   | 192.168.10.32   |
| Worker        | worker-03   | 192.168.10.33   |
| Worker        | worker-04   | 192.168.10.34   |
| Worker        | worker-05   | 192.168.10.35   |
| Worker        | worker-06   | 192.168.10.36   |

**Network:** 192.168.10.0/24, Gateway: 192.168.10.1, DNS: 192.168.10.1 / 9.9.9.9
**Pod CIDR:** 10.244.0.0/16 | **Service CIDR:** 10.96.0.0/12
**Cluster endpoint:** `talos.bruner.lab` (DNS A record pointing to all 3 control plane IPs)

---

## Repository Structure

```
.
├── config/          # Generated Talos machine configs and TLS certs (gitignored secrets)
├── docs/            # Guides: bootstrap, config, patching, upgrading
├── patches/         # Hand-authored Talos config source (common + per-node + firewall)
├── resources/       # Post-bootstrap Kubernetes manifests (metrics-server, cert-approver)
└── scripts/         # Lifecycle automation scripts
```

---

## Key Scripts

All scripts live in `./scripts/` and source `./scripts/lib/consts.sh` for shared defaults.

| Script                       | Purpose                                                        |
|------------------------------|----------------------------------------------------------------|
| `generate-config.sh`         | Stacks static patches and generates machine configs via `talosctl gen config` |
| `apply-config.sh`            | Applies machine configs to nodes via `talosctl`                |
| `bootstrap-kubernetes.sh`    | One-time Kubernetes bootstrap on the first control plane node  |
| `download-config.sh`         | Fetches `kubeconfig` from the control plane                    |
| `upgrade-talos.sh`           | Upgrades Talos OS on a single node; prompts for confirmation   |
| `upgrade-kubernetes.sh`      | Upgrades Kubernetes cluster-wide via `talosctl upgrade-k8s`    |
| `regenerate-talosconfig.sh`  | Regenerates `config/talosconfig` and installs to `~/.talos/config` |

### upgrade-talos.sh Usage

```bash
./scripts/upgrade-talos.sh -t <control|worker> -n <node-ip> -v <version>
# Example:
./scripts/upgrade-talos.sh -t worker -n 192.168.10.31 -v v1.9.4
```

The script prints the `talosctl upgrade` command and prompts `Continue? [y/N]` before executing. Worker upgrades use `--wait --debug`. Control plane upgrades add `--preserve`.

---

## Bootstrap Workflow (in order)

```bash
./scripts/generate-config.sh   # 1. Generate patches and machine configs
./scripts/apply-config.sh      # 2. Apply configs (nodes must be in Maintenance mode)
./scripts/bootstrap-kubernetes.sh  # 3. Bootstrap k8s (once, on control-01)
./scripts/download-config.sh   # 4. Fetch kubeconfig
```

Post-bootstrap, install additional resources:

```bash
./resources/install.sh         # Installs metrics-server and kubelet-cert-approver
```

---

## Configuration System

### Static Patches → Machine Config

Config is built from hand-authored static YAML patches stacked by `talosctl gen config`:

- `patches/common-control.yaml` — shared config for all control plane nodes
- `patches/common-worker.yaml` — shared config for all worker nodes
- `patches/firewall.yaml` — firewall rules applied to all nodes
- `patches/nodes/<node>.yaml` — tiny per-node file (address, hostname; certSANs for control)

`config/` holds the generated machine configs (gitignored). There is no templating layer or schema — just plain YAML files and `talosctl`.

### Adding a New Node

1. Copy an existing `patches/nodes/<name>.yaml` of the same type and edit its address/hostname (and certSANs IP for control plane nodes)
2. Run `./scripts/generate-config.sh -n <name>`
3. Boot the VM in Talos Maintenance mode
4. Run `./scripts/apply-config.sh`

---

## Upgrading Talos OS

Upgrades are done **one node at a time** using `upgrade-talos.sh`. Always upgrade workers before control plane nodes. See `docs/upgrading.md` for full details.

```bash
# Upgrade a single worker
./scripts/upgrade-talos.sh -t worker -n 192.168.10.31 -v v1.9.4
```

For sequential upgrades across all workers, use the **Talos Worker Upgrade** skill (`.claude/skills/talos-worker-upgrade.md`).

---

## Tools Required

- `talosctl` — Talos OS control CLI
- `kubectl` — Kubernetes client
- `kustomize` — Kubernetes resource bundling

---

## Secrets and Credentials

- `config/secrets.yaml` — Talos cluster secrets (tokens, CA certs). **Do not commit.**
- `config/talosconfig` — Talos client config. **Do not commit.**
- `config/kubeconfig` — Kubernetes client config. **Do not commit.**
- Credentials are backed up in **1Password** (see `README.md` for regeneration steps).

---

## Conventions

- **Line endings:** Always use LF (`\n`), never CRLF (`\r\n`). This is a macOS development environment.
- Node hostnames follow `{control,worker}-{01..09}` (zero-padded)
- IPs: control plane starts at `.21`, workers start at `.31`
- Config patches in `patches/` are hand-authored source; edit them directly. `config/` is generated output.
- Static IPs on all nodes — no DHCP
- All nodes share the same DNS, NTP, and gateway config
