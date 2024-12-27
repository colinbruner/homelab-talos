# Upgrading


## Before Upgrading
Review the the [official documentation][official]:

> For example, if upgrading from Talos 1.0 to Talos 1.2.4, the recommended upgrade path would be:
    > - upgrade from 1.0 to latest patch of 1.0 - to v1.0.6
    > - upgrade from v1.0.6 to latest patch of 1.1 - to v1.1.2
    > - upgrade from v1.1.2 to v1.2.4

## Getting Ready
1. Edit the [upgrade script](./scripts/upgrade-talos.sh) to specify the version at top.
2. Run the script on WORKERS first
3. Run the script on CONTROL node(s) last

## Running the Upgrade
```bash
# Worker Node
❯ ./scripts/upgrade-talos.sh -t control -n 192.168.1.32
...
watching nodes: [192.168.1.32]
    * 192.168.1.32: post check passed

# Control Node
❯ ./scripts/upgrade-talos.sh -t control -n 192.168.1.20
Will run the following command:
talosctl upgrade --wait --debug --nodes 192.168.1.20 --image ghcr.io/siderolabs/installer:v1.7.7 --preserve
Continue? [y/N] y
◲ watching nodes: [192.168.1.20]
    * 192.168.1.20: waiting for actor ID
```

[official]: https://www.talos.dev/v1.9/talos-guides/upgrading-talos/#faqs
