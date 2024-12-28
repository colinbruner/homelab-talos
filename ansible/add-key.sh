#!/bin/bash

PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPE/CB9u3hsHE6/8vnQs4ZB4KFNDQsTKkce5SrPQD4gH"
CMD="mkdir -p .ssh && echo $PUBKEY > .ssh/authorized_keys && chmod 600 .ssh/authorized_keys"

ssh colin@192.168.10.4 $CMD
echo "Done"
