---
title: Bypassing netflix's paywall BS
author: hugo
date: 2025-09-29 09:11:00 +0200
categories: [Tutorial, infrastructure]
tags: [sysadmin, networking, rustdesk, dnsmasq, wireguard]
render_with_liquid: false
---

### Introduction

I've received a notice recently from my streaming provider that upset me quite a bit. I've been a loyal netflix customer since 5 years only to get locked out of my account like a criminal. Instead of relaxing on the couch with my significant other, I was debugging the situation and unable to log in to my account.

![iframe](</assets/img/posts/netflix-locked-me-out-of-my-pc-v0-zejhzx512lye1.jpg>)

As this is new to me and I don't spend my free time reading the terms of service, I quickly realized I shared my account without knowing it is illegal. I live far away from my parents so I gave them access since I don't watch netflix that often anyways.

I'm not a fan of these greedy practices and won't put up with them virtually throttling my access. I'll start off by setting up a remote access so that I can configure everything from afar and configure a jump box to route my traffic through a mini pc back to my gateway. The mini pc is a Zotac ZBOX CI321 nano and has a Realtek network card that allows it to be set into AP mode. As the OS a fedora 42 server is used to configure the networking and the VPN tunnel.

![iframe](</assets/img/posts/7bb1-zbox-cover.jpg>)

The diagram of what we are trying to set up would look something like this

TV --> zotac --> router --> my house

The TV connects to the mini pc over wi-fi, the zotac mini pc then connects to the LAN over cabled ethernet and some packets are redirected through the wireguard tunnel to my house.


#### Remote access

Start up this docker compose setup on a VPS to install Rustdesk. Once started you should get access to a public key generated here: ./data/id_ed25519.pub which you'll use later on the rustdesk clients

```yaml
services:
  hbbs:
    container_name: hbbs
    image: rustdesk/rustdesk-server:latest
    command: hbbs
    volumes:
      - ./data:/root
    network_mode: "host"
    depends_on:
      - hbbr
    restart: always

  hbbr:
    container_name: hbbr
    image: rustdesk/rustdesk-server:latest
    command: hbbr
    volumes:
      - ./data:/root
    network_mode: "host"
    restart: always
```

Allow these inbound connections to your server: 

the range tcp/21114-tcp/21119 and udp/21116

![iframe](</assets/img/posts/swappy-20250929-185530.png>)

