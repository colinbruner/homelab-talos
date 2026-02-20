# Talos

I've documented the initial bootstrapping of a single control node + three worker nodes, all running as VMs on Proxmox.

This documentation is captured below in the following components:

- [Bootstrap](./docs/bootstrap.md)
- [Config](./docs/config.md)
- [Patching](./docs/patching.md)
- [Upgrading](./docs/upgrading.md)

## Regenerating Kubeconfig & Talosconfig
Refer to the Talos discussion [here](https://github.com/siderolabs/talos/discussions/9457). 

Secrets for control nodes are in 1password along with current talosconfig, secrets, and kubeconfig. However, these generated certs do expire.

Overview as follows:
```bash
# OSX
# Extract the CA cert + key from the control plane config
yq -r .machine.ca.crt control-02.yaml | base64 -d > ca.crt
yq -r .machine.ca.key control-02.yaml | base64 -d > ca.key

# Generate fresh credentials
talosctl gen key --name admin
talosctl gen csr --key admin.key --ip 127.0.0.1
talosctl gen crt --ca ca --csr admin.csr --name admin

# Update existing `talosconfig` with the new values
# NOTE: edit the talosconfig for each step
# For ca: cat ca.crt | base64 | pbcopy
# For crt: cat admin.crt | base64 | pbcopy
# For key: cat admin.key | base64 | pbcopy
vim talosconfig

# Finally, generate new Kubeconfig.
talosctl kubeconfig -n 192.168.10.20 -e ... --talosconfig ./talosconfig
```

## Directories

- [config](./config/): generated configuration for Talos control and worker nodes.
- [docs](./docs/): documentation about bootstrapping and configuring Talos Linux.
- [patches](./patches/): patches that have been geneated by [scripts](./scripts) to apply to Talos Linux.
- [scripts](./scripts/): contains scripts intended to be ran from this directory.
- [templates](./templates/): yaml templates consumed by scripts to generate [patches](./patches/).
- [values](./values/): files, by hostname, containing specific values for that worker or control node.

## Official Links:

- [Applying Configuration][apply]
- [Patching][patching]
- [Troubleshooting][troubleshooting]

[apply]: https://www.talos.dev/v1.7/introduction/getting-started/#apply-configuration
[patching]: https://www.talos.dev/v1.7/talos-guides/configuration/patching/
[troubleshooting]: https://www.talos.dev/v1.7/introduction/troubleshooting/
