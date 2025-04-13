---
title: Windows print server
author: hugo
date: 2025-04-14 09:11:00 +0200
categories: [Tutorial, infrastructure]
tags: [windows, printers, windows-server]
render_with_liquid: false
---

## Introduction

This is a quick write up on a couple of different ways to set up a print server on a windows environment. There are generally two ways of going about this. Either add the required server roles to your domain controller or use a separate machine. Using the later option gives you more flexibility to update or change your printers without having Domain-controller downtime.

Once you decide where to install it you can now deploy your printers in two ways. Either publish the printers into the Active directory and write a group policy (GPO) to install the printers on user devices or simply push out a group policy that adds printers as samba shares on users devices. I tend to prefer the first option as I don't like to see too many printers appear as shares.

If you make the newbie mistake like me of adding the printers to the domain without the GPO users will be able to see the printers in the available printers section but once they double click on it they won't be able to get it installed if they don't have administrator privileges

## Setting up the server

Unlike our [previous article](https://chirpy.thekor.eu/posts/oidc/) where we setup the domain controller, the hostname does not need to be changed before joining the domain. You'll always be able to change the machine's hostname later on.

However before we start, make sure to run Sysprep in case you are reusing an existing VM. Cloning a VM or doing a full clone from a template will cause issues when joining the domain. Windows won’t allow 2 machines with the same security ID to be on the same domain. Since you cloned the machine that security gets cloned as well unfortunately.

### (Optional) Generating a new SID security ID


You can skip this section if you're installing a windows server from scratch. If you're cloning the machine then start it up and press windows key + R or simply look for the program called "Run" as an administrator.

- Type "sysprep"

- In the System Preparation Tool:

In System Cleanup Action section select:

"Enter System Out-of-Box Experience (OOBE)"

check the "Generalize" box, this removes specific settings like SID

In Shutdown Options section select: "Reboot"

- A pop up should appear asking you to reboot. Click OK and your new SID will be generated.

- Once the system is back up, login and follow the steps to change the Administrator password, Hostname and IP Address.

You have successfully generated a new SID.


## Adding the printer server role

Set a fixed IP Address and publish the A or CNAME record into your DNS provider. Once that is done join the domain and install the "print and document service" role. During the wizard it will ask you about which features you want. We won't need the LDP or internet print features.

After rebooting, go to print manager, add the printer driver and add as many printers as you want.

Make sure the tick "publish to AD" is activated on all printers otherwise users won't be able to see it. That option can be found in the print manager

## Firewall

>Windows Server 2008 newer versions of Windows Server have increased the dynamic client port range for outgoing connections. The new default start port is 49152, and the default end port is 65535. Therefore, you must increase the RPC port range in your firewalls. This change was made to comply with Internet Assigned Numbers Authority (IANA) recommendations. This differs from a mixed-mode domain that consists of Windows Server 2003 domain controllers, Windows 2000 server-based domain controllers, or legacy clients, where the default dynamic port range is 1025 through 5000.

Make sure the tcp ports 49152 to 65535 are allowed to open up connections on client devices otherwise I wasn't able to open up the printer's spool file. [Looking at what the internet says about these ports](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/config-firewall-for-ad-domains-and-trusts), it seems they are used by authentication services and the RPC protocol but don't quote me on this.

