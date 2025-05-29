# Comptia Linux+ (XK0-005) course notes

This course is given by John McGovern on CBT nuggets. The purpose of this document is to summarize some of the key learnings I got from it.

## FHS File Hierarchy Standard

As opposed to windows systems, /home and /root could be in totally different physical locations whereas in Windows anything below C:\ drive belongs to the C:\ drive 

If you ever want a hint type ```man hier```

/etc configuration files
/boot files needed to boot: kernel executable file (vmlinux), grub bootloader, initramdisk image loads the initial modules and drivers 
/lib libraries used for the OS
/dev device files like keyboards, usb drives, terminals
/proc virtual file system (in memory) has information relating to running processes, info related to hw statistics
/sys  virtual file system (in memory) has kernel modules, and driver information, power management, info about attached blocked devices
/home contains user directories
/tmp relaxed permissions, tmp files get deleted on boot
/root home directory of the root user
/opt optional directory to store third party programs you build from source
/sbin directory to store system level programs 
/usr/bin local user programs

you can pipe the errors to /dev/null by doing

```cat /etc/passwd /etc/shadow 2> /dev/null```

## Formatting

Before using a disk you need to either format it with MBR or GPT. MBR splits your disk into 512 bytes with the first sector is dedicated to the master boot record. By choosing MBR you are limiting the maximum size of your partitions to 2Tb. Another limit is you can create up to 4 partitions.

## Boot

1. uefi triggers the POST
1. Power on Self Test or POST is done
1. uefi loads the grub bootloader. UEFI ships with secure boot which allows you to boot into your machine in case for example your machine gets compromised with a virus.
1. initrd: ramdisk loads the necessary kernel modules so that the linux kernel can load
1. kernel then starts sysvinit or systemd 
1. services will start depending on the boot level. Some services will wait on the network, others on boot, etc
 
If you want to have a dual boot setup you would edit the /boot/grub/grub.cfg on debian or /boot/grub2/grub.cfg on red hat. On these two distros the process of changing the boot configuration will be slightly different. Whatever distro you're running be aware that you shouldn't edit /boot files directly and go through the /etc conf files instead. 

When a computer boots up and does not have a fixed IP address it sends out an ARP request to receive an ip address. Now either the DHCP server (which can be a firewall for example) has a MAC address reservation or it assigns one from a DHCP pool for a certain time (also known as lease time). Once the lease time is expired the server has the option to re-assign it in case the IP is not currently in use.

## Boot sources

ISO mount, usb mount, DVD optical disk, pxe network boot, ipxe network boot

## Kernel panic

Reasons might range from hardware failure, misconfigured driver, incompatible drivers, software hack or simply an update of the kernel?

diagnose by looking at the last boot

```bash
root@tutorial:$ journalctl -b -1
```

diagnose severity level critical or above in the last couple of boots 

```bash
root@tutorial:$ journalctl -p 2
```

or the kernel logs directly

```bash
root@tutorial:$ /var/log/kern.log
root@tutorial:$ /var/log/sys.log
```

or the ring buffer logs directly

```bash
root@tutorial:$ dmesg -T | grep -Ei "fail|error|panic"
[Fri Apr 18 09:53:57 2025] tsc: Marking TSC unstable due to check_tsc_sync_source failed
[Fri Apr 18 09:53:58 2025] RAS: Correctable Errors collector initialized.
[Fri Apr 18 09:54:05 2025] nvidia: module verification failed: signature and/or required key missing - tainting kernel
[Fri Apr 18 09:54:05 2025] EDAC sbridge: Failed to register device with error -19.
[Fri Apr 18 10:30:33 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm find: Directory block failed checksum
[Fri Apr 18 10:30:33 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm find: Directory block failed checksum
[Fri Apr 18 10:30:33 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm apt.systemd.dai: Directory block failed checksum
[Fri Apr 18 10:30:33 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm apt.systemd.dai: Directory block failed checksum
[Fri Apr 18 10:30:33 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm du: Directory block failed checksum
[Fri Apr 18 10:30:33 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm du: Directory block failed checksum
[Fri Apr 18 10:34:16 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm rsync: Directory block failed checksum
[Fri Apr 18 10:34:16 2025] EXT4-fs error (device sdd2): htree_dirblock_to_tree:1082: inode #2097187: block 4: comm rsync: Directory block failed checksum

```

once you find something interesting you can dig into it. The -C flag appends line numbers to the output

```bash
root@tutorial:$ grep -C 3 "[Fri Apr 18 09:54:05 2025] nvidia" dmesg
```

