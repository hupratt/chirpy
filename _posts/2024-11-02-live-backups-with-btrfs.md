---
title: Live backups with btrfs
author: hugo
date: 2024-11-02 09:11:00 +0200
categories: [Tutorial, infrastructure]
tags: [btrfs, backup, sync]
render_with_liquid: false
---

## Intro: Backup and restore with btrfs snapshots

Most tutorials and guides out there around btrfs focus on snapshots as a way to recover missing data on the same machine. 
Some guides explain how to keep a backup of a btrfs system with Timeshift and other tools but would it be possible to do it without extra bloatware?

In this guide we will delve into how to keep btrfs in sync with a backup system which we have previous imaged into a virtualized proxmox VM. We will be sending snapshots of the source system into the virtualized copy of the system every day to simulate daily use. In the end we will restore the backup system to the most up to date version of the source system by applying the latest snapshot.

## In practice: on the source system 

So as we start out in our journey here is what our subvolumes look like:

```
[root@nb-hpratt /]# btrfs subv list /
ID 256 gen 255550 top level 5 path root
ID 257 gen 255551 top level 5 path home
```

And here is what our fstab looks like:

```
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

```
[root@nb-hpratt /]# btrfs subvolume snapshot -r /home/ /home/.snapshot/@snapshot_20241102
Create a readonly snapshot of '/home/' in '/home/.snapshot/@snapshot_20241102'
[root@nb-hpratt /]# btrfs subvolume snapshot -r / /root/.snapshot/@snapshot_20241102
Create a readonly snapshot of '/' in '/root/.snapshot/@snapshot_20241102'

```

Which now added those two snapshots into your list of subvolumes

```
[root@nb-hpratt /]# btrfs subv list /
ID 256 gen 255569 top level 5 path root
ID 257 gen 255569 top level 5 path home
ID 280 gen 255568 top level 257 path home/.snapshot/@snapshot_20241102
ID 281 gen 255569 top level 256 path root/.snapshot/@snapshot_20241102
```

Snapshots in btrfs are not just file copies they are snapshots that record the incremental changes that happened in that subvolume

At some point you will want to send those incremental changes to a backup system which in our case is a proxmox VM and in order to do that you will need to boot into a Live CD of fedora or any linux distribution and apply some changes.

## Live boot into fedora

The first thing we will do is mount the btrfs system into /mnt and to make the parent subvolume read only. Without doing this change you won't be able to send out your snapshots

```
btrfs property set -ts /mnt/home ro true
btrfs property set -ts /mnt/root ro true

```

Make sure openssh-server is installed on the target backup VM and send the snapshots with this one liner

```
btrfs send -p /mnt/home /mnt/home/.snapshot/@snapshot_20241102 | ssh root@10.10.85.171 "btrfs receive /home/.snapshot"
```

What this does is send over all of the incremental changes that were done since you imaged the source system and send them over SSH to your backup system. 

Now repeat the process for the root directory

```
btrfs send -p /mnt/root /mnt/root/.snapshot/@snapshot_20241102 | ssh root@10.10.85.171 "btrfs receive /root/.snapshot"
```

You now have two perfectly synchronized systems. The only thing you would need to do on the target backup system to use the latest version is to 1. change the fstab file, 2. allow read/write on the snapshots and 3. reboot:

1. change the fstab file

```
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
UUID=0df06d0a-b446-4da4-92fe-43b0e54aab54 /                       btrfs   subvolid=281,compress=zstd:1 0 0
UUID=a3122f1f-7821-4b21-8e91-3ef30ed6ce52 /boot                   ext4    defaults        1 2
UUID=9729-C6B9          /boot/efi               vfat    umask=0077,shortname=winnt 0 2
UUID=0df06d0a-b446-4da4-92fe-43b0e54aab54 /home                   btrfs   subvolid=280,compress=zstd:1 0 0

```

2. allow read/write on the snapshots

```
btrfs property set -ts /home/.snapshot/@snapshot_20241102 ro false
btrfs property set -ts /root/.snapshot/@snapshot_20241102 ro false

```

3. reboot

```
shutdown -r 
or 
reboot
```

Congratulations, you have just updated the target backup system into today's 2nd of November 2024 snapshot

Do not forget to allow read/write permissions on your source's home and root subvolumes before existing your usb boot otherwise you won't be able to enter your session. The same goes to your backup system. If you forget to set it back to the parent subvolume what will happen is you'll start creating snapshots of snapshots and that is not a good idea if you don't want useless redundant data to clog your storage.