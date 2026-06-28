# Upgrading

## Kubernetes

### Before Upgrading

Review the the [official documentation][official-k8s]:

### Upgrading

```bash
# See diff of changes, no real changes made.. dryrun
talosctl --nodes control-01 upgrade-k8s --to 1.36.2 --dry-run

# Automated upgrade of control & workers to 1.36.2
talosctl --nodes control-01 upgrade-k8s --to 1.36.2
```

## Talos

### Before Upgrading

Review the the [official documentation][official-talos]:

> For example, if upgrading from Talos 1.0 to Talos 1.2.4, the recommended upgrade path would be:
>
> - upgrade from 1.0 to latest patch of 1.0 - to v1.0.6
> - upgrade from v1.0.6 to latest patch of 1.1 - to v1.1.2
> - upgrade from v1.1.2 to v1.2.4

### Getting Ready

1. Ensure you're upgrading to a compatible version
2. Run the script on CONTROL node(s) first
3. Run the script on wORKERS nodes last

### Running the Upgrade

```bash
# Control Node
❯ ./scripts/upgrade-talos.sh -t control -n 192.168.10.21 -v v1.13.5
Will run the following command:
talosctl upgrade --nodes 192.168.10.21 --image ghcr.io/siderolabs/installer:v1.13.5 --wait --debug --preserve
Continue? [y/N] y
◲ watching nodes: [192.168.10.21]
    * 192.168.10.21: waiting for actor ID

# Worker Node
❯ ./scripts/upgrade-talos.sh -t worker -n 192.168.10.31 -v v1.13.5
...
watching nodes: [192.168.10.31]
    * 192.168.10.31: post check passed
```

[official-talos]: https://www.talos.dev/v1.13/talos-guides/upgrading-talos/#faqs
[official-k8s]: https://www.talos.dev/v1.13/kubernetes-guides/upgrading-kubernetes/