This following command filters only the kernel messages from the last boot and pipes it to grep which will look for any case insensitive regex occurence of fail or error or panic

```bash
root@tutorial:$ journalctl -k -b -1 | grep -Ei "fail|error|panic"

```

by removing the -b flag you see the current boot logs 

```bash
root@tutorial:$ journalctl --since today | grep -Ei "fail|error|panic"
```

## Raid

- RAID 0 – Striping: Data split across drives, no redundancy
- RAID 1 – Mirroring: redundancy, half space lost
- RAID 5 – Striping + Parity: Spreads data and parity bit info across all drives, can survive 1 disk failure
- RAID 10 (1+0) – Mirrored Stripes: Pairs of mirrored drives, then stripes data across them. In a 4 disk setup you can sustain 2 disk failures if they are in different mirror pairs. If both disks in a single mirror pair fail, you lose the array. In a 6 disk setup you can sustain 3 disk failures if they are in different mirror pairs
- RAIDZ1 – RAID 5 in the ZFS world, can survive 1 disk failure. It's safer than RAID5 because:
  - Checksums: ZFS checks every block for corruption, RAID 5 does not
  - Self-healing: If a block is corrupt, ZFS can automatically repair it using parity
  - No write hole: ZFS uses copy-on-write, avoiding inconsistencies during power loss, which RAID 5 is vulnerable to

## Types of storage

1. Block storage: Each block has an address, and the OS or the database decides how to organize it. Better performance for larger files.
1. Object storage: Each block has a UUID and rich metadata that simplifies the querying. Used in cloud environments like aws s3
1. Filesystem storage: Organizes data into files and directories

## Mounting directories 

- sshfs: You can mount filesystems without sudo privileges by using sshfs. It's apparently not great for high-performance I/O workloads but is much easier to setup

- samba: If you want to go the secure route go with samba as it allows you to password protect your shares

- autofs: if you're dealing with a medium that might not always be available all the time I would opt for autofs. The mount does not happen at boot like with a samba or nfs mount but rather once a user accesses it.

- nfs: insecure compared to samba, fast to setup on linux

## text utilities

1. awk

does some of the same functions like grep with regex. Additionally it can: 
- manipulate tabular or csv data
- target columns in files. You can add it to your grep pipe to filter the columns/lines you want
- sum a column or filter numeric values. This example shows all attached block devices that are 100 Gb or more


```bash
root@tutorial:$ lsblk -b -o NAME,SIZE | awk '$2 > 100000000000'
root@tutorial:$ awk '!/^#/ { print $12 }' u_ex250527.log # ignore any lines that start with a # sign and print column 12 from the file
root@tutorial:$ awk '!/^#/ && $12 == 503' u_ex250527.log | sort -u # print lines that have a 503 on the 12th column and remove duplicates

```

2. sed

the stream editor. Usage ```sed -i "s/Scotland/UK/g" file.txt``` removes all instances of Scotland in the file.txt and replaces it with UK

3. printf

useful for string formatting in bash scripting

4. vim

When using command mode:

- use ```gg``` to go to the bottom of a file or ```shift+G``` to go to the start of a document

- use undo with u and Ctrl + r to redo

- use ```:set number``` to add numbers to the first column

- use ```yy``` to copy a line and ```p``` to paste

- press Ctrl + v to enter visual mode which allows us to select blocks to copy for example

When using insert mode:

- press dd to remove a line

## Compression and archiving

1. gzip

tar archives, it does not actually compress anything. This is why you usually combine it with gzip with commands like ```tar -cvzf Documents.tgz Documents```

Compress a file and delete the txt file

```bash
root@tutorial:$ gzip -v textfile.txt
```

use zcat to view compressed files

```bash
root@tutorial:$ zcat textfile.txt.gz
```

this command decompresses textfile.txt.gz into textfile.txt and deletes the textfile.txt.gz

```bash
root@tutorial:$ gunzip -v textfile.txt.gz
```

2. bzip2

slower than gzip but higher compression ratios

Compress a file and delete the txt file

```bash
root@tutorial:$ bzip2 -v textfile.txt
```

use bzcat to view compressed files

```bash
root@tutorial:$ bzcat textfile.txt.bz2
```

this command decompresses textfile.txt.bz2 into textfile.txt and deletes the textfile.txt.bz2

```bash
root@tutorial:$ bunzip2 -v textfile.txt.bz2
```

3. xz

higher compression ratio compared to bzip and gzip

