# Skill: Talos Node Upgrade

Upgrade Talos OS sequentially across all cluster nodes using `./scripts/upgrade-talos.sh`. Control plane nodes are upgraded first, then workers.

## Instructions

When the user invokes this skill, ask for any missing arguments:

- **Talos version** to upgrade to (e.g. `v1.9.4`) — this is the only required input

Node IPs are auto-discovered from the live cluster (no manual IP list needed).

### Step 1: Gather Inputs

If the user did not provide a version, ask:
> What Talos version should nodes be upgraded to? (e.g. `v1.9.4`)

### Step 2: Auto-Discover Nodes

Run the following two commands to discover control plane and worker IPs from the live cluster:

```bash
# Control plane node IPs
kubectl get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

# Worker node IPs
kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
  -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
```

Display the discovered lists to the user:

```text
Discovered control plane nodes: 192.168.10.20, 192.168.10.22, 192.168.10.23
Discovered worker nodes:        192.168.10.31, 192.168.10.32, ...
```

Confirm with the user before proceeding.

### Step 3: Upgrade — Control Plane First, Then Workers

Process nodes in this order:

1. Control plane nodes (sorted by IP)
2. Worker nodes (sorted by IP)

For each node, repeat the following two sub-steps:

#### 3a. Run the Upgrade

```bash
./scripts/upgrade-talos.sh -t <control|worker> -n <NODE_IP> -v <VERSION> -y
```

- Use `-t control` for control plane nodes, `-t worker` for workers
- The `-y` flag auto-confirms the prompt (no `echo y |` pipe needed)
- Use a **600 second timeout** per node (full reboot + cluster rejoin)
- **Stop immediately** if the script exits non-zero

#### 3b. Post-Upgrade Validation

After the script completes, validate the node has rejoined by polling until `Ready`:

```bash
kubectl get nodes -o wide --no-headers | grep <NODE_IP>
```

Poll every **10 seconds**, up to **120 seconds**. The node must show `Ready` status before proceeding to the next node.

Alternatively (or additionally), check via:

```bash
talosctl get members -o json
```

Verify the member entry for `<NODE_IP>` has `operatingSystem` populated.

**If validation times out**, stop and do not continue to remaining nodes.

### Step 4: Failure Handling

If any node fails (non-zero exit or validation timeout):

- Report which node failed and show relevant error output
- Do not continue to subsequent nodes
- Suggest diagnostics:

  ```bash
  talosctl dmesg --nodes <NODE_IP>
  talosctl logs --nodes <NODE_IP>
  ```

### Step 5: Summary Report

After all nodes complete (or on first failure), print a summary table:

```text
Node            | Type    | IP              | Result
----------------|---------|-----------------|--------
control-01      | control | 192.168.10.20   | OK
control-02      | control | 192.168.10.22   | OK
control-03      | control | 192.168.10.23   | OK
worker-01       | worker  | 192.168.10.31   | OK
worker-02       | worker  | 192.168.10.32   | FAILED
worker-03       | worker  | 192.168.10.33   | SKIPPED
```

---

## Notes

- **Upgrade order: control plane first, then workers** (per `docs/upgrading.md`)
- Control plane upgrades automatically use `--preserve` via the script's internal logic
- The `-y` flag was added to `upgrade-talos.sh` to support non-interactive mode
- Worker IPs: `192.168.10.31`–`192.168.10.39` | Control plane IPs: `192.168.10.20`, `.22`, `.23`
- The script lives at `./scripts/upgrade-talos.sh` relative to the repo root
