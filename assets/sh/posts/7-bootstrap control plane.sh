#!/bin/bash

# move the binaries we downloaded earlier to the controlplane

scp \
  downloads/controller/kube-apiserver \
  downloads/controller/kube-controller-manager \
  downloads/controller/kube-scheduler \
  downloads/client/kubectl \
  units/kube-apiserver.service \
  units/kube-controller-manager.service \
  units/kube-scheduler.service \
  configs/kube-scheduler.yaml \
  configs/kube-apiserver-to-kubelet.yaml \
  root@controlplane:~/

ssh root@controlplane <<'EOF'
mkdir -p /etc/kubernetes/config
mv kube-apiserver \
kube-controller-manager \
kube-scheduler kubectl \
/usr/local/bin/
mkdir -p /var/lib/kubernetes/
mv ca.crt ca.key \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  encryption-config.yaml \
  /var/lib/kubernetes/
mv kube-apiserver.service \
  /etc/systemd/system/kube-apiserver.service
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
mv kube-controller-manager.service /etc/systemd/system/
mv kube-scheduler.kubeconfig /var/lib/kubernetes/
mv kube-scheduler.yaml /etc/kubernetes/config/
mv kube-scheduler.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable kube-apiserver \
  kube-controller-manager kube-scheduler
systemctl start kube-apiserver \
  kube-controller-manager kube-scheduler
sleep 10
systemctl is-active kube-apiserver
kubectl cluster-info \
  --kubeconfig admin.kubeconfig
EOF


#  allow the Kubernetes API Server to access the Kubelet API on each worker node
ssh root@controlplane <<'EOF'
kubectl apply -f kube-apiserver-to-kubelet.yaml \
  --kubeconfig admin.kubeconfig
EOF

sleep 10
curl --cacert ca.crt \
  https://controlplane.kubernetes.local:6443/version