Compress a file and delete the txt file

```bash
root@tutorial:$ xz -v textfile.txt
```

use xzcat to view compressed files

```bash
root@tutorial:$ xzcat textfile.txt.xz
```

this command decompresses textfile.txt.xz into textfile.txt and deletes the textfile.txt.xz

```bash
root@tutorial:$ unxz -v textfile.txt.xz
```


4. zip

is supported on windows

Compress a file or multiple ones

```bash
root@tutorial:$ zip test.zip textfile.txt textfile2.txt
```

Compress a folder 

```bash
root@tutorial:$ zip -r testfolder.zip testfolder/
```

use unzip to view compressed files

```bash
root@tutorial:$ unzip -l test.zip
root@tutorial:$ unzip -p test.zip file.txt | less
```

this command decompresses test.zip

```bash
root@tutorial:$ unzip test.zip
```

5. tar

```tar -xvzf <tarball> ``` to decompress a tarball compressed with gzip
```tar -xvzf <tarball> -C /tmp``` to decompress a tarball compressed with gzip into the tmp directory
```tar -cvzf tarball.tgz directory/``` to compress a directory into a gzip tarball

6. cpio

alternative archiving to tar

```bash
root@tutorial:$ find /etc -name "*.conf" | cpio -ov etcbackup.cpio
root@tutorial:$ cpio -iv < etcbackup.cpio
```

7. dd or ddrescue

dd does a bite-like copy of your data. you can tell it the byte size of the chunks you want to copy over per operation with the bs= flag. Careful if you combine the bs= flag with the count= flag you could actually have data loss. 

```bash
root@tutorial:$ dd if=/dev/sdX of=backup.img bs=4M
root@tutorial:$ dd if=/dev/sdX of=/dev/sdY
```

ddrescue is a process that is more careful with the drive i.e. doesn't bruteforce like dd and is usually used on failing drives. Force overwrite with -f and -n for do not retry which quickly copies all readable data. I want the process to skip errors.

```bash
root@tutorial:$ ddrescue -f -n /dev/sdX /mnt/backup/recovery.img rescue.log
```
you can then use the rescue log to retry failed blocks

```bash
root@tutorial:$ ddrescue -r3 /dev/sdX /mnt/backup/recovery.img rescue.log
```
## manage files & transfers

```ls -li``` gives us the inode of a file. File's inode are unique which means that if you do a hard link you're pointing to an inode.

By using a soft (symbolic) link you're not linking by inode but by file name which breaks as soon as you move or rename the original file

1. rsync

source and destination need rsync installed

```bash
root@tutorial:$ rsync -avz --delete /root proxmox01:/destination/ >> /tmp/transferproxmox01.log 2>&1
```
- rsync files under /root and append the logs to the /tmp directory
- The 2>&1 descriptor is used to redirect output — both standard output (stdout) and standard error (stderr) — into the same log file
- The 3>&1 1>&2 2>&3 descriptor is used to redirect the standard error (stderr) into the log file
- z compresses so that the transfer goes faster, it doesnt actually compress anything
- a does recursive copy and keeps meta data, permissions
- v is for verbose
- --delete removes remote files that were deleted locally

2. scp

```bash
root@tutorial:$ scp -r /root proxmox01:/destination/ -P 2025
```

Transfer your files from /root recursively into proxmox01 over tcp port 2025

3. sftp

you get a cli where you ``get`` and ``put`` files

4. netcat

can be used to test open ports and transfer files between machines

```bash
root@tutorial:$ nc -vz mail.whatever.de 587 
```

This command checks if the smtp port is open by sending a STARTTLS command to the server to know if it can send smtp over TLS

- z stands for scanning
- v stands for verbose

```bash
root@server:$ nc -lvp 7788
```

server listens on 7788

```bash
root@client:$ nc 192.168.178.5 7788 < testfile.txt
```

## partitions

1. fdisk

you can use fdisk to manage partitions. Let's take an example creating a LUKS encrypted ext4 partition

```bash
root@client:$ apt install cryptsetup
root@client:$ fdisk /dev/sde
# press d and w to delete sde1
root@client:$ fdisk /dev/sde
# press g, n, t, 8300 and w to create a gpt partition
root@client:$ cryptsetup luksFormat /dev/sde1
root@client:$ cryptsetup open /dev/sde1 crypt
root@client:$ mkfs.ext4 /dev/mapper/crypt
root@client:$ mount /dev/mapper/crypt /mnt

```

create a partition by typing:

- g Create a new GPT partition table (optional but recommended)

