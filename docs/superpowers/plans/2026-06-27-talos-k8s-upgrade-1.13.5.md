# Talos & Kubernetes Upgrade to v1.13.5 / v1.36.2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the homelab Talos cluster from Talos OS v1.12.4 / Kubernetes v1.35.1 to the latest Talos OS v1.13.5 and its bundled Kubernetes v1.36.2, with zero data loss and no control-plane outage.

**Architecture:** This is an in-place rolling upgrade of a live cluster, not a code change. Talos OS is upgraded first (one node at a time, control plane before workers, etcd quorum preserved), because Talos 1.12 cannot run Kubernetes 1.36 — only Talos 1.13 can. Kubernetes is upgraded second via `talosctl upgrade-k8s`, which internally orders control-plane components before kubelets. Repo defaults and docs are then synced so future config generation matches the new versions. Because it operates on live infrastructure, "tests" in this plan are **health/version verification commands with expected output** rather than unit tests.

**Tech Stack:** Talos Linux, `talosctl`, Kubernetes, `kubectl`, bash lifecycle scripts in `scripts/`.

## Global Constraints

- **Target Talos OS version:** `v1.13.5` (exact, latest stable).
- **Target Kubernetes version:** `1.36.2` (exact — the version bundled with Talos v1.13.5).
- **Upgrade order is mandatory:** Talos OS upgrade fully completes on all nodes **before** the Kubernetes upgrade begins. Talos 1.12 does not support K8s 1.36.
- **Node order within the Talos OS upgrade:** control plane nodes first (`control-01` → `control-02` → `control-03`), then workers (`worker-01` … `worker-06`), strictly **one node at a time**.
- **Control plane Talos upgrades MUST use `--preserve`** (handled automatically by `upgrade-talos.sh -t control`) to keep etcd data across the reboot.
- **Single-minor rule:** never skip a minor version. 1.12→1.13 and 1.35→1.36 are each one minor bump; do not attempt to jump further.
- **Stop-on-failure:** if any node fails to return to `Ready` or any health check fails, halt and do not proceed to the next node/phase.
- **Line endings:** LF only in any edited file.
- **Cluster facts** (from `CLAUDE.md`): control plane = `192.168.10.21/.22/.23`; workers = `192.168.10.31`–`.36`; endpoint = `talos.bruner.lab`.

---

## File Structure

This upgrade is executed mostly via existing scripts; only three repo files change, all in the housekeeping phase:

- `scripts/lib/consts.sh` — bump `DEFAULT_KUBERNETES_VERSION` so future `generate-config.sh` runs emit 1.36.2 configs.
- `CLAUDE.md` — fix the "workers before control plane" line to match the correct control-first order.
- `docs/upgrading.md` — refresh stale example version numbers and the doc-link Talos version.
- `MEMORY.md` (in the memory dir, outside the repo) — fix the stale index entry pointing at a deleted file.

No machine-config regeneration or re-apply is required for the upgrade itself: `talosctl upgrade` and `talosctl upgrade-k8s` mutate the running install image directly. Re-generating configs is only needed if node config content changes, which this plan does not do.

---

## Task 1: Upgrade local CLI tooling to v1.13.5

**Files:** none (local toolchain only).

