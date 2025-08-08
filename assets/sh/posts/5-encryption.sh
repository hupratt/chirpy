#!/bin/bash

# generate an encryption key and add it to the template 

export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

envsubst < configs/encryption-config.yaml \
  > encryption-config.yaml

scp encryption-config.yaml root@controlplane:~/