- n Create a new partition (accept defaults unless you have specific size needs)

- t Change the partition type

    For LUKS, type 8300 (Linux filesystem)

- w Write and exit

2. parted

the flags are slightly different but it's essentially the same as fdisk but it has nice extra features like scripts, file system creation  and has a gui version of its own.
be careful when deleting or creating anything on parted as it does all changes in place with no need to commit our changes like fdisk

3. partprobe

inform OS of partition changes

4. fsck

very useful when partition is damaged. 

If windows ntfs is broken you can try to fix it by mounting a fedora server iso, changing tty terminal, and running ```fsck.ntfs /dev/sdX```. If the drive is unhealthy you can try and fix the partition by using ```ntfsfix```

you can use ```apt-get -y install gsmartcontrol``` to check your drive's health

5. tune2fs

you can change the frequency of fsck (or e2fsck) running on your partition

6. resize2fs

> How would you expand the storage on ext4 after allocating more space to a VM?

You must begin with the partition unmounted. If you can't unmount it (e.g. it's your root partition or something else the system needs to run), use something like System Rescue CD instead.

Run parted, or gparted if you prefer a GUI, and resize the partition to use the extra space. I prefer gparted as it gives you a nice graphical representation, very similar to the one you've drawn in your question.

(parted) select /dev/sdX
(parted) resizepart
(parted) 100%

```bash
root@client:$ resize2fs /dev/whatever
root@client:$ e2fsck /dev/whatever #(just to find out whether you are on the safe side)

```
and remount your partition.

> How would you resize an LVM partition?


```bash
root@client:$ fdisk -l
root@client:$ parted # resizepart | <Zahl der Partition> | 100% | quit 
root@client:$ pvresize /dev/sda3
root@client:$ lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
root@client:$ resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
root@client:$ df -h
```

### Mounting partitions 

0. on the command line: 
Problem is it won't persist with a reboot

1. automatically with fstab:

in the fstab here's what each section does:
- first section specifies what you want to mount i.e. the target partition
- second section specifies where you want to mount it
- next one specifies the partition type
- next one specifies whether the partition should mount on boot with the -a command. If yes then specify "defaults"
- next one is the dump section. most modern systems don't use the dump aka "backup" section anymore 
- next one is the pass section. 1 is the highest priority when running fsck on boot, 0 means no checks and 2 means it is checked after the disks in that have pass=1. Advantage of the 2 is that it can run in parallel to other pass=2 disks. Another advantage is that, if a disk with pass=1 in /etc/fstab is faulty or fails fsck, the system may not boot normally and can drop you into emergency mode. Be aware that this option will be overriden by the tune2fs frequency

2. automatically with systemd

you can stop an existing mount with systemd

all relevant files can be found under /run/systemd/generator


## LVM

skipped. i'm planning to use zfs or btrfs for personal use and ceph at work. It makes no sense for me (right now) to learn LVM

## Sharing file systems over the network

### nfs

on the debian server:

```bash
root@server:$ apt update && apt install nfs-kernel-server
root@server:$ nano /etc/exports

/testshare 192.168.1.0/24(rw,root_squash)

root@server:$ systemctl start nfs-kernel-server
root@server:$ exportfs -r
root@server:$ exportfs # verify that the share is there
```

you could have had read only with the ro option, root_squash separates the client root account from the server's root account in terms of permissions 

on the debian client:

```bash
root@client:$ apt update && apt install nfs-utils
root@client:$ mount 192.168.1.5:/testshare testshare
```

You can persist this mount with fstab

```bash
root@client:$ nano /etc/fstab
192.168.1.5:/testshare  /mnt/testshare   nfs    defaults    0   0 
```
notice the pass and dump options are turned off 

### samba
On the debian server:

```bash
root@smbserver:$ apt update && apt install samba
root@smbserver:$ systemctl status smbd
root@smbserver:$ smbstatus --version
```


```bash
root@smbserver:$ nano /etc/samba/smb.conf

[share]
path = /home/sambauser/share
valid users = sambauser
read only = no
browseable = yes
```


```bash
root@smbserver:$ systemctl restart smbd
root@smbserver:$ systemctl restart nmbd
root@smbserver:$ nmblookup smbserver # should return our ip address

root@smbserver:$ adduser sambauser
root@smbserver:$ smbpasswd -a sambauser
root@smbserver:$ mkdir /home/sambauser/share
root@smbserver:$ chown sambauser:sambauser /home/sambauser/share
root@smbserver:$ chmod 700 /home/sambauser/share
root@smbserver:$ testparm

```

