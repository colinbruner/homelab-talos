# WSL

Using WSL with Ansible will require installing SSH private key locally.

1. Download private key
2. Save to ~/.ssh/<key>
3. Lock down key `chmod 600 ~/.ssh/<key>`
4. Start SSH Agent `eval $(ssh-agent)`
5. Add Keys `ssh-add ~/.ssh/<key>`

# Prerequisites

## Add Keys to VM

Run the following, inspect first to make sure IPs are correct..

```bash
# Create ~/.ssh and add pubkey to authorized_keys file
$ ./add-key.sh
```

## Create NFS Share

We'll need to create an NFS share that will store images to boot off the network with.

QNAP Side:

1. Enable NFS Service
2. Create Shared Folder + Set Guest Access (NOTE: needs to be RW for Ansible image download)
3. Enable Access Right (see link below)

https://www.qnap.com/en-us/how-to/faq/article/how-to-enable-and-setup-host-access-for-nfs-connection

The location of the NFS Server is configurable with `nfs_server_addr` variables in the pxe role.

## Bootstrap

```bash
# This will update packages and add NOPASSWD sudo for user 'colin'
$ ansible-playbook -i inv --ask-become-pass bootstrap.yml
```

# Requirements

Require the Ansible's posix collection for utilities such as mounting NFS drives

```bash
$ ansible-galaxy collection install -r requirements/collections.yml
```

# Install

```bash
# Run Install with specified variables
$ ansible-playbook -i inv pxe.yml --extra-vars @vars/main.yml
```

# Unifi

Configure Network Boot on the appropriate network with the following:

`{{ pxe_server_addr }} undionly.kpxe`
