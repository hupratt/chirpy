#!/bin/bash

# move the binaries we downloaded earlier to the controlplane
# and configure the CNI: 
# to ensure network traffic crossing the CNI Container Network Interface
# `bridge` network is processed by `iptables`, load and configure the `br-netfilter` kernel module

for HOST in node01 node02; do
  SUBNET=$(grep ${HOST} machines.txt | cut -d " " -f 4)
  sed "s|SUBNET|$SUBNET|g" \
    configs/10-bridge.conf > 10-bridge.conf

  sed "s|SUBNET|$SUBNET|g" \
    configs/kubelet-config.yaml > kubelet-config.yaml

  scp 10-bridge.conf kubelet-config.yaml \
  root@${HOST}:~/
done


for HOST in node01 node02; do
  scp \
    downloads/worker/* \
    downloads/client/kubectl \
    configs/99-loopback.conf \
    configs/containerd-config.toml \
    configs/kube-proxy-config.yaml \
    units/containerd.service \
    units/kubelet.service \
    units/kube-proxy.service \
    root@${HOST}:~/
done

for HOST in node01 node02; do
  scp \
    downloads/cni-plugins/* \
    root@${HOST}:~/cni-plugins/
done


for HOST in node01 node02; do
ssh root@${HOST} <<'EOF'
apt-get update
apt-get -y install socat conntrack ipset kmod
swapon --show
swapoff -a
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
mv crictl kube-proxy kubelet runc \
  /usr/local/bin/
mv containerd containerd-shim-runc-v2 containerd-stress /bin/
mv cni-plugins/* /opt/cni/bin/
mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
modprobe br-netfilter
echo "br-netfilter" >> /etc/modules-load.d/modules.conf
echo "net.bridge.bridge-nf-call-iptables = 1" \
  >> /etc/sysctl.d/kubernetes.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" \
  >> /etc/sysctl.d/kubernetes.conf
sysctl -p /etc/sysctl.d/kubernetes.conf
mkdir -p /etc/containerd/
mv containerd-config.toml /etc/containerd/config.toml
mv containerd.service /etc/systemd/system/
mv kubelet-config.yaml /var/lib/kubelet/
mv kubelet.service /etc/systemd/system/
mv kube-proxy-config.yaml /var/lib/kube-proxy/
mv kube-proxy.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy
sleep 10
systemctl is-active kubelet
EOF
done

ssh root@controlplane "kubectl get nodes --kubeconfig admin.kubeconfig"
