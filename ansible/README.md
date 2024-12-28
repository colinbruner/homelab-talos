# WSL

Using WSL with Ansible will require installing SSH private key locally.

1. Download private key
2. Save to ~/.ssh/<key>
3. Lock down key `chmod 600 ~/.ssh/<key>`
4. Start SSH Agent `eval $(ssh-agent)`
5. Add Keys `ssh-add ~/.ssh/<key>`

# Add Keys to VM
Run the following, inspect first to make sure IPs are correct..

```bash
# Create ~/.ssh and add pubkey to authorized_keys file
$ ./add-key.sh
```

# Bootstrap

```bash
# This will update packages and add NOPASSWD sudo for user 'colin'
$ ansible-playbook -i inv --ask-become-pass bootstrap.yml
```

# Requirements

Require the Ansible's posix collection for utilities such as mounting NFS drives

```bash
$ ansible-galaxy collection install -r requirements/galaxy.yml
```

# Install

```bash
#
$ ansible-playbook -i inv pxe.yml
```
