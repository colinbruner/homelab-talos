# Skill: Talos Worker Upgrade

Upgrade Talos OS sequentially across one or more worker nodes using `./scripts/upgrade-talos.sh`.

## Instructions

When the user invokes this skill, ask them for any missing arguments:
- **Node IPs or range** (e.g. `192.168.10.31` to `192.168.10.36`, or a list of IPs)
- **Talos version** to upgrade to (e.g. `v1.9.4`)

Then execute the upgrade sequentially, one node at a time, following these rules:

### Execution Rules

1. Run the script for each node in order:
   ```bash
   echo "y" | ./scripts/upgrade-talos.sh -t worker -n <NODE_IP> -v <VERSION>
   ```
2. **Before running**, confirm the command that will be executed with the user.
3. **Auto-confirm** the script's `Continue? [y/N]` prompt by piping `y` via stdin.
4. **Wait** for the script to fully complete (look for `post check passed` in output) before moving to the next node.
5. **Stop immediately** if any node upgrade fails (non-zero exit code or absence of `post check passed`). Do not proceed to remaining nodes.
6. Report success or failure for each node as it completes.

### Success Indicator

A successful upgrade ends with:
```
"<NODE_IP>": events check condition met
"<NODE_IP>": post check passed
```

### Failure Handling

If any node fails:
- Report which node failed and show the relevant error output
- Do not continue to subsequent nodes
- Suggest checking `talosctl dmesg --nodes <NODE_IP>` or `talosctl logs --nodes <NODE_IP>` for diagnostics

### Example Invocation

User: "Upgrade workers .31 through .36 to v1.9.4"

Run in sequence:
- `echo "y" | ./scripts/upgrade-talos.sh -t worker -n 192.168.10.31 -v v1.9.4`
- (wait for success)
- `echo "y" | ./scripts/upgrade-talos.sh -t worker -n 192.168.10.32 -v v1.9.4`
- (wait for success)
- ... continue through .36

Use a **600 second timeout** per node (upgrades involve a full reboot and cluster rejoin cycle).

### Notes

- Worker nodes are in the range `192.168.10.31` – `192.168.10.39`
- Control plane nodes use `-t control` and require the `--preserve` flag (handled by the script)
- The script lives at `./scripts/upgrade-talos.sh` relative to the repo root
- Always upgrade workers before control plane nodes
