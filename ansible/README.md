# WSL

Using WSL with Ansible will require installing SSH private key locally.

1. Download private key
2. Save to ~/.ssh/<key>
3. Lock down key `chmod 600 ~/.ssh/<key>`
4. Start SSH Agent `eval $(ssh-agent)`
5. Add Keys `ssh-add ~/.ssh/<key>`

# Bootstrap

```bash
# This will update packages and add NOPASSWD sudo for user 'colin'
$ ansible-playbook -i inv --ask-become-pass bootstrap.yml
```

# Install

```bash
#
$ ansible-playbook -i inv pxe.yml
```
