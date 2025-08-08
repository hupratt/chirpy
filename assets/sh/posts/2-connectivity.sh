#!/bin/bash

# configure the hosts, connectivity over SSH and the Host Lookup Table

cat <<EOF > machines.txt
192.168.3.81 controlplane.kubernetes.local controlplane
192.168.3.82 node01.kubernetes.local node01 10.200.0.0/24
192.168.3.83 node02.kubernetes.local node02 10.200.1.0/24
EOF


key_file="$HOME/.ssh/id_rsa"

# Generate key only if it doesn't exist
if [ ! -f "$key_file" ]; then
  ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "admin@thekor.eu"
else
  echo "Key already exists: $key_file"
fi

while read IP FQDN HOST SUBNET; do
  ssh-copy-id root@${IP}
done < machines.txt

hostnamectl set-hostname jumphost

while read IP FQDN HOST SUBNET; do
    CMD="sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl set-hostname ${HOST}
done < machines.txt

while read IP FQDN HOST SUBNET; do
  ssh -n root@${IP} hostname --fqdn
done < machines.txt

echo "" > hosts
echo "# Kubernetes The Hard Way" >> hosts

while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> hosts
done < machines.txt

cat hosts >> /etc/hosts

for host in controlplane node01 node02
   do ssh root@${host} hostname
done

while read IP FQDN HOST SUBNET; do
  scp hosts root@${HOST}:~/
  ssh -n \
    root@${HOST} "cat hosts >> /etc/hosts"
done < machines.txt

