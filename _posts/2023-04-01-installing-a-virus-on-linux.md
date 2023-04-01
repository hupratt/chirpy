---
title: A simple virus for Linux
author: hugo
date: 2023-04-01 15:11:00 +0200
categories: [Tutorial, programming]
tags: [systemd, hacking, python, c++]
render_with_liquid: false
---


> This tutorial will guide you through the process of infecting Linux based computers with a trojan. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }


## The art of deception

_The best defense is a good offense_. Once you're able to write this up and distribute it yourself you'll get a good grasp of how this attack works and what to look out for to stay protected on the internet. Let's define what a trojan is and what we intend to do here today.

<em>In computing, a Trojan horse is any malware that misleads users of its true intent by disguising itself as a real program. The term is derived from the ancient Greek story of the deceptive Trojan Horse that led to the fall of the city of Troy.</em> [`Wikipedia`](https://en.wikipedia.org/wiki/Trojan_horse_(computing)).

To perform this attack you will need to know the Linux distribution and the processor architecture of your target. We are thankfully blessed with a myriad of distributions in Linux which probably explains why there are so few trojans for Linux out there. A second factor that probably explains why there are few reported viruses for linux is the simple fact that there are very few people running Linux as their main desktop distribution. Don't believe me? Head over to [amiunique.org](https://amiunique.org/) and see for yourself. 

![click-jacking success](/assets/img/posts/2023-04-01_15-17.png){: width="100%"}

1.11% of internet users are apparently connected to the internet with a ubuntu desktop environment. This information seems in line [with what wikipedia is saying](https://en.wikipedia.org/wiki/Usage_share_of_operating_systems#:~:text=For%20desktop%20and%20laptop%20computers,US%20up%20to%206.2%25) as well


## Requirements

The only thing you'll need in this network penetration test are two things: python and some C++ libraries


## Setting up the local environment


Start off by cloning [my repository from git](https://github.com/hupratt/aura-botnet) or create the tree folder structure pictured below

```console
    [waz@localhost]# mkdir -p aura-server && cd aura-server
    [waz@localhost]# virtualenv env
    [waz@localhost]# python
    Python 3.10.6 (main, Mar 10 2023, 10:55:28) [GCC 11.3.0] on linux
    Type "help", "copyright", "credits" or "license" for more information.
    
```
Make sure to activate the environment and install. Now either `pip install django` or `pip install -r requirements.txt` in case you want to use the same exact version number of the libraries I use.

Let's go over the main folders in the project to start with a big picture overview. The virus itself is located in `aura-client`. Once installed this program will receive payloads via http that it will execute and ship back the standard output of those commands back to the web server.
`aura-server` is a webserver that will allow us to fingerprint our target(s), define commands we should run on our target(s) and whether those commands should run one time or every time the timer triggers. Our third and last important folder is the systemd one. This folder houses the agent and the kernel timer handler. Depending on the kind of permissions used to execute the trojan we will either install a systemd services or the kernel timer handler. Don't worry this choice is already baked into the program itself. 

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
You can now navigate to http://localhost:41450/admin and input the credentials on the last step. You should be greeted with the following page:

![admin page](/assets/img/posts/2023-04-01_23-26.png){: width="100%"}

Click on "Commands" to create our first command on the admin page. I'll run a harmless command `ls -lha` which lists the items in the current directory.
Once installed our target will appear in the "Bots" section

![creating our first command on the admin page](/assets/img/posts/2023-04-01_23-27.png){: width="100%"}

## Building the trojan