**Interfaces:**
- Produces: a `talosctl` binary at exactly `v1.13.5` on PATH, used by every later task. This is required because `talosctl` v1.13.2 has bug [#13350](https://github.com/siderolabs/talos/issues/13350) (renders K8s 1.36 scheduler fields into a 1.35 scheduler config). `kubectl` is already v1.36.2 and needs no change.

- [ ] **Step 1: Record the current client version (baseline)**

Run:
```bash
talosctl version --client
```
Expected (before upgrade): `Tag: v1.13.2`.

- [ ] **Step 2: Upgrade talosctl to v1.13.5**

If installed via Homebrew:
```bash
brew upgrade siderolabs/talos/talosctl || brew install siderolabs/talos/talosctl
```
If installed via the official installer (fallback):
```bash
curl -sL https://talos.dev/install | sh -s -- -v v1.13.5
```

- [ ] **Step 3: Verify the client is now v1.13.5**

Run:
```bash
talosctl version --client
```
Expected: `Tag: v1.13.5`.

- [ ] **Step 4: Verify kubectl is already at target**

Run:
```bash
kubectl version --client
```
Expected: `Client Version: v1.36.2` (already correct — no action needed).

No commit (toolchain only, nothing tracked changed).

---

## Task 2: Pre-flight — health check, etcd backup, secrets confirmation

**Files:** none (produces a local backup artifact).

**Interfaces:**
- Consumes: `talosctl` v1.13.5 from Task 1, and `config/talosconfig` (already installed at `~/.talos/config`).
- Produces: a local etcd snapshot file (recovery artifact), and a confirmed-healthy cluster baseline that every subsequent verification compares against.

- [ ] **Step 1: Confirm the cluster is fully healthy before touching anything**

Run:
```bash
talosctl --nodes 192.168.10.21 health
```
Expected: all checks report `OK` / `healthy`, ending with `waiting for all k8s nodes to report ready: OK`. **If anything is unhealthy, STOP** and resolve before upgrading.

- [ ] **Step 2: Confirm every node is `Ready` and record starting versions**

Run:
```bash
kubectl get nodes -o wide
```
Expected: 9 nodes `Ready`; `OS-IMAGE` shows `Talos (v1.12.4)`; `VERSION` shows `v1.35.x`. This is the baseline.

- [ ] **Step 3: Take an etcd snapshot (recovery point)**

Run:
```bash
talosctl --nodes 192.168.10.21 etcd snapshot etcd-backup-$(date +%Y%m%d-%H%M%S).db
```
Expected: `etcd snapshot saved to "etcd-backup-...db"` and a non-zero file size. Move/keep this file somewhere safe off the cluster.

- [ ] **Step 4: Confirm cluster secrets are recoverable**

Verify `config/secrets.yaml` and `config/talosconfig` exist locally and are backed up in 1Password (per `README.md`).
```bash
ls -l config/secrets.yaml config/talosconfig
```
Expected: both files present. **If `secrets.yaml` is missing and not in 1Password, STOP** — losing it makes the cluster unmanageable.

No commit.

---

## Task 3: Upgrade Talos OS on control plane nodes (v1.12.4 → v1.13.5)

**Files:** none (mutates running nodes via `scripts/upgrade-talos.sh`).

**Interfaces:**
- Consumes: `talosctl` v1.13.5, a healthy cluster + etcd snapshot from Task 2.
- Produces: control-plane nodes running Talos `v1.13.5` with etcd quorum intact. Workers (Task 4) and the K8s upgrade (Task 5) depend on the control plane already being on 1.13.5.

Process **`control-01` (.21) → `control-02` (.22) → `control-03` (.23)`, one at a time.** After each node, run the verification steps before starting the next. `-t control` makes the script add `--preserve` automatically.

- [ ] **Step 1: Upgrade control-01**

Run:
```bash
./scripts/upgrade-talos.sh -t control -n 192.168.10.21 -v v1.13.5 -y
```
Expected: script prints `talosctl upgrade --wait --debug --nodes 192.168.10.21 --image ghcr.io/siderolabs/installer:v1.13.5 --preserve`, the node reboots, and the command exits `0` after `--wait` reports the node back up. **If exit code is non-zero, STOP.**

- [ ] **Step 2: Verify control-01 rejoined on the new version**

Poll every 10s up to 180s:
```bash
kubectl get nodes control-01 -o wide
```
Expected: `STATUS=Ready` and `OS-IMAGE=Talos (v1.13.5)`.

- [ ] **Step 3: Verify etcd quorum is healthy before continuing**

Run:
```bash
talosctl --nodes 192.168.10.21 health
```
Expected: all `OK`, including etcd members healthy. **Do not proceed to control-02 until this passes.**

- [ ] **Step 4: Upgrade control-02**

Run:
```bash
./scripts/upgrade-talos.sh -t control -n 192.168.10.22 -v v1.13.5 -y
```
Expected: exit `0`.

- [ ] **Step 5: Verify control-02**

Poll `kubectl get nodes control-02 -o wide` until `Ready` + `Talos (v1.13.5)`, then run `talosctl --nodes 192.168.10.21 health` and confirm all `OK`.

- [ ] **Step 6: Upgrade control-03**

Run:
```bash
./scripts/upgrade-talos.sh -t control -n 192.168.10.23 -v v1.13.5 -y
```
Expected: exit `0`.

- [ ] **Step 7: Verify all three control nodes are on v1.13.5**

Run:
```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane -o wide
```
Expected: `control-01/02/03` all `Ready` with `OS-IMAGE=Talos (v1.13.5)`.

No commit.

---

## Task 4: Upgrade Talos OS on worker nodes (v1.12.4 → v1.13.5)

**Files:** none (mutates running nodes via `scripts/upgrade-talos.sh`).

**Interfaces:**
- Consumes: control plane already on v1.13.5 (Task 3).
- Produces: all 6 workers on Talos `v1.13.5`, leaving the entire cluster on v1.13.5 — the precondition for the Kubernetes upgrade in Task 5.

Process **`worker-01` (.31) → `worker-02` (.32) → … → `worker-06` (.36)`, one at a time.** `-t worker` runs with `--wait --debug` (no `--preserve`).

> **Shortcut:** the `talos-worker-upgrade` skill (`.claude/skills/talos-worker-upgrade.md`) automates this exact loop (auto-discovers IPs, upgrades sequentially, validates each node, prints a summary). You may invoke it with version `v1.13.5` instead of running the six steps below manually. The steps below are the explicit equivalent.

- [ ] **Step 1: Upgrade worker-01**

Run:
```bash
./scripts/upgrade-talos.sh -t worker -n 192.168.10.31 -v v1.13.5 -y
```
Expected: exit `0`; `--wait` reports `post check passed`.

- [ ] **Step 2: Verify worker-01**

Poll every 10s up to 180s:
```bash
kubectl get nodes worker-01 -o wide
```
Expected: `Ready` + `OS-IMAGE=Talos (v1.13.5)`. **If it does not return to Ready, STOP.**

- [ ] **Step 3: Upgrade worker-02 and verify**

```bash
./scripts/upgrade-talos.sh -t worker -n 192.168.10.32 -v v1.13.5 -y
```
Then poll `kubectl get nodes worker-02 -o wide` until `Ready` + `Talos (v1.13.5)`.

- [ ] **Step 4: Upgrade worker-03 and verify**

```bash
./scripts/upgrade-talos.sh -t worker -n 192.168.10.33 -v v1.13.5 -y
```
Then poll `kubectl get nodes worker-03 -o wide` until `Ready` + `Talos (v1.13.5)`.

- [ ] **Step 5: Upgrade worker-04 and verify**

```bash
./scripts/upgrade-talos.sh -t worker -n 192.168.10.34 -v v1.13.5 -y
```
Then poll `kubectl get nodes worker-04 -o wide` until `Ready` + `Talos (v1.13.5)`.

- [ ] **Step 6: Upgrade worker-05 and verify**

```bash
./scripts/upgrade-talos.sh -t worker -n 192.168.10.35 -v v1.13.5 -y
```
Then poll `kubectl get nodes worker-05 -o wide` until `Ready` + `Talos (v1.13.5)`.

- [ ] **Step 7: Upgrade worker-06 and verify**

```bash
./scripts/upgrade-talos.sh -t worker -n 192.168.10.36 -v v1.13.5 -y
```
Then poll `kubectl get nodes worker-06 -o wide` until `Ready` + `Talos (v1.13.5)`.

- [ ] **Step 8: Verify the entire cluster is on Talos v1.13.5**

Run:
```bash
kubectl get nodes -o wide
```
Expected: all 9 nodes `Ready` with `OS-IMAGE=Talos (v1.13.5)`. (`VERSION`/kubelet is still `v1.35.x` — that is upgraded in Task 5.)

- [ ] **Step 9: Final OS-phase health check**

Run:
```bash
talosctl --nodes 192.168.10.21 health
```
Expected: all `OK`.

No commit.

---

## Task 5: Upgrade Kubernetes (v1.35.1 → v1.36.2)

**Files:** none (mutates the running cluster via `scripts/upgrade-kubernetes.sh`).

**Interfaces:**
- Consumes: every node on Talos v1.13.5 (Tasks 3–4) — required, since K8s 1.36 only runs on Talos 1.13.
- Produces: all control-plane components and all kubelets at `v1.36.2`. `talosctl upgrade-k8s` orders control-plane components before kubelets internally, so no manual node ordering is needed here.

- [ ] **Step 1: Dry-run the Kubernetes upgrade to preview changes**

Run:
```bash
./scripts/upgrade-kubernetes.sh -v 1.36.2 -d -y
```
Expected: prints `talosctl --nodes talos.bruner.lab upgrade-k8s --to 1.36.2 --dry-run`, then a diff of component image updates from `1.35.x` → `1.36.2` with **no errors**. **If the dry-run errors, STOP and investigate.**

- [ ] **Step 2: Execute the Kubernetes upgrade**

Run:
```bash
./scripts/upgrade-kubernetes.sh -v 1.36.2 -y
```
Expected: each control-plane component (`kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `kube-proxy`) updates, then kubelets roll node-by-node, ending with a success message and exit `0`. **If exit code is non-zero, STOP.**

- [ ] **Step 3: Verify every node's kubelet is on v1.36.2**

Run:
```bash
kubectl get nodes -o wide
```
Expected: all 9 nodes `Ready` with `VERSION=v1.36.2` and `OS-IMAGE=Talos (v1.13.5)`. (This also resolves the pre-existing worker-01 kubelet skew at v1.35.0.)

- [ ] **Step 4: Verify control-plane component versions**

Run:
```bash
kubectl get pods -n kube-system -l tier=control-plane -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```
Expected: apiserver/controller-manager/scheduler images all tagged `v1.36.2`.

- [ ] **Step 5: Final post-upgrade health check**

Run:
```bash
talosctl --nodes 192.168.10.21 health && kubectl get pods -A | grep -vE 'Running|Completed' || echo "all pods healthy"
```
Expected: `talosctl health` all `OK`; the pod check prints only the header (or `all pods healthy`) — no crash-looping/pending pods caused by the upgrade.

No commit (live cluster only).

---

## Task 6: Sync repo defaults and fix doc inconsistencies

**Files:**
- Modify: `scripts/lib/consts.sh:23`
- Modify: `CLAUDE.md` (the "Upgrading Talos OS" section — node order line)
- Modify: `docs/upgrading.md:13-16,41-43,55-56`

**Interfaces:**
- Consumes: the now-current cluster versions.
- Produces: repo defaults that match the live cluster, so a future `generate-config.sh` (e.g. when adding a node) emits a v1.36.2 config and docs reflect reality.

- [ ] **Step 1: Bump the default Kubernetes version**

In `scripts/lib/consts.sh`, change:
```bash
DEFAULT_KUBERNETES_VERSION="1.35.1"
```
to:
```bash
DEFAULT_KUBERNETES_VERSION="1.36.2"
```

- [ ] **Step 2: Verify generate-config now defaults to 1.36.2**

Run a no-write smoke check of the variable:
```bash
grep DEFAULT_KUBERNETES_VERSION scripts/lib/consts.sh
```
Expected: `DEFAULT_KUBERNETES_VERSION="1.36.2"`.

- [ ] **Step 3: Fix the contradictory upgrade-order line in CLAUDE.md**

In `CLAUDE.md`, under "Upgrading Talos OS", replace:
```
Upgrades are done **one node at a time** using `upgrade-talos.sh`. Always upgrade workers before control plane nodes. See `docs/upgrading.md` for full details.
```
with:
```
Upgrades are done **one node at a time** using `upgrade-talos.sh`. Always upgrade **control plane nodes before workers** (matches `docs/upgrading.md` and the `talos-worker-upgrade` skill). See `docs/upgrading.md` for full details.
```

- [ ] **Step 4: Refresh stale example versions in docs/upgrading.md**

In `docs/upgrading.md`, update the Kubernetes examples from `1.32.0` to `1.36.2`:
```bash
talosctl --nodes control-01 upgrade-k8s --to 1.36.2 --dry-run
talosctl --nodes control-01 upgrade-k8s --to 1.36.2
```
update the Talos example from `v1.8.4` to `v1.13.5`:
```bash
❯ ./scripts/upgrade-talos.sh -t control -n 192.168.10.21 -v v1.13.5
```
and bump the two doc links from `/v1.9/` to `/v1.13/`:
```
[official-talos]: https://www.talos.dev/v1.13/talos-guides/upgrading-talos/#faqs
[official-k8s]: https://www.talos.dev/v1.13/kubernetes-guides/upgrading-kubernetes/
```

- [ ] **Step 5: Confirm no CRLF was introduced**

Run:
```bash
file scripts/lib/consts.sh CLAUDE.md docs/upgrading.md
```
Expected: no `CRLF` in the output (LF only).

- [ ] **Step 6: Commit the repo sync**

```bash
git add scripts/lib/consts.sh CLAUDE.md docs/upgrading.md
git commit -m "chore: sync versions to Talos v1.13.5 / Kubernetes 1.36.2 after upgrade

Bump DEFAULT_KUBERNETES_VERSION to 1.36.2, fix the control-plane-first
upgrade order in CLAUDE.md, and refresh stale example versions and doc
links in docs/upgrading.md.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Final verification and memory update

**Files:**
- Modify: memory `MEMORY.md` and `project_upgrade_debt.md` (in `/Users/colinbruner/.claude/projects/-Users-colinbruner-code-colinbruner-homelab-talos/memory/`).

**Interfaces:**
- Consumes: the completed upgrade.
- Produces: a correct memory index and an updated upgrade-state record for future sessions.

- [ ] **Step 1: Full final verification**

Run:
```bash
talosctl version --nodes 192.168.10.21,192.168.10.31 | grep -A1 NODE
kubectl get nodes -o wide
```
Expected: all nodes Talos `v1.13.5`, Kubernetes `v1.36.2`, all `Ready`.

- [ ] **Step 2: Fix the stale MEMORY.md index entry**

The index lists `upgrade_debt.md`, but the actual file is `project_upgrade_debt.md`. Correct the line in `MEMORY.md` to point at `project_upgrade_debt.md`.

- [ ] **Step 3: Update the upgrade-state memory**

In `project_upgrade_debt.md`, add a dated entry recording the 2026-06-27 upgrade to Talos v1.13.5 / Kubernetes v1.36.2 and that all 9 nodes are at parity. Remove any "remaining work" items that are now done.

- [ ] **Step 4: Confirm cluster stability after a soak**

After ~15 minutes, re-run:
```bash
talosctl --nodes 192.168.10.21 health && kubectl get pods -A | grep -vE 'Running|Completed' || echo "all pods healthy"
```
Expected: all `OK` / healthy. Upgrade complete.

---

## Rollback Notes

- **Talos OS:** Talos keeps the previous boot partition. If a single node fails to come up healthy, `talosctl rollback --nodes <ip>` reverts it to the prior OS version. Do this before touching the next node.
- **Kubernetes:** `talosctl upgrade-k8s` is reversible to the prior minor: `./scripts/upgrade-kubernetes.sh -v 1.35.1 -y` (single-minor downgrade only).
- **etcd:** if control-plane data is lost, recover from the snapshot taken in Task 2 (`talosctl bootstrap --recover-from=<snapshot>` flow per Talos disaster-recovery docs).
- **Golden rule:** never proceed to the next node/phase while the current one is unhealthy.
