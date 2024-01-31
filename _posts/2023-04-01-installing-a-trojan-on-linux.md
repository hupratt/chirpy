---
title: A simple trojan for Linux
author: hugo
date: 2023-04-03 15:11:00 +0200
categories: [Tutorial, security]
tags: [systemd, hacking, python, cmake]
render_with_liquid: false
---


> This tutorial will guide you through the process of infecting Linux based computers with a trojan. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }


## The art of deception

_The best defense is a good offense_. Once you're able to write this up and distribute it yourself you'll get a good grasp of how this attack works and what to look out for to stay protected on the internet. Let's define what a trojan is and what we intend to do here today.

<em>In computing, a Trojan horse is any malware that misleads users of its true intent by disguising itself as a real program. The term is derived from the ancient Greek story of the deceptive Trojan Horse that led to the fall of the city of Troy.</em> [`Wikipedia`](https://en.wikipedia.org/wiki/Trojan_horse_(computing)).

To perform this attack you will need to know the Linux distribution and the processor architecture of your target. We are thankfully blessed with a myriad of distributions in Linux which probably explains why there are so few trojans for Linux out there. A second factor that might explain why there are few reported viruses for linux is the simple fact that there are very few people running Linux as their main desktop distribution. Don't believe me? Head over to [amiunique.org](https://amiunique.org/) and see for yourself. 

![click-jacking success](/assets/img/posts/2023-04-01_15-17.png){: width="100%"}

1.11% of internet users are apparently connected to the internet with a ubuntu desktop environment. This information seems in line [with what wikipedia is saying](https://en.wikipedia.org/wiki/Usage_share_of_operating_systems#:~:text=For%20desktop%20and%20laptop%20computers,US%20up%20to%206.2%25) as well. 


## Requirements

The only thing you'll need in this network penetration test are two things: python and some C++ libraries.

If you're on debian-like systems you can simply run the following commands to install those

```console
    [waz@localhost]# sudo add-apt-repository ppa:deadsnakes/ppa
    [waz@localhost]# sudo apt update
    [waz@localhost]# sudo apt install python3.10 python3.10-dev python3.10-venv
    [waz@localhost]# sudo apt install build-essential
    [waz@localhost]# sudo apt install libcurl4-openssl-dev
```



## Setting up the local environment


Start off by cloning [my repository from git](https://github.com/hupratt/aura-botnet) or create the tree folder structure pictured below.

```console
    [waz@localhost]# mkdir -p aura-server && cd aura-server
    [waz@localhost]# virtualenv env or python3 -m venv env
    [waz@localhost]# source env/bin/activate
    [waz@localhost]# python
    Python 3.10.6 (main, Mar 10 2023, 10:55:28) [GCC 11.3.0] on linux
    Type "help", "copyright", "credits" or "license" for more information.
    
```
Make sure to activate the environment and install the dependencies. Now either `pip install django` `pip install django-dotenv` and the postgres library for django's database adapter to work or `pip install -r requirements.txt` in case you want to use the same exact libraries I used.

Let's go over the main folders in the project to start with a big picture overview. The virus itself is located in `aura-client`. Once installed this program will receive JSON payloads via http that it will execute and ship the standard output of those commands back to the web server as JSON as well.
`aura-server` is a webserver that will allow us to fingerprint our target(s), define commands we should run on our target(s), when they should run, whether those commands should run one time or every time the timer triggers, etc. Our third and last important folder is the systemd one. This folder houses the agent and the kernel timer handler. Depending on the kind of permissions used to execute the trojan we will either install and enable a systemd service or install the kernel timer handler. Don't worry this choice is already baked into the program itself. I'm just giving a bit more context around how these tools are set up. 

```console
[waz@localhost]# tree -L 3

├── aura-client
│   ├── aura.cc
│   ├── authfile.cc
│   ├── authfile.hh
│   ├── bot.cc
│   ├── bot.hh
│   ├── build
│   │   ├── aura-client
│   │   ├── CMakeCache.txt
│   │   ├── CMakeFiles
│   │   ├── cmake_install.cmake
│   │   ├── d-bus.service
│   │   ├── d-bus.timer
│   │   └── Makefile
│   ├── CMakeFiles
│   │   ├── 3.22.1
│   │   ├── aura-client.dir
│   │   └── CMakeTmp
│   ├── CMakeLists.txt
│   ├── constants.hh
│   ├── deps
│   │   ├── json.hpp
│   │   └── picosha2.h
│   ├── installer.cc
│   ├── installer.hh
│   ├── request.cc
│   ├── request.hh
│   ├── sysinfo.cc
│   ├── sysinfo.hh
│   ├── tests
│   │   ├── CMakeLists.txt
│   │   ├── helper.hh
│   │   ├── tests-authfile.cc
│   │   ├── tests-bot.cc
│   │   ├── tests-installer.cc
│   │   ├── tests-main.cc
│   │   └── tests-request.cc
│   ├── util.cc
│   └── util.hh
├── aura-server
│   ├── aura
│   │   ├── __init__.py
│   │   ├── __pycache__
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── wsgi.py
│   ├── bots.sqlite3
│   ├── convey
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── __init__.py
│   │   ├── migrations
│   │   ├── models.py
│   │   ├── __pycache__
│   │   ├── tests.py
│   │   ├── urls.py
│   │   └── views
│   ├── env
│   │   ├── bin
│   │   ├── lib
│   │   └── pyvenv.cfg
│   ├── groups.json
│   ├── manage.py
│   ├── media
│   │   └── text
│   └── runserver.sh
└── systemd
    ├── d-bus.service
    ├── d-bus.timer
    └── root.d-bus.service
```


## Provisioning the server

If you're familiar with django this should be straightforward. Start off by initializing a sqlite database by running the migrate command. Once that's done create a super user and start the server locally

```console
    (env) waz@localhost:$ python manage.py migrate
    (env) waz@localhost:$ python manage.py createsuperuser
    (env) waz@localhost:$ python manage.py runserver localhost:41450
    Watching for file changes with StatReloader
    Performing system checks...

    System check identified no issues (0 silenced).
    April 01, 2023 - 21:24:16
    Django version 3.0, using settings 'aura.settings'
    Starting development server at http://localhost:41450/
    Quit the server with CONTROL-C.
```
You can now navigate to http://localhost:41450/admin and input the credentials that were created on the last step. You should be greeted with the following page:

![admin page](/assets/img/posts/2023-04-01_23-26.png){: width="100%"}

Click on "Commands" to create our first command on the admin page. I'll run a harmless `date` command which returns the current date and time.
Once installed the infected host will appear in the "Bots" section.

![creating our first command on the admin page](/assets/img/posts/2023-04-01_23-27.png){: width="100%"}

## Building the trojan

Now that the upstream is taken care of let's build the trojan. Change directory so that you're inside the "aura-client" directory and run the following cmake command

```console
    waz@localhost:$ cmake . -B build/
```

This command reads the cmake configuration script called CMakeLists.txt and configures a Makefile for us inside the newly created build directory. Change directory into the build directory once that's done. Next copy the "d-bus.service" and "d-bus.timer" files here and run make.

```console
    waz@localhost:$ make
```

Once that's done you'll have an executable (aura-client) that can be used to spy on other computers. I'm choosing to target my own computer here but this would work even if the target is halfway accross the world. 

The name for the service was purposefully chosen to blend into Linux systems because there is another service running permanently with the exact same name. Except the real dbus service does not have a hyphen between the "d" and the "b". You can look this up for yourself: [_Dbus is an Inter-Process Communication protocol (IPC). It allows multiple processes to exchange information in a standardized way. This is typically used to separate the back end system control from the user-facing interface._](https://www.cardinalpeak.com/blog/using-dbus-in-embedded-linux)

Before running this trojan have a look at your timers, enabled systemd services and the two following directories: ~/.gnupg and ~/.config

Let's now run the c++ executable inside our build directory

```console
    waz@localhost:$ ./aura-client
```

You'll notice that a new timer was added:

```console
    waz@localhost:$ systemctl list-timers -a
NEXT                         LEFT          LAST                         PASSED            UNIT                           ACTIVATES                       
n/a                          n/a           n/a                          n/a               d-bus.timer                    d-bus.service

```

After running the trojan the following directories will appear as well: ~/.gnupg/systemd and ~/.config/.seeds 

## Video

Just like in your previous showcases I like to complement the code with a use case. I should have probably edited the video to make it shorter but I'm too lazy for that. Here you go:

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">

<iframe width="100%" height="400px" src="https://youtube.thekor.eu/uploads/netgear/Videos/chirpy/2023-04-04%2001-04-14.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

</div>

## Conclusion

Although harmless this exercise showed us how scary and easy it is to hide a reverse shell into someone else's computer. Linus Tech tips a famous youtuber as well as many other youtubers have gotten a taste of this type of hack last month. The attackers dissimulated their trojan by modifying the picture and extension of the program so that it looked like any other inocuous PDF file. 

Linus explains that antiviruses and windows defender will skip programs that are above a certain size because it assumes viruses and trojans aren't generally above a certain threshold say 300 Mb. Well it turns out it's very easy for a programmer to add empty lines of code to generate a 700Mb file and hence bypass security. 

So if you use free software you're vulnerable to trojans but as we saw with Linus' example, proprietary operating systems are not immune either. So how can we protect ourselves from this type of attacks ? Well I think the only thing we can do is compartimentalize and limit permissions on user sessions. Having air-tight permissions will prevent an attacker from escalating his/her privileges. A second thing that would definitely help is to compartimentalize. If you're buying and selling cryptocurrencies make sure the wallet is not stored in your computer. Another tip would be to use a password vault to avoid typing any password and configure your favorite browser to remove all cookies everytime you log off so that no one can steal your session cookies to gmail for example.

Thank you for reading this far

Cheers
