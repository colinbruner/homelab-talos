# Bootstrap
The following defines how to bootstrap a new Talos cluster

## Inital Configuration
Four scripts can be used for initial bootstrapping a single Talos control plane node.

1. generate-config.sh: generates configuration files and secrets for a single node cluster.
2. apply-config.sh: applies configuration files to a single node cluster.
3. bootstrap-kubernetes.sh: bootstraps the kubernetes controlplane.
4. download-config.sh: downloads the kubeconfig used to interact with Kubernetes on Talos Linux

After generating configuration (defined below), modify as needed.

### Generating Config
The [bootstrap-config.sh](./bootstrap-config.sh) script is used to generate configurations and bootstrap a single node IP address.

```bash
# $1=NODE IP
# $2=Cluster Name (default: homelab)
$ ./bootstrap-config.sh 192.168.1.157 my-cluster-name
generating PKI and tokens
Created config/controlplane.yaml
Created config/worker.yaml
Created config/talosconfig

# NOTE: These files are important and will be used when joining additional nodes to the cluster
$ ls -l config/
total 84
-rw-r--r-- 1 colinbruner colinbruner 32844 Jun 18 17:34 controlplane.yaml
-rw------- 1 colinbruner colinbruner  8861 Jun 18 17:34 secrets.yaml
-rw-r--r-- 1 colinbruner colinbruner  1563 Jun 18 17:34 talosconfig
-rw-r--r-- 1 colinbruner colinbruner 26870 Jun 18 17:34 worker.yaml
```

### Apply Config
The [apply-config.sh](./apply-config.sh) script is used to apply configurations to a single node IP address.

Before running, modify the generated configuration files in [config/](./config/) as necessary. If modifying controlplane.yaml to statically set IPs, there are a few separate locations update or add desired IP address to. Search controlplane.yaml for the IP address used in the `bootstrap-config.sh` command and replace as necessary.
```bash
# $1=Node IP to Configure
# $2=Name of file in ./config/ to use
$ ./apply-config.sh 192.168.1.157 controlplane.yaml
```

### Bootstrap Kubernetes
The following will bootstrap the single Talos controlplane node with Kubernetes.

For more information see [kubernetes bootstrap][kboot]
```bash
$ ./bootstrap-kubernetes.sh 192.168.1.157
```

### Download Config
The following downloads the kubeconfig for authenticating with the newly bootstrapped kubernetes cluster.
```bash
$ ./download-config.sh 192.168.1.157
```