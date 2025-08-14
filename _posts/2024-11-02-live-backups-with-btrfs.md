---
title: Live backups with btrfs
author: hugo
date: 2024-11-02 09:11:00 +0200
categories: [Tutorial, infrastructure]
tags: [btrfs, backup, sync]
render_with_liquid: false
---

## Intro: Backup and restore with btrfs snapshots

You're working from home and forgot your laptop at work? You want to go on a trip and want a way to use your laptop without bringing it with you? Well now you can. I have a replica/backup machine on my servers that is literally a one to one copy of my laptop. I've been meaning to do this for a while hence so I prepared this a year ago when I got my workstation by setting up btrfs. 

Most tutorials and guides out there around btrfs focus on snapshots as a way to recover missing data on the same machine. But what if I just want to keep a secondary machine in sync with my work laptop? Some guides explain how to store a backup of a btrfs system with Timeshift but fail to answer this question. I would prefer a solution that does not involve extra bloatware that is not even properly maintained.

In this guide we will delve into how to keep btrfs in sync with a backup system into a virtualized proxmox VM. We will be sending snapshots of the source system into the virtualized copy of the system every day to simulate daily use. In the end we will restore the backup system to the most up to date version of the source system by applying the latest snapshot.

## In practice: on the source system 

So as we start out in our journey here is what our subvolumes look like:

```bash
[root@nb-hpratt /]# btrfs subv list /
ID 256 gen 255550 top level 5 path root
ID 257 gen 255551 top level 5 path home
```

And here is what our fstab looks like:

```bash
#
# /etc/fstab
# Created by anaconda on Mon Nov  6 15:18:08 2023
#
# Accessible filesystems, by reference, are maintained under '/dev/disk/'.
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info.
#
# After editing this file, run 'systemctl daemon-reload' to update systemd
# units generated from this file.
#
UUID=0df06d0a-b446-4da4-92fe-43b0e54aab54 /                       btrfs   subvol=root,compress=zstd:1 0 0
UUID=a3122f1f-7821-4b21-8e91-3ef30ed6ce52 /boot                   ext4    defaults        1 2
UUID=9729-C6B9          /boot/efi               vfat    umask=0077,shortname=winnt 0 2
UUID=0df06d0a-b446-4da4-92fe-43b0e54aab54 /home                   btrfs   subvol=home,compress=zstd:1 0 0

```

Both root and home subvolumes were imaged on the 27th of October so the source system has some changes that are not present on the backup system.


To achieve syncronization you will want to create read only snapshots of your two subvolumes by running these two commands:

```bash
[root@nb-hpratt /]# btrfs subvolume snapshot -r /home/ /home/.snapshot/@snapshot_20241102
Create a readonly snapshot of '/home/' in '/home/.snapshot/@snapshot_20241102'
[root@nb-hpratt /]# btrfs subvolume snapshot -r / /.snapshot/@snapshot_20241102
Create a readonly snapshot of '/' in '/.snapshot/@snapshot_20241102'

```

Which now added those two snapshots into your list of subvolumes

```bash
[root@nb-hpratt /]# btrfs subv list /
ID 256 gen 255569 top level 5 path root
ID 257 gen 255569 top level 5 path home
ID 280 gen 255568 top level 257 path home/.snapshot/@snapshot_20241102
ID 281 gen 255569 top level 256 path .snapshot/@snapshot_20241102
```

Snapshots in btrfs are not just file copies they are pointers to a certain version of our system. 

## Creating a replica on a target VM

I have a KDE fedora 42 laptop so the first thing to do is to install the same ISO on a VM. You can install the server version as well and run these commands to achieve the same result:

```bash
[root@nb-hpratt /]# dnf5 install @kde-desktop
[root@nb-hpratt /]# systemctl enable sddm
[root@nb-hpratt /]# systemctl set-default graphical.target
```

Make sure openssh-server is installed and running on the target backup VM and send the snapshots with this one liner

