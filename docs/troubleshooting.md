# Troubleshooting

## ArgoCD login redirect loop

**Symptom:** ArgoCD login page continuously redirects back to itself after entering credentials. Authentication never completes.

**Root cause:** Worker nodes have `cluster.controlPlane.endpoint` pointing to a single control plane IP address (e.g. `https://192.168.10.20:6443`) instead of the cluster DNS record (`https://talos.bruner.lab:6443`). When the endpoint is a single IP, OIDC/SSO callback routing breaks and ArgoCD cannot complete the login flow.

**Fix:** Ensure all worker machine configs have the DNS endpoint set:

```yaml
cluster:
  controlPlane:
    endpoint: https://talos.bruner.lab:6443
```

Regenerate and reapply worker configs:

```bash
for i in 1 2 3 4 5 6; do
  ./scripts/generate-config.sh -n "worker-0${i}"
done

for i in 1 2 3 4 5 6; do
  ./scripts/apply-config.sh -n "worker-0${i}" -e "192.168.10.3${i}"
done
```

Verify the endpoint on a running node:

```bash
talosctl -n 192.168.10.31 get machineconfig -o yaml | grep -A 1 "endpoint:"
```

**Reference:** <https://github.com/siderolabs/talos/issues/9147#issuecomment-2332549152>
