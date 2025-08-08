SERVER_IP=$(grep controlplane machines.txt | cut -d " " -f 1)
NODE_0_IP=$(grep node01 machines.txt | cut -d " " -f 1)
NODE_0_SUBNET=$(grep node01 machines.txt | cut -d " " -f 4)
NODE_1_IP=$(grep node02 machines.txt | cut -d " " -f 1)
NODE_1_SUBNET=$(grep node02 machines.txt | cut -d " " -f 4)

echo $SERVER_IP
echo $NODE_0_IP
echo $NODE_0_SUBNET
echo $NODE_1_IP
echo $NODE_1_SUBNET


ssh root@controlplane <<EOF
  ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF


ssh root@node01 <<EOF
  ip route add ${NODE_1_SUBNET} via ${NODE_1_IP}
EOF

ssh root@node02 <<EOF
  ip route add ${NODE_0_SUBNET} via ${NODE_0_IP}
EOF

ssh root@controlplane ip route
ssh root@node01 ip route
ssh root@node02 ip route

# verify encryption for secrets is working

kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

ssh root@controlplane \
    'etcdctl get /registry/secrets/default/kubernetes-the-hard-way | hexdump -C'

kubectl create deployment nginx \
  --image=nginx:latest

sleep 30

kubectl get pods -l app=nginx

# port forward and query locally

# POD_NAME=$(kubectl get pods -l app=nginx \
#   -o jsonpath="{.items[0].metadata.name}")

# echo $POD_NAME

# kubectl port-forward $POD_NAME 8080:80

# verify connectivity in another terminal

# curl --head http://127.0.0.1:8080

kubectl expose deployment nginx \
  --port 80 --type NodePort

NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

NODE_NAME=$(kubectl get pods \
  -l app=nginx \
  -o jsonpath="{.items[0].spec.nodeName}")

echo "Service is now exposed over the NodePort: http://${NODE_NAME}:${NODE_PORT}"

curl -I http://${NODE_NAME}:${NODE_PORT}