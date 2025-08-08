#!/bin/bash

# move the binaries we downloaded earlier to the controlplane

scp \
  downloads/controller/etcd \
  downloads/client/etcdctl \
  units/etcd.service \
  root@controlplane:~/

ssh root@controlplane <<'EOF'
mv etcd etcdctl /usr/local/bin/
mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
cp ca.crt kube-api-server.key kube-api-server.crt /etc/etcd/
mv etcd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
etcdctl member list
EOF

