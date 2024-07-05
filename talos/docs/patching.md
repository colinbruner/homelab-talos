# Patching
For full documentation and some examples, see [patching][patching].

## Live Machines
This is editting the configuration of a machine(s) as it is running live.

### Types of Patches
Talos supports two types of patches:
- [Strategic Merge][strategic]
- [JSON Patches (RFC6902)][rfc6902]

Strategic merging allows merging 1 yaml configuration file into another. For non-array values, this typically results in the merging value `overwriting` the existing value. For array values, the merginv values are `appended` to the end of the array.

JSON Patching allows more fine grained control of various aspects of the configuration.

#### Strategic Merging
```bash
# Target controlplane IP Address
NODE_IP=192.168.1.10

# Patch live running machineconfig (mc)
talosctl patch mc \
  --talosconfig config/talosconfig \
  -e $NODE_IP \
  -n $NODE_IP \
  --patch @patch.yaml
patched MachineConfigs.config.talos.dev/v1alpha1 at the node 192.168.1.10
Applied configuration without a reboot
```

#### JSON Patches (RFC6902)
```bash
# Target controlplane IP Address
NODE_IP=192.168.1.10

# Patch live running machineconfig (mc)
talosctl patch mc \
  --talosconfig config/talosconfig \
  -e $NODE_IP \
  -n $NODE_IP \
  --patch @patch.yaml
patched MachineConfigs.config.talos.dev/v1alpha1 at the node 192.168.1.10
Applied configuration without a reboot
```

## Configuration File Patching
This type of patching is effectively just editting a local file. These configurations changes will still need to be applied to running instance(s).

```bash
NODE_IP=192.168.1.10 # Target controlplane IP Address
# Patch generated machine configuration, requires local files
talosctl machineconfig patch \
  --talosconfig config/talosconfig \
  -n $NODE_IP \
  -e $NODE_IP \
  --patch @patch.yaml \
    config/controlplane.yaml
```

### Script Example
This type of patching can be handle by regenerating configuration files originally generated during [bootstrapping](./bootstrap.md).

```bash
# Supplying '-f' will force overwrite any existing configuration files
$ ./scripts/generate-config.sh -t worker -n worker-01 -e 192.168.1.22 -f
# NOTE: Before running, I copied the original worker-01.yaml to my existing directory
# After rerunning, we see additional changes now reflected.
$ diff worker-01.yaml config/workers/worker-01.yaml
12a13,14
>         extraArgs:
>             rotate-server-certificates: "true"

# Apply
```

[strategic]: https://www.talos.dev/v1.7/talos-guides/configuration/patching/#strategic-merge-patches
[rfc6902]: https://www.talos.dev/v1.7/talos-guides/configuration/patching/#rfc6902-json-patches