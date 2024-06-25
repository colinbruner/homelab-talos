# Bootstraping

## Overview
The bootstraping process is handled with 4 scripts defined in the [scripts/](./scripts) directory. This process will handle bootstraping a single control node followed by worker nodes.

- [generate-config.sh][gc]
- [apply-config.sh][ac]
- [bootstrap-kubernetes.sh][bk]
- [download-config.sh][dc]

## Configuration
Before bootstraping, confirm your desired configuration is set. This can be done by reviewing files in the [values](../values) and [templates/](../templates) directories.

For more information, view [configuration](./config.md).

## Control & Worker
The following two sections will apply to both control & worker nodes.

### Generate Configs
Running the below script from the [talos/](../) directory will generate configuration for bootstraping a Talos cluster.

```bash
# generate configuration for a single control node
$ ./scripts/generate-config.sh
```

After bootstrapping, you'll also want to generate configuration for worker nodes. These configuration files are saved in a (config/workers/)[../configs/workers/] directory.

```bash
$ ./scripts/generate-config.sh
```

### Apply Configs
Running the below script from the [talos/](../) directory will apply configuration and begin bootstraping a Talos cluster.

```bash
$ ./scripts/apply-config.sh
```

The script below will apply configuration to a new worker node.
```bash
$ ./scripts/apply-config.sh
```

## Control Only (bootstrapping)
The following section applies only to the initial bootstrapping process of a single control node.

### Bootstrap Kubernetes
Once Talos Linux is up and online, you'll need to bootstrap kubernetes. The following script will bootstrap your kubernetes cluster.

```bash
$ ./scripts/bootstrap-kubernetes.sh
```

### Download Configs
Now that the Talos cluster and kubernetes are both up and online, you'll need to download the kubeconfig for authenticating to your new kubernetes cluster.

```bash
$ ./scripts/download-config.sh
```

[gc]: ../scripts/generate-config.sh
[ac]: ../scripts/apply-config.sh
[bk]: ../scripts/bootstrap-kubernetes.sh
[dc]: ../scripts/download-config.sh