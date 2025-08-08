#!/bin/bash

# provision TLS certificates

sed -i "s|node-0|node01|g" ca.conf
sed -i "s|Node-0|Node01|g" ca.conf
sed -i "s|node-1|node02|g" ca.conf
sed -i "s|Node-1|Node02|g" ca.conf
sed -i "s|server.kubernetes.local|controlplane.kubernetes.local|g" ca.conf


openssl genrsa -out ca.key 4096
openssl req -x509 -new -sha512 -noenc \
-key ca.key -days 3653 \
-config ca.conf \
-out ca.crt

certs=(
  "admin" "node01" "node02"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

for i in ${certs[*]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"

  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done

for host in node01 node02; do
  ssh root@${host} mkdir /var/lib/kubelet/

  scp ca.crt root@${host}:/var/lib/kubelet/

  scp ${host}.crt \
    root@${host}:/var/lib/kubelet/kubelet.crt

  scp ${host}.key \
    root@${host}:/var/lib/kubelet/kubelet.key
done


scp \
  ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  root@controlplane:~/