# Talos
I've documented the initial bootstrapping of a single control node + three worker nodes, all running as VMs on Proxmox. 

This documentation is captured below in the following components:
- [Bootstrap](./docs/bootstrap.md)
- [Config](./docs/config.md)
- [Patching](./docs/patching.md)
- [Upgrading](./docs/upgrading.md)

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