On the debian client:


```bash
root@smbclient:$ apt update && apt install samba-client && apt install cifs-utils
root@smbclient:$ nmblookup smbserver # should return the server's ip address
root@smbclient:$ mount -t cifs //192.168.1.5/home/sambauser/share /mnt/share -o username=sambauser,password=sambauser

```

## managing services

### systemctl

you can mask services so that you won't be able to start it

```bash
root@tutorial:$ systemctl start nginx.service
root@tutorial:$ systemctl mask nginx.service
root@tutorial:$ systemctl status nginx.service # running
root@tutorial:$ systemctl stop nginx.service # stopped and masked
root@tutorial:$ systemctl start nginx.service # won't work
```

### cron

on ubuntu place your bash scripts within the /etc/cron.daily

crontab -e creates a user crontab that can be listed with ```crontab -l```

## processes

you can edit the fields that appear in top by typping f

lsof can be used to look at open files at any moment in time

You can look at the open files for a specific pid

```bash
root@tutorial:$ lsof -p 28671
```

You can look at the open files for a specific user

```bash
root@tutorial:$ lsof -u ubuntu
```

You can look at the open network connections. -P gives us the actual ports and not the inferred protocols

```bash
root@tutorial:$ lsof -i -P
```

instead of going through top to find the pid you can also type 

You can look at the open files for a specific pid

```bash
root@tutorial:$ pidof nginx
root@tutorial:$ ps -o ppid= -p 4845
root@tutorial:$ pkill nginx

```

but if you don't know the name of the service you can use pgrep to get partital matches

```bash
root@tutorial:$ pgrep ngin
```

you can change the priority of a process by reducing the nice index. 


```bash
root@tutorial:$ nice -n -10 sleep 600&
```
By adding a & to a command you send the process to the background which effectively gives the control back to the user instead of running in the foreground

you can later change the value if you so wish

```bash
root@tutorial:$ renice -10 -p 6849
```

## managing interfaces

You can see who is online on a computer with the command w

```bash
root@tutorial:$ w
```

ifconfig useful to see receive packets RX, transfered packets TX as well as errors perstaining to both flows. By using the -a flag you see all of the interfaces both online and offline.

```bash
root@tutorial:$ ifconfig -a
```
You can also turn off an interface with the ```ifconfig enp0s1 down``` command

communication between two machines is done over the level 2 mac address. In order for machine 1 to know where machine 2 is it will send out an arp request to know what the level 2 address is the communication can happen. You can see your machine's ARP cache by using the cli with the following command:

```bash
root@tutorial:$ arp -a
```

If you want to communicate outside of your switch's zone you'll have to talk to the gateway which is the device that will bridge the communication with other networks. You can control routing tables on linux with the route command 

```bash
root@tutorial:$ route -n
root@tutorial:$ route add -net 192.168.2.0 netmask 255.255.255.0 gw 10.10.89.1
```

ifconfig and route are deprecated though and i should be using the ip command instead

```bash
root@tutorial:$ ip route show
root@tutorial:$ ip route add 192.168.64.56/24 via 10.250.3.44 dev enp0s1
```


nmcli is the modern way of managing the networkmanager


```bash
root@tutorial:$ nmcli device status
root@tutorial:$ nmcli connection add type ethernet ifname ens18 connection.id "TestCon"

```

This command should create a network profile inside of /etc/NetworkManager/system-connections on ubuntu

Set a static ip with nmcli:

```bash
root@tutorial:$ nmcli con mod ens18 ipv4.address "10.250.3.33/24"
root@tutorial:$ nmcli con mod ens18 ipv4.gateway 10.250.3.1
root@tutorial:$ nmcli con mod ens18 ipv4.dns 10.250.3.1
root@tutorial:$ nmcli con mod ens18 connection.autoconnect yes
root@tutorial:$ nmcli con mod ens18 ipv4.method manual
root@tutorial:$ nmcli con mod ens18 ipv4.dns-search thekor.eu
```

To investigate sockets there are two commands: netstat and ss


```bash
root@tutorial:$ ss -tulnp
root@tutorial:$ netstat -tulnp

```

-t: TCP sockets

-u: UDP sockets

-l: Only show listening sockets

-n: Show numerical addresses (don’t resolve names)

-p: Show process using the socket

You can verify your hosts' FQDN with the following command:

```bash
root@proxmox07:~# hostname -f
proxmox07.thekor.eu
```

