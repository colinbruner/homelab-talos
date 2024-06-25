# Bootstrap
The following defines how to bootstrap a new Talos cluster

## Inital Configuration
Four scripts, which can be found in [scripts/](./scripts/) directory, can be used for initial bootstrapping a single Talos control plane node.

1. [generate-config.sh][gc]: generates configuration files and secrets for control node and workers.
2. [apply-config.sh][ac]: applies configuration files to Talos Linux control node and workers.
3. [bootstrap-kubernetes.sh][bk]: bootstraps the kubernetes controlplane on a single control node.
4. [download-config.sh][dc]: downloads the kubeconfig used to interact with Kubernetes on Talos Linux.

### Generating Control Config
The [bootstrap-config.sh][bc] script is used to generate configurations and bootstrap a single node IP address.

```bash
# -t: type (control|worker)
# -n: name (string) of node, expected to match a file in values/
# -e: endpoint (string) the current IP of node
$ ./scripts/generate-config.sh \
    -t control \
    -n control-01 \
    -e 192.168.1.157 \
    -c homelab
creating: homelab/talos/patches/network.yaml
generating PKI and tokens
Created homelab/talos/scripts/../config/control-01.yaml
generating PKI and tokens
Created homelab/talos/scripts/../config/talosconfig

# NOTE: These files are important and will be used when joining additional nodes to the cluster
$ ls -l config/
total 32
-rw-r--r-- 1 colinbruner colinbruner 11384 Jun 22 23:40 controlplane.yaml
-rw------- 1 colinbruner colinbruner  8861 Jun 22 23:40 secrets.yaml
-rw-r--r-- 1 colinbruner colinbruner  1563 Jun 22 23:40 talosconfig
drwxr-xr-x 2 colinbruner colinbruner  4096 Jun 22 23:40 worker
```

### Apply Config
The [apply-config.sh][ac] script is used to apply configurations to a single node IP address.

```bash
# $1=Node IP to Configure
# $2=Name of file in ./config/ to use
$ ./apply-config.sh 192.168.1.157 controlplane.yaml
```

### Bootstrap Kubernetes
The following will bootstrap the single Talos controlplane node with Kubernetes.

For more information see [kubernetes bootstrap][kboot],
```bash
$ ./scripts/bootstrap-kubernetes.sh -e 192.168.1.20
```

### Download Config
The following downloads the kubeconfig for authenticating with the newly bootstrapped kubernetes cluster.
```bash
$ ./download-config.sh 192.168.1.157
```

[gc]: ./scripts/generate-config.sh
[ac]: ./scripts/apply-config.sh
[bk]: ./scripts/bootstrap-kubernetes.sh
[dc]: ./scripts/download-config.sh

[kboot]: https://www.talos.dev/v1.7/introduction/getting-started/#kubernetes-bootstrap