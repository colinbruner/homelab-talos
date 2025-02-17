#!/bin/bash

if [[ $1 == "" ]] | [[ $2 == "" ]]; then
  echo "Usage: $0 <user> <host>"
  exit 1
fi

PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPE/CB9u3hsHE6/8vnQs4ZB4KFNDQsTKkce5SrPQD4gH"
CMD="mkdir -p .ssh && echo $PUBKEY > .ssh/authorized_keys && chmod 600 .ssh/authorized_keys"

ssh $1@$2 $CMD
echo "Done"
