---
title: SSO part 3 Wireless network Access Control and VLANs
author: hugo
date: 2025-07-26 09:11:00 +0200
categories: [Tutorial, infrastructure]
tags: [SSO, active-directory]
render_with_liquid: false
---

## Introduction

[We previously set up a single sign on system](https://chirpy.thekor.eu/posts/wireless-network-access-control/) with the windows active directory, unifi switches, unifi access points, authentik as the OIDC provider and freeradius. I was able to get wifi to work but now I'd like to take it one step forward. 

If you follow up on the previous guide, our users automatically land on the switches VLAN which is not what we want. We'd like our users to be assigned an IP from their department's VLAN so that they keep the same network level permissions whether they are cabled or work from the wireless network. This would allow people to access internal services from another room in the building and take us one step closer to centralization and control.

## How it works

Freeradius is forwarding the authorization and authentication to the active directory so it would make sense to have it decide of the VLAN we should be in. Employees are created and managed in the organizational unit OU called Employee which is then split into multiple OUs to group employees into departments e.g. Finance, IT, Sales and so on. Freeradius can therefore determine the vlan tag from the OU that they are in. 

## Configuring the domain controller

Since the mapping is made by simply querying the distinguished name DN in the LDAP source and extracting the OU there is not much configuration to be done on here. 

A footnote is worth mentioning here though. The DN query will return OU = NULL because of german special characters like "ß", "é" and others. In this case the query should revert to the department attribute in the Active directory:

![active directory properties](</assets/img/posts/ad.png>)


## Configuring the debian server


Users get authenticated and authorized via the EAP inner-tunnel which triggers an ntlm query in our active directory (over the samba connection). If the flow is successful, we would want freeradius to query the VLAN and return the 802.1Q header back to the wifi device. Freeradius has a hook for this state so we'll use it to run a simple bash script that queries the OU and infer the VLAN. 

Let's start by installing and configuring the exec program to query our users' VLAN attribute. exec is a utility binary from freeradius that allows us to run bash scripts.

```bash
root@radius:$ apt install freeradius-util
root@radius:$ ln -s /etc/freeradius/3.0/mods-available/exec /etc/freeradius/3.0/mods-enabled
root@radius:$ find /usr/lib /usr/lib64 /lib -name 'rlm_exec.so*' 2>/dev/null
/usr/lib/freeradius/rlm_exec.so

root@radius:$ dpkg -l | grep freeradius
ii  freeradius                     3.2.1+dfsg-4+deb12u1                amd64        high-performance and highly configurable RADIUS server
ii  freeradius-common              3.2.1+dfsg-4+deb12u1                all          FreeRADIUS common files
ii  freeradius-config              3.2.1+dfsg-4+deb12u1                amd64        FreeRADIUS default config files
ii  freeradius-ldap                3.2.1+dfsg-4+deb12u1                amd64        LDAP module for FreeRADIUS server
ii  freeradius-utils               3.2.1+dfsg-4+deb12u1                amd64        FreeRADIUS client utilities
ii  libfreeradius3                 3.2.1+dfsg-4+deb12u1                amd64        FreeRADIUS shared librar
```


configure the post-auth hook in the default site to trigger the module:

```bash
root@radius:$ nano /etc/freeradius/3.0/sites-available/default

post-auth {

    # Assign VLAN for authenticated users
     exec

     (...)
}
```

```bash
root@radius:$ nano /etc/freeradius/3.0/mods-available/exec

exec {
    wait = yes
    input_pairs = request
    output_pairs = reply
    program = "/etc/freeradius/3.0/get_vlan.sh %{User-Name}"
    shell_escape = yes
}
```


```bash
root@radius:$ nano /etc/freeradius/3.0/get_vlan.sh

#!/bin/bash

USERNAME="$1"
DEFAULT_VLAN="7"
LDAP_URI="ldap://fqdn"
BIND_DN="serviceaccount@domain"
BIND_PW="password"
BASE_DN="dn where the users are"
DOMAIN="domain name"

# Find the user's DN (Distinguished Name)
USER_DN=$(ldapsearch -x -H "$LDAP_URI" -D "$BIND_DN" -w "$BIND_PW" -b "$BASE_DN" "(UserPrincipalName=${USERNAME}@${DOMAIN})" dn)

# Extract first OU from DN
OU=$(echo "$USER_DN" | grep -o "OU=[^,]*" | head -n 1 | cut -d'=' -f2)

# sometimes the query above will return OU = NULL because of german special characters
# in this case the query reverts to the department attribute in the Active directory
if [ -z "$OU" ]; then
    DEPT=$(ldapsearch -x -H "$LDAP_URI" -D "$BIND_DN" -w "$BIND_PW" -b "$BASE_DN" "(UserPrincipalName=${USERNAME}@${DOMAIN})" department | grep "^department:" | awk '{print $2}')
    echo "Tunnel-Type = VLAN"
    echo "Tunnel-Medium-Type = IEEE-802"
    echo "Tunnel-Private-Group-Id = $DEPT"
    exit 0
fi

# Map OU name to VLAN ID
case "$OU" in
  "Group-1") VLAN="10" ;;
  "Group-2") VLAN="11" ;;
  "Group-3") VLAN="12" ;;
  "Group-4") VLAN="13" ;;
  "Group-5") VLAN="16" ;;
  "Group-6") VLAN="15" ;;
  "Group-7") VLAN="99" ;;
  *) VLAN="$DEFAULT_VLAN" ;;
esac

# Output RADIUS reply attributes
echo "Tunnel-Type = VLAN"
echo "Tunnel-Medium-Type = IEEE-802"
echo "Tunnel-Private-Group-Id = $VLAN"

exit 0
```


## Conclusion

Another article to wrap up our SSO journey. In the next episode I'll probably look into MAC address filtering and cabled network access control with unifi. Wouldn't it be awesome if you could block unauthorized devices from your network? Yes, it's not a silver bullet but it at least adds another hurdle to jump through in order to break into our systems.

Cheers