On the client at my parents house I simply [downloaded the installer on a windows client](https://github.com/rustdesk/rustdesk/releases/download/1.4.2/rustdesk-1.4.2-x86_64.exe), set a permanent password and configured it to be able to talk to my server by configuring the "ID server", the "Relay server" and the "Key". The "ID server" and the "Relay server" are the same and can either be the IP address or an FQDN that you configured on some public DNS

![iframe](</assets/img/posts/swappy-20250929-190357.png>)


#### The server wireguard configuration

At home i'm running wireguard on an LXC container. This is the endpoint that my parents will use to spoof their IP

```bash
wireguard-alpine:$ wg genkey > privatekey
wireguard-alpine:$ wg pubkey < privatekey > publickey
wireguard-alpine:$ wg genpsk
wireguard-alpine:$ apk add nano iptables wireguard-tools
wireguard-alpine:$ cd /etc/wireguard
wireguard-alpine:$ cat <<EOF > wg0.conf
[Interface]
Address = 10.60.5.1/32
ListenPort = <redacted>
PrivateKey = <redacted>
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <redacted>
PresharedKey = <redacted>
AllowedIPs = 10.60.5.2
PersistentKeepalive = 25
EOF
wireguard-alpine:$ ln -s /etc/init.d/wg-quick /etc/init.d/wg-quick.wg0
wireguard-alpine:$ rc-update add wg-quick.wg0 default
wireguard-alpine:$ cat <<EOF > /etc/sysctl.conf
net.ipv4.ip_forward=1
EOF
wireguard-alpine:$ rc-update add sysctl
```


#### The client VPN configuration

I've configured a dedicated VPN connection that redirects all of the netflix traffic through the VPN. To set it up on the fedora server simply install the tools, enable and persist the connection accross reboots:

```bash
root@zotac:$ dnf install -y wireguard-tools
root@zotac:$ cd /etc/wireguard
root@zotac:$ wg genkey > privatekey
root@zotac:$ wg pubkey < privatekey > publickey
root@zotac:$ wg genpsk
```

I have setup the endpoint as a "fqdn:port" because my public IP changes every day so I'll need to make sure that the machine uses a public DNS server so that it can pick up the IP change and avoid disruption. 

You'll notice that I setup a DNS server on the tunnel. This IP resolves to a pihole instance I have running on my LAN. This is an important piece of the puzzle in getting the traffic to flow correctly back and forth with netflix as we will see in the next chapter.

```bash
root@zotac:$ cat <<EOF > wg0.conf
[Interface]
Address = 10.60.5.2
ListenPort = 51874
PrivateKey = <redacted>
DNS = 10.10.0.105

[Peer]
PublicKey = <redacted>
PresharedKey = <redacted>
AllowedIPs = 10.60.5.1, 3.251.50.149, 54.155.178.5, 54.74.73.31
Endpoint = <fqdn>:<port>
PersistentKeepalive = 25
EOF
```

Now simply run the command below to start the VPN. You should see a handshake just as below. If the handshake is missing there is some misconfiguration on the tunnel or some firewall is most probably blocking the traffic.

```bash
root@zotac:$ systemctl enable --now wg-quick@wg0.service
root@zotac:$ wg
interface: wg0
  public key: <redacted>
  private key: (hidden)
  listening port: <redacted>

peer: <redacted>
  preshared key: (hidden)
  endpoint: <ip>:<port>
  allowed ips: 10.60.5.1/32
  latest handshake: 5 seconds ago
  transfer: 33.70 MiB received, 84.79 MiB sent
  persistent keepalive: every 25 seconds
```


#### Routing the traffic through the tunnel

It sounds simple to do but there are two problems. Firstly, I can't simply "root" the toshiba smart TV or the amazon firestick to mess around with the name resolution so I've opted to go with the least intrusive option that would be doable while sitting 3000 kilometers away namely DHCP. DHCP, or better dnsmasq will reconfigure the TV to the DNS and IP that I want it to use. 

The second hurdle to getting the traffic to flow right is to handle ipv6 traffic. If you try to resolve netflix.com you get 3 ipv4 and 3 ipv6 addresses back. As I can't control which route the TV chooses I'll have to setup a rogue DNS server that forwards all of the traffic to one ipv4 address and ignore the other 5 addresses. I could also setup the name resolution with dnsmasq and create an A record that would point to all 3 ipv4 addresses but I'll keep it simple for now and use the pihole GUI.

Wireguard supports ipv6 so I could theoretically just do a full tunnel and pass it all the ipv4 and ipv6 traffic. The only problem in this equation is that my ISP doesn't support ipv6 which means I can't forward ipv6 addresses. This is not the most elegant solution but it's the only way I found to make this work without messing with complicated iptables rules.


#### Setting up the access point

We will do two birds with one stone here by using nmcli to set up an access point and configure dnsmasq for the TV to use our rogue DNS

```bash
root@zotac:$ nmcli con add type wifi ifname wlan1 mode ap con-name MyHomeWiFI ssid zotac
root@zotac:$ nmcli con modify MyHomeWiFI 802-11-wireless.band bg
root@zotac:$ nmcli con modify MyHomeWiFI 802-11-wireless.channel 1
root@zotac:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.key-mgmt wpa-psk
root@zotac:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.proto rsn
root@zotac:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.group ccmp
root@zotac:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.pairwise ccmp
root@zotac:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.psk MaxPass21
root@zotac:$ nmcli con modify MyHomeWiFI ipv4.method shared
root@zotac:$ nmcli con modify MyHomeWiFI ipv4.dns ""
root@zotac:$ nmcli con modify MyHomeWiFI ipv4.ignore-auto-dns yes
root@zotac:$ nmcli con modify MyHomeWiFI +ipv4.dns-search ""
root@zotac:$ nmcli con modify MyHomeWiFI ipv4.dns-priority -42
root@zotac:$ nmcli con modify MyHomeWiFI connection.autoconnect yes
root@zotac:$ nmcli con up MyHomeWiFI
```

disable systemd-resolved as we don't want to introduce another DNS resolver on our system

```bash
root@zotac:$ systemctl disable systemd-resolved && systemctl stop systemd-resolved
root@zotac:$ rm /etc/resolv.conf
root@zotac:$ echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | tee /etc/resolv.conf
root@zotac:$ chattr +i /etc/resolv.conf
```

create a custom dns entry for the access point's DHCP pool

```bash
root@zotac:$ cat <<EOF > /etc/NetworkManager/dnsmasq-shared.d/custom.conf
no-resolv
server=10.10.85.105
dhcp-option=6,10.10.85.105
EOF
```

restart NetworkManager and make sure it's advertising the right DNS 

```bash
root@zotac:$ systemctl restart NetworkManager
root@zotac:$ journalctl -xeu NetworkManager -f
```

![iframe](</assets/img/posts/swappy-20250930-165325.png>)

append the ipv6.disable=1 flag to your grub boot options

```bash
root@zotac:$ nano /etc/default/grub
(...)
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash ipv6.disable=1"

root@zotac:$ grub2-mkconfig -o /boot/grub2/grub.cfg
root@zotac:$ reboot
```


#### Plug'n'play

Now, the only thing left to do is connect to the wpa access point that we configured on the mini pc and watch the traffic flow to the tunnel using tcpdump or bmon to get an overview of the number of packets or the network speeds that we are getting.

Here's some valuable views: 

- See the unencrypted traffic flowing between netflix and the wireguard's endpoint

```bash
root@zotac:$ tcpdump -i wg0 -n | grep 10.60.5.2
```

![iframe](</assets/img/posts/swappy-20250930-165157.png>)

- Make sure there is no http/https traffic flowing to the local gateway:

```bash
root@zotac:$ tcpdump port 443 -i enp5s0 -n
```

- Look at the encrypted traffic leaving from the local gateway to my wireguard server's public IP

```bash
root@zotac:$ tcpdump port <vpn_port> -i enp5s0 -n
```

- On the server-side, look at what enpoints the Toshiba smart tv is reaching out to grab the netflix content 

```bash
root@zotac:$ tcpdump port 443 -i wg2 -n
```


### Conclusion

Hope you enjoyed todays read. It turned out to be a lot more intricate than I initially planned which only makes the end goal all the more enjoyable. See you on the next one


Cheers
