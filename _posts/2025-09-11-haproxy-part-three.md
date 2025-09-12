---
title: haproxy part 3 the Virtual Router Redundancy Protocol  
author: hugo
date: 2025-09-11 09:11:00 +0200
categories: [Tutorial, infrastructure]
tags: [sysadmin, networking, haproxy]
render_with_liquid: false
---


## Introduction 

This will be a short one today and I wanted to go over a very simple question. What if the proxmox node running haproxy goes down? We've setup a load balancer [in our previous article](https://chirpy.thekor.eu/posts/haproxy-part-two/) but there is a fundamental flaw. If the machine is down: who is load balancing the load balancer? And the obvious answer is: "no one" which is a pity. I have the advantage in my setup of having a physical firewall so I don't need to worry about it in the context of my proxmox maintenances. I could of course live migrate the VM into another node but I don't feel like waiting for 30 Gb to migrate over a 1 Gb connection to start my maintenance. The solution to our conundrum would either be to setup a proxmox cluster with ceph for high availability or the poor's man solution: clone the existing haproxy VM and use the VRRP protocol to create a shared virtual IP with another machine. That way if one of the VMs is not working properly then the second VM takes over. 


## Installation

Download the package:

for fedora:
```bash
[root@haproxy-wk1 haproxy]$ dnf install keepalived
```
on ubuntu: 

```bash
[root@haproxy-wk1 haproxy]$ apt install keepalived

```

The rsyslog logs are integrated into the journalctl logs in ubuntu so you don't need to do any extra steps to see those valuable logs in journactl. If you're on fedora however there are some extra steps:


```bash
[root@haproxy-wk1 haproxy]$ systemctl edit keepalived
[Service]
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=keepalived


```
this creates a file here: /etc/systemd/system/keepalived.service.d/override.conf

Next apply the changes and add these settings. I'm using the virtual IP VIP: 10.10.25.9 in the example below: 

```bash
[root@haproxy-wk1 haproxy]$ systemctl daemon-reexec
[root@haproxy-wk1 haproxy]$ systemctl restart keepalived
[root@haproxy-wk1 haproxy]$ nano /etc/keepalived/keepalived.conf
```

```text
global_defs {
    script_user root
    enable_script_security
}


vrrp_script chk_haproxy {
    script "/usr/local/bin/check-haproxy.sh"
    interval 1
    weight -20
    fall 1
    rise 3
}

vrrp_instance VI_1 {
    state MASTER              # On one node MASTER, others BACKUP
    interface ens18           # Replace with your actual NIC (e.g., ens3)
    virtual_router_id 51
    priority 100              # Lower on backups (e.g., 90, 80)
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass <redacted>
    }

    virtual_ipaddress {
        10.10.25.9/24 dev ens18   # VIP on host network
    }

    track_script {
        chk_haproxy
    }
}
```

On the second node, simply copy over this config, replace "state MASTER" to "state BACKUP" and "priority 100" to "priority 90"

If you're using a software defined network however the multicast packet might not propagate properly. At least it failed for me so here is the simple fix: 


```text
(...)

vrrp_instance VI_1 {
    state MASTER               # On one node MASTER, others BACKUP
    interface ens18            # Replace with your actual NIC (e.g., ens3)
    virtual_router_id 51
    priority 100               # Lower on backups (e.g., 90, 80)
    advert_int 1
    unicast_src_ip 10.10.25.198   # this node's IP
    unicast_peer {
        10.10.25.199              # other node(s)
    }
    authentication {
        auth_type PASS
        auth_pass <redacted>
    }

    virtual_ipaddress {
        10.10.25.9/24 dev ens18   # VIP on host network
    }

    track_script {
        chk_haproxy
    }
}
```

If the MASTER node is off the BACKUP node will be elected MASTER node. But what if the haproxy is not available? I've added this extra script to make sure the necessary containers are healthy. Keepalived will actually make sure the VIP gets elected on the node that has healthy containers. 

```bash
[root@haproxy-wk1 haproxy]$ nano /usr/local/bin/check-haproxy.sh

#!/bin/bash

# List of container names to check
containers=("haproxy-loadbalancer" "haproxy1")

for c in "${containers[@]}"; do
    /usr/bin/docker ps --filter "name=$c" --filter "status=running" --format '{{.Names}}' | grep -q "$c"
    if [ $? -ne 0 ]; then
        # Container is not running
        exit 1
    fi
done

# All containers are running
exit 0

```

Make the script executable, start and enable the service:

```bash
[root@haproxy-wk1 haproxy]$ chmod u+x /usr/local/bin/check-haproxy.sh
[root@haproxy-wk1 haproxy]$ systemctl enable --now keepalived
[root@haproxy-wk1 haproxy]$ journalctl -u keepalived.service -f

Sep 11 15:58:16 docker-lb1 Keepalived[306310]: Startup complete
Sep 11 15:58:16 docker-lb1 systemd[1]: Started keepalived.service - Keepalive Daemon (LVS and VRRP).
Sep 11 15:58:16 docker-lb1 Keepalived_vrrp[306313]: VRRP_Script(chk_haproxy) succeeded
Sep 11 15:58:20 docker-lb1 Keepalived_vrrp[306313]: (VI_1) Entering MASTER STATE
```

On the BACKUP node you should see your private ip:
```bash
[root@haproxy-wk1 haproxy]$ ip addr show ens18
2: ens18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP group default qlen 1000
    link/ether bc:24:11:7f:a6:2b brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 10.10.25.199/24 metric 100 brd 10.10.25.255 scope global dynamic ens18
       valid_lft 5343sec preferred_lft 5343sec
    inet6 fe80::be24:11ff:fe7f:a62b/64 scope link 
       valid_lft forever preferred_lft forever
```

On the master node you should see your private ip and the virtual IP (VIP) 10.10.25.9:

```bash
[root@haproxy-wk1 haproxy]$ ip addr show ens18
2: ens18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast state UP group default qlen 1000
    link/ether bc:24:11:bc:ba:2f brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 10.10.25.198/24 metric 100 brd 10.10.25.255 scope global dynamic ens18
       valid_lft 5627sec preferred_lft 5627sec
    inet 10.10.25.9/24 scope global secondary ens18
       valid_lft forever preferred_lft forever
    inet6 fe80::be24:11ff:febc:ba2f/64 scope link 
       valid_lft forever preferred_lft forever
```


### Conclusion

You can test out stopping the containers or turning off the machine. I started working on this thinking it would be hard but it was actually incredibly simple. 

Cheers and see you on the next one