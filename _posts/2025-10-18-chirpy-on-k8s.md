---
title: k8s part 6 adding a blog to the cluster
author: hugo
date: 2025-10-18 09:11:00 +0200
categories: [Tutorial, infrastructure]
tags: [sysadmin, networking, k8s, ceph, storage, gitlab]
render_with_liquid: false
---

### Introduction

Time to level up this blog and practice what we preach. This article will look at how to deploy this jekyll blog [into the proxmox cluster we set up earlier](https://chirpy.thekor.eu/posts/k8s-p3/). The blog is currently orchestrated by a simple docker compose stack which usually gets updated by running a ``git pull && docker compose up -d --build``. Instead of doing it that way we will push the docker container into our gitlab registry and let our cluster trigger the pull from gitlab and start the deployment. We already have [wildcard certificates created with cert-manager](https://chirpy.thekor.eu/posts/k8s-p4-adding-tls/) so this should be pretty straightforward. 

![iframe](</assets/img/posts/jekyll_deployment_workflow.svg>)

This is the first stepping stone into actually migrating my whole docker stack into kubernetes. 

### Preparing for the deployment

Building the image is as simple as adding a couple of lines to the docker compose file to point to our gitlab's container registry

```yaml
services:
  jekyll_dev:
    build: .
    restart: unless-stopped
    image: registry.thekor.eu/github/chirpy:latest
    container_name: chirpy
    ports:
      - "4000:4000"
    volumes:
      - ./theproject:/home/myuser/app
    # This tells the web container to mount the `bundle` images'
    # /bundle volume to the `jekyll_dev` containers ~/bundle path.
    volumes_from:
      - bundle
  bundle:
    image: registry.thekor.eu/github/chirpy:latest
    restart: always
    volumes:
      - /bundle
```

To trigger the build and send it to the docker repository:

```bash
docker compose build
docker login registry.thekor.eu
docker push registry.thekor.eu/github/chirpy:latest
# passwords get saved here
cat ~/.docker/config.json
```

Or create a special release for the occasion: 

```bash
docker tag registry.thekor.eu/github/chirpy:latest registry.thekor.eu/github/chirpy:kube
docker image ls
REPOSITORY                                           TAG                                  IMAGE ID       CREATED         SIZE
registry.thekor.eu/github/chirpy                     kube                                 4c546a7122c2   4 minutes ago   136MB
registry.thekor.eu/github/chirpy                     latest                               4c546a7122c2   4 minutes ago   136MB
docker login registry.thekor.eu
docker push registry.thekor.eu/github/chirpy:kube
```

Gitlab's config should look like this if you're running an haproxy reverse proxy to handle the gitlab TLS certificates

```yaml
services:
  gitlab:
    image: gitlab/gitlab-ce
    container_name: gitlab
    restart: always
    hostname: 'gitlab.thekor.eu'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://gitlab.thekor.eu'
        gitlab_rails['registry_enabled'] = true
        registry_external_url 'https://registry.thekor.eu'
        registry_nginx['listen_https'] = false
        registry_nginx['listen_port'] = '5005'
        registry_nginx['enable'] = true
        registry['enable'] = true
        nginx['redirect_http_to_https'] = false
        nginx['listen_https'] = false
        nginx['listen_port'] = 80
        nginx['proxy_set_headers'] = {
          "X-Forwarded-Proto" => "https",
          "X-Forwarded-Ssl" => "on"
        }
(...)
    ports:
      - '80:80'
      - '443:443'
      - '5005:5005'
(...)
```

Whether you're terminating the TLS on gitlab or on the reverse proxy it doesn't really matter. What does matter is having https otherwise containerd or docker will refuse to pull the image from the registry. Docker allows you to easily drop this security to http with the change below but I couldn't easily get it to work on the containerd side so I don't recommend that approach. If you add a new node to your cluster you will also certainly forget to add the containerd configuration which will lead to ackward situations during upgrades or rollouts. 

```bash
nano /etc/docker/daemon.json
{
  "insecure-registries": ["registry.thekor.eu:5005"]
}
```

The incoming queries from the internet get masqueraded to the reverse proxy below who either forwards the TCP stream to kubernete's haproxy reverse proxy (kube-backend backend) who then terminates the SSL connection or forwards to another http reverse proxy (tcp-444-backend backend) that houses my legacy docker stack.

My reverse proxy's haproxy.cfg looks like this: 

```bash
frontend tcp-443-in
    bind *:443
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }

    acl sni_chirpy req.ssl_sni -i chirpy.thekor.eu
    acl is_https req.ssl_sni -i thekor.eu
    use_backend kube-backend if sni_chirpy
    use_backend tcp-444-backend if is_https
    default_backend tcp-444-backend

backend tcp-444-backend
    mode tcp
    option tcp-check
    server haproxy-legacy haproxy-legacy:444 send-proxy

backend kube-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server kube1 <kube node ip>:8443
    server kube2 <kube node ip>:8443
    server kube3 <kube node ip>:8443
```

### The k8s deployment

Now that all the planets are aligned we can trigger the kubernetes deployment and ingress. Like I said earlier we are currently building upon [the proxmox cluster we set up earlier](https://chirpy.thekor.eu/posts/k8s-p3/) which is using ceph as the distributed file system. We created in that article a storage called "rook-ceph-block" which, as the name suggests, allows us to create block storage for our database. The use case with our blog however requires us to persist files in a file-based structure. Ceph naturally supports this with its own cephfs implementation but we will have to enable it. 

#### Setting up the cephfs

The file system's name should correspond to your storage classes' fsName and pool nam

```bash
git clone --single-branch --branch v1.15.3 https://github.com/rook/rook.git
cd rook/deploy/examples
kubectl apply -f csi/cephfs/storageclass.yaml
nano csi/cephfs/storageclass.yaml

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-cephfs
provisioner: rook-ceph.cephfs.csi.ceph.com # csi-provisioner-name
parameters:
  # clusterID is the namespace where the rook cluster is running
  # If you change this namespace, also change the namespace below where the secret namespaces are defined
  clusterID: rook-ceph # namespace:cluster

  # CephFS filesystem name into which the volume shall be created
  fsName: myfs

  # Ceph pool into which the volume shall be created
  # Required for provisionVolume: "true"
  pool: myfs-data0
(...)

```

Instantiate the class: 

```bash
cat <<EOF > fs.yaml
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: myfs
  namespace: rook-ceph
spec:
  metadataPool:
    name: myfs-metadata
    replicated:
      size: 3
  dataPools:
    - name: myfs-data
      replicated:
        size: 3
  metadataServer:
    activeCount: 1
    activeStandby: true
EOF
kubectl apply -f fs.yaml
```

and attach to the toolbox container [we created earlier](https://chirpy.thekor.eu/posts/ceph/): 

```sh
kubectl -n rook-ceph get cephfilesystem myfs -w  
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}') -- sh
sh-5.1$ ceph osd pool ls       
replicapool
.mgr
myfs-metadata
myfs-data0
```

We can now create the actual blog itself i.e. the docker-secret, the wildcard certificate, the deployment and the ingress

```bash
kubectl create namespace chirpy
kubectl create secret docker-registry regcred \
  --docker-server=registry.thekor.eu \
  --docker-username=<secret> \
  --docker-password=<secret> \
  --docker-email=<secret> \
  -n chirpy

kubectl get secret wildcard-thekor -n cert-manager -o yaml \
  | sed 's/namespace: cert-manager/namespace: chirpy/' \
  | kubectl apply -n chirpy -f -

kubectl apply -f https://raw.githubusercontent.com/hupratt/kubernetes-the-hard-way/refs/heads/part6/kubeconfiguration/deploy/chirpy/deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/hupratt/kubernetes-the-hard-way/refs/heads/part6/kubeconfiguration/deploy/chirpy/ingress.yaml
```

And there you have it ! A fresh blog waiting to tackle new challenges. I could of course automate this further with a gitlab runner, CI/CD pipelines and webhooks but it's good enough for now.

Once you want to rollout a change simply go through the steps below and watch the deployment create a new replicaset with the new version, spin up a new pod, redirect the traffic to the new pod and terminate the old replicaset. And all of this happened seamlessly and no downtime. Absolutely beautiful.

![iframe](</assets/img/posts/swappy-20251018-203613.png>)

Hope you enjoyed this one and I wish you a good evening/afternoon/morning wherever you are. 

Cheers