```bash
[root@nb-hpratt /]# ssh root@proxmox05-btrfs "setenforce 0"

[root@nb-hpratt /]# btrfs send /.snapshot/@snapshot_20241102 \
  | gzip -c \
  | ssh root@proxmox05-btrfs "gzip -d | btrfs receive /.snapshot" &

btrfs send /home/.snapshot/@snapshot_20241102 \
  | gzip -c \
  | ssh root@proxmox05-btrfs "gzip -d | btrfs receive /home/.snapshot" &

wait
```

What this does is send over our compressed snapshot over SSH to your backup system. 

Once it's done you now have two perfectly synchronized systems. The only thing you would need to do on the target system to use the latest version is to create a 'new root', change the fstab file, and reboot:

- create a 'new root' to allow read/write of your snapshots

```bash
[root@nb-hpratt /]# btrfs subvolume snapshot /home/.snapshot/@snapshot_20241102 /home/.snapshot/@snapshot_20241102_rw
[root@nb-hpratt /]# btrfs subvolume snapshot /.snapshot/@snapshot_20241102 /.snapshot/@snapshot_20241102_rw

```

- change the fstab file: run ```btrfs subv list /``` to determine the ID's of your new root (/.snapshot/@snapshot_20241102_rw) and new home (/home/.snapshot/@snapshot_20241102_rw)

```bash
#
# /etc/fstab
# Created by anaconda on Mon Nov  6 15:18:08 2023
#
# Accessible filesystems, by reference, are maintained under '/dev/disk/'.
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info.
#
# After editing this file, run 'systemctl daemon-reload' to update systemd
# units generated from this file.
#
UUID=0df06d0a-b446-4da4-92fe-43b0e54aab54 /                       btrfs   subvolid=285,compress=zstd:1 0 0
UUID=a3122f1f-7821-4b21-8e91-3ef30ed6ce52 /boot                   ext4    defaults        1 2
UUID=9729-C6B9          /boot/efi               vfat    umask=0077,shortname=winnt 0 2
UUID=0df06d0a-b446-4da4-92fe-43b0e54aab54 /home                   btrfs   subvolid=284,compress=zstd:1 0 0

```



- reboot

```bash
[root@nb-hpratt /]# shutdown -r now
```
or

```bash
[root@nb-hpratt /]# reboot
```

Congratulations, you have just updated the target backup system into today's 2nd of November 2024 snapshot

## Sending changes to our target VM

Life goes on, you return from your trip and go back to the office. After a couple of months you have new changes that are in your laptop that are not on your backup VM anymore. In order to fix this we can either delete the target snapshot and send the home and root subvolumes again or we send the incremental changes that happened since 2nd of November 2024

This is the command to create a new snapshot just like we did earlier

```bash
[root@nb-hpratt /]# btrfs subvolume snapshot -r /home/ /home/.snapshot/@snapshot_20250812
Create a readonly snapshot of '/home/' in '/home/.snapshot/@snapshot_20250812'
[root@nb-hpratt /]# btrfs subvolume snapshot -r / /.snapshot/@snapshot_20250812
Create a readonly snapshot of '/' in '/.snapshot/@snapshot_20250812'

```

Let's see how we can send the incremental changes only. 


```bash
[root@nb-hpratt /]# ssh root@proxmox05-btrfs "setenforce 0"

[root@nb-hpratt /]# btrfs send -p /.snapshot/@snapshot_20241102 /.snapshot/@snapshot_20250812 \
  | gzip -c \
  | ssh proxmox05-btrfs "gzip -d | btrfs receive /disk/master/.snapshot" &

btrfs send -p /home/.snapshot/@snapshot_20241102 /home/.snapshot/@snapshot_20250812 \
  | gzip -c \
  | ssh proxmox05-btrfs "gzip -d | btrfs receive /disk/master/home/.snapshot" &

wait

```

Once it's done you simply repeat the steps we did earlier by creating a 'new root', changing the fstab file with the new subvolume id's , and rebooting.


And there you have it, you now updated the target backup system into  12th of August 2025 snapshot

Cheers
