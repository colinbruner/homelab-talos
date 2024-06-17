# Build
The following is custom built src code for homelab.

## iPXE
We're building a custom `undionly.kpxe` file with an embedded script to break the bootloader infinite chain. This seems to be the best path forward using using Unifi's DHCP Server instead of a ISC DHCP Server on Linux.

### chain.ipxe
This file is intended to be embedded in the `undionly.kpxe` binary to break the chain loading process.
https://ipxe.org/howto/chainloading

### Building
Building on WSL (Ubuntu), the following was required: 

```bash
# Install prereqs
$ sudo apt-get install liblzma-dev -y

# Build - will produce 'bin/undionly.kpxe'
$ ./build.sh
```