You can also get some valuable information regarding the name servers used and the mx records of a domain by typing:

```bash
root@proxmox07:~# hostname -v thekor.eu
```

## networking

nsswitch is a file that decides the priority we set for /etc/hosts vs external dns servers

/etc/resolv.conf shouldn't be modified directly as it is managed by NetworkManager

ping has some flags that allow us to see how many routers/hops did we take to reach a particular server i.e. TTL time to live

traceroute works by gradually incrementing the TTL from 1 to n and saving the ouput between increments

a tool that merges the ping and traceroute command is called mtr. By merging the two we get to see network statistics like packet loss

## package manager

dpkg is used to install single packages on debian based systems

to handle dependencies however it is much better to just use apt or aptitude

rpm is the dpkg analog in the red hat world

you can either restart or reload configuration files. The advantage of reloading is that you won't get downtime

## logging

you can define which error levels/severity get logged by your ring buffer in your /etc/syslog.d/*.conf

by default you can look at your critical logs by running:

```bash
root@tutorial:~# journalctl -p 2
```

systemd service are logged into journalctl  

## public key cryptography

gpg is used to encrypt files and plays well with the linux keyring. The only problem is that if you're going to be using encrypted files a lot you'll want to encrypt the whole drive instead. As a file grows you'll have to wait a long time as the task is very cpu intensive.

asymetric public key cryptography is fairly simple. Both parties publish their public keys. Once you want to communicate sensitive data then simply use the recipients public key to encrypt the file.

## authentication

you can use pam to enfore mfa and group policies like users are only allowed to sign in between monday and friday or brute force protection

## harden your system

1. you can restrict access to the dmesg kernel messages to administrators only for example.

2. you can edit the /etc/pam.d to improve password quality like minimal length and number of digits or the number of uppercase chars within the password. You can even make sure that at least 2 chars are different compared to the previous password.

3. you can decide to not reply to any icmp messages by tuning your kernel parameters. 

```bash
root@tutorial:~# sysctl -w net.ipv4.icmp_echo_ignore_all=1
```
but in order to make it persistent you'll have to write those changes into /etc/sysctl.conf

```bash
root@tutorial:~# cat /proc/sys/net/ipv4/icmp_echo_ignore_all
0
root@tutorial:~# sysctl -p
root@tutorial:~# cat /proc/sys/net/ipv4/icmp_echo_ignore_all
1
```

4. add selinux?

## packaging

be careful when removing packages on ubuntu. You can run this command to see what dependencies are behind each program with ```apt depends``` or see what depends on the program that you are removing ```apt rdepends```

```bash
root@tutorial:~# apt rdepends nginx
```

## user management

you can add default files to any user created on a machine by placing them in the /etc/skel directory

you can prevent someone from loging into a system by changing their shell from /bin/bash into /bin/false

## firewalls

### firewalld

Incoming traffic: Blocked unless allowed by zone/service.

Outgoing traffic: Allowed by default.

The default zone is usually public. You can check it with: 

```bash
root@tutorial:~# firewall-cmd --get-default-zone
```

You can specify zones in case the machines moves to a public space or to a dmz and then change the applied zone accordingly. Alternatively you can set an interface to a zone.

```bash
root@tutorial:~# firewall-cmd --zone=home --change-interface=eth0 --permanent
```
set some rules:

```bash
root@tutorial:~# firewall-cmd --zone=public --add-port=8080/tcp --permanent
root@tutorial:~# firewall-cmd --zone=public --add-service=ssh --permanent
root@tutorial:~# firewall-cmd --reload # Changes persist after reboot, but don’t apply until you reload.
```


### iptables

tables (filter, nat, mangle, raw, security), chains (INPUT, OUTPUT, FORWARD) and rules. Rules combine chains and tables. Not any table chain combination is allowed. The filter table can only be combined with an input a forward or an outbound chain.

chains pertains to whereabouts in the connection you want to apply a rule: 
1. prerouting: before any routing calculation has taken place?
2. input: happens after routing calculation has taken place and is destined to our forward server 
3. forward: 
4. outbound: 
5. post routing: when we are exiting

if a packet comes in destined to us the chains that get triggered are: prerouting and input 
if a packet comes in destined to someone else the chains that get triggered are: prerouting and forward and post routing 
if we send a packet the chains that get triggered are: output and post routing 

-I inserts a rule in the top of the list. If we do a deny all at the top it doesn't matter what the next rules are since they will be ignored
-A appends a rule at the end of the list

```bash
root@tutorial:~# iptables -A INPUT -p tcp --dport 22 -j ACCEPT
root@tutorial:~# iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
root@tutorial:~# iptables -L -v -n # shows all chains for filter table
root@tutorial:~# iptables -t nat -L -v -n # shows all chains for nat table

```

```bash
root@tutorial:~# iptables -P INPUT DROP
root@tutorial:~# iptables -P FORWARD DROP
root@tutorial:~# iptables -P OUTPUT ACCEPT

```

To apply these changes:

```bash
root@tutorial:~# iptables-save > /etc/iptables/rules.v4 # debian
root@tutorial:~# iptables-save > /etc/sysconfig/iptables # red hat

```

### ufw

default behavior is the same as firewalld so all outgoing traffic is allowed and all incoming traffic is refused by default

```bash
root@tutorial:~# ufw enable      # Turn on the firewall
root@tutorial:~# ufw disable     # Turn it off
root@tutorial:~# ufw status      # See current rules
root@tutorial:~# ufw allow ssh
root@tutorial:~# ufw allow from 192.168.1.0/24 to any port 22
root@tutorial:~# ufw delete allow 22
root@tutorial:~# ufw app list # These profiles are stored in /etc/ufw/applications.d/.
```

## access control 

you can make files immutable and remove the immutability bit


```bash
root@tutorial:~# chattr +i file.txt
root@tutorial:~# chattr +i file.txt
root@tutorial:~# lsattr file.txt
root@tutorial:~# chattr -R +i Dir/

```

you can make files append only with +a, you can compress or encrypt a file with the +c and +e respectively

### access control lists

setfacl and getfactl are used to change the bahvior of some directories. For instance if we nee  all new files in a directory to inherit certain permissions:

```bash
root@tutorial:~# setfacl -d -m u:john:rw /shared/dir
root@tutorial:~# setfacl -d -m g:marketing:rw /shared/dir
root@tutorial:~# getfacl /shared/dir

```

and remove them:

```bash
root@tutorial:~# setfacl -x u:john:rw /shared/dir
root@tutorial:~# setfacl -x g:marketing:rw /shared/dir
root@tutorial:~# getfacl /shared/dir

```

### apparmor

control what files and network ports can be used
 

```bash
root@tutorial:~# ls /etc/apparmor.de/ # policies
root@tutorial:~# aa-status
root@tutorial:~# aa-enforce /usr/sbin/sssd

```

### selinux

Think of it as a strict security policy enforcement tool that decicdes what processes can access which files, sockets, ports, etc.

## permissions

You can use symbolic notation or octal notation to manage permissions on the file system

```bash
root@tutorial:~# chmod o=rwx file.txt # give others read write execute
root@tutorial:~# chmod a=rwx file.txt # give everyone read write execute
root@tutorial:~# chmod u+x,o=-rwx file.txt  # give user execute and remove read write execute for others
```

use a combination of 4, 2, and 1 to build these commands

```bash
root@tutorial:~# chmod 007 file.txt # give others read write execute
root@tutorial:~# chmod 777 file.txt # give everyone read write execute
root@tutorial:~# chmod 107 file.txt  # give user execute and remove read write execute for others
```

Make sure that you're able to execute on directories otherwise you won't be able to cd into them 

Even if the file has write permissions for your user, if the directory where it resides does not then you can't

SUID is the 4th hidden permission bit that can be used on files. You grant it with u+s or 4 in the octal notation. This allows any user for example write into the /etc/passwd directory without giving out sudo privileges


```bash
root@tutorial:~# chmod u+s file.txt
root@tutorial:~# chmod u-s file.txt
root@tutorial:~# chmod 4744 file.txt
root@tutorial:~# ls -l /usr/bin/passwd
-rwsr-xr-x 1 root root 59640 Mar 22  2019 /usr/bin/passwd

```

GUID is the SUID hidden permission bit that can be used on directories. You grant it with g+s or 2 in the octal notation. This allows us to run files as the group. If set on a directory, any files created will have their group ownership set to the group owner of the directory


```bash
root@tutorial:~# chmod g+s Dir/
root@tutorial:~# chmod g-s Dir/
root@tutorial:~# chmod 2744 Dir/

```

What your files to stick around? You can set a directory with a sticky bit in order to prevent any file from being deleted. Once it's set only root and the owner can delete files

```bash
root@tutorial:~# chmod o+t Dir/
root@tutorial:~# chmod o-t Dir/
root@tutorial:~# chmod 1744 Dir/
              
```

There are default permissions in linux, new files for instance have a 666 permission set by default and 777 for directories. What if we need to change the default permissions that any new file or new directory? That is where the umask command comes in. 


```bash
root@tutorial:~# nano /etc/profile
root@tutorial:~# nano ~/.bashrc
umask 022
(...)
```

## bash scripting

linux does not look at the file extension to determine if it's a script or not. bash scripts have a shebang at the beginning of the file

## git

you can checkout particular commits by specifying the commit hash which will detach you from the branch where you were working. 

This is particularly useful when working with tags because you can then replacing that long commit hash by the tag

```bash
root@tutorial:~# git checkout v1.0

```

## infrastructure as code

ansible is an agentless. You specify an inventory where you store ip addresses and passwords. You then create a playbook that specifies your desired state.

Keep in mind that json does not support comments


## debug network issues

shows statistics for drops or misses:

```bash
root@tutorial:~# ip -s link show enp0s1

```

powershell: 

```powershell
PS C:\Users\Documents> Get-NetAdapter -Name "Ethernet"

```

## debugging disks

iops is the measurement of speed. Input output per second measures how much data is coming accross per second. You can have a look at those with the iostat command

you can debug filesystem issues by unmounting a partition and running e2fsck on it

troubleshooting hard drives starts with smart scans. Over time electrical or mechanical issues turn our valuable data into bad blocks. To identify them simply run 

```bash
root@tutorial:~# badblocks -v /dev/sda1

```

deleting files on SSDs don't automatically get deleted. The corresponding blocks are simply marked for deletion. In order to make our SSD's run faster we can delete those stale blocks. On a mounted file system simply:


```bash
root@tutorial:~# fstrim -v /

```

Over time mechanical hard drives need to be defragmented otherwise you'll lose performance because the data is scattered around. 

```bash
root@tutorial:~# apt install e2fsprogs # debian
root@tutorial:~# dnf install e2fsprogs # fedora
root@tutorial:~# e4defrag -c /hdd # scan
root@tutorial:~# e4defrag /hdd #defragment

```

## systemd and boot targets

Back in the day linux used to boot with run levels with sysvinit. When the run level is set to 0 the system shuts down, by setting it to 6 it reboots, 1 stands for single user mode and is used for administration tasks because only the root can login. In this mode you can repair issues like file system corruption or grub related issues. At level two you can access you personal files but there is no networking. Level 3 is multi user with networking and level 4 adds a graphical interface. Level 5 is full mode which means you have access to the whole system. 

Nowadays systemdreplaced systemd which means we don't use runlevels anymore but instead use targets. 

- poweroff.target is the equivalent of runlevel 0 in systemd
- rescue.target is the equivalent of runlevel 1 in systemd
- multi-user.target is the equivalent of runlevel 2, 3, 4 in systemd
- graphical.target is the equivalent of runlevel 5 in systemd
- reboot.target is the equivalent of runlevel 6 in systemd



```bash
root@tutorial:~# systemctl get-default
graphical.target
root@tutorial:~# systemctl isolate multi-user.target # instantly switches to that target but is not persistent
root@tutorial:~# systemctl set-default multi-user.target # persists target change. you'll login to this target on next reboot

```

Whenever you change the configuration on /etc/fstab it automatically generates systemd services that do the mounting in the background. Those services can be found here: 

```bash
root@tutorial:~# ls /run/systemd/generator/*.mount

```

## quotas

you can impose quotas on a docker process by editing the docker compose file. Additionnaly if you're running a docker as a service on a server you shoud consider editing the daemon.json file so that it rotates the logs. By default docker does not delete any logs which could cause your service to crash if you're only using one partition. 

It's also possible to set up soft and hard quotas on linux by editing the /etc/fstab file 

```bash
root@tutorial:~# nano /etc/fstab # add usrquota,grpquota in the file system options
root@tutorial:~# mount -o remount /
root@tutorial:~# quotacheck -ugcm /dev/sda # creates configuration files
root@tutorial:~# edquota john # edit quota for a user called john
root@tutorial:~# edquota -g testgroup # edit quota for a group
root@tutorial:~# quotaon -vug /dev/sda
root@tutorial:~# repquota /
root@tutorial:~# su john
root@tutorial:~# quota
```

careful before modifying existing quotas you have to disable existing ones otherwise you risk damaging the file system

## The 3 2 1 backup rule

3 total copies of your data: your working copy, primary backup and secondary backup
2 different types of storage media: which could either be a local SSD, a NAS, bluray
1 off-site copy