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

The primary files generated here are `secrets.yaml`, `talosconfig`, and `control-01.yaml`, the file of which is named after the `-n` input name of the node.
```bash
# generate configuration to bootstrap controlplane
$ ./scripts/generate-config.sh -t control -n control-01 -e 192.168.1.157 -c homelab
creating: homelab/talos/patches/strategic-patch.yaml
creating: homelab/talos/patches/json-patch.yaml
creating: homelab/talos/scripts/../config/secrets.yaml
creating: homelab/talos/scripts/../config/control-01.yaml
creating: homelab/talos/scripts/../config/talosconfig
```

#### Worker

After bootstrapping, you'll also want to generate configuration for worker nodes. These configuration files are saved in a (config/workers/)[../configs/workers/] directory.

```bash
# generate configuration to bootstrap worker nodes
$ ./scripts/generate-config.sh -t worker -n worker-01 -e 192.168.1.201
creating: homelab/talos/patches/worker-01/strategic-patch.yaml
creating: homelab/talos/scripts/../config/workersworker-01.yaml
```

### Apply Configs
Running the below script from the [talos/](../) directory will apply configuration and begin bootstraping a Talos cluster control node.

The below script will cause the initial control node to be reconfigured. After this happens, the node will remain in a 'Booting' stage until the following bootstrap configurations can be applied. Refer to [Bootstrap Kubernetes][#bootstrap kubernetes] section below.
```bash
# applies configuration based upon a generated control-01.yaml file
$ ./scripts/apply-config.sh -t control -e 192.168.1.10 -n control-01
```

#### Worker
The script below will apply configuration to a new worker node.
```bash
# applies configuration based upon a generated worker-01.yaml file
$ ./scripts/apply-config.sh -t worker -e 192.168.1.199 -n worker-01
```

## Control Only (bootstrapping)
The following section applies only to the initial bootstrapping process of a single control node.

### Bootstrap Kubernetes
Once Talos Linux is up and online, you'll need to bootstrap kubernetes. The following script will bootstrap your kubernetes cluster.

```bash
# bootstraps the kubernetes cluster on running Talos Linux, this will only need to be done once
$ ./scripts/bootstrap-kubernetes.sh -e 192.168.1.10
```

At this point everything on the Talos dashboard should indicate healthy and running. The following step will download the Kubeconfig which will allow you to connect directly to the controlplane.

### Download Configs
Now that the Talos cluster and kubernetes are both up and online, you'll need to download the kubeconfig for authenticating to your new kubernetes cluster.

```bash
# downloads the kubeconfig in the config/ directory, this file should be kept secret and save
$ ./scripts/download-config.sh -e 192.168.1.10
```

## Validation
The following will validate the health of the single node cluster and confirm you are able to authenticate and connect to it.

```bash
# The NODE_IP should be the IP address value, typically set within values/control-01.yaml
$ export NODE_IP="192.168.1.20"
$ export TALOSCONFIG=config/talosconfig
$ talosctl -n $NODE_IP -e $NODE_IP health
discovered nodes: ["192.168.1.20"]
waiting for etcd to be healthy: ...
waiting for etcd to be healthy: OK
waiting for etcd members to be consistent across nodes: ...
waiting for etcd members to be consistent across nodes: OK
waiting for etcd members to be control plane nodes: ...
waiting for etcd members to be control plane nodes: OK
waiting for apid to be ready: ...
waiting for apid to be ready: OK
waiting for all nodes memory sizes: ...
waiting for all nodes memory sizes: OK
waiting for all nodes disk sizes: ...
waiting for all nodes disk sizes: OK
waiting for kubelet to be healthy: ...
waiting for kubelet to be healthy: OK
waiting for all nodes to finish boot sequence: ...
waiting for all nodes to finish boot sequence: OK
waiting for all k8s nodes to report: ...
waiting for all k8s nodes to report: OK
waiting for all k8s nodes to report ready: ...
waiting for all k8s nodes to report ready: OK
waiting for all control plane static pods to be running: ...
waiting for all control plane static pods to be running: OK
waiting for all control plane components to be ready: ...
waiting for all control plane components to be ready: OK
waiting for kube-proxy to report ready: ...
waiting for kube-proxy to report ready: OK
waiting for coredns to report ready: ...
waiting for coredns to report ready: OK
waiting for all k8s nodes to report schedulable: ...
waiting for all k8s nodes to report schedulable: OK
```

[gc]: ../scripts/generate-config.sh
[ac]: ../scripts/apply-config.sh
[bk]: ../scripts/bootstrap-kubernetes.sh
[dc]: ../scripts/download-config.sh