---
# the default layout is 'page'
icon: fas fa-info-circle
order: 4
---

Hi, welcome to chirpy thanks for stopping by. I'm a software enthusiast that tinkers with malware, content management systems, devops tools and anything I find useful to my day to day life. I run and host roughly ~ 20 web apps on my own infrastructure. Infrastucture here is a just a fancy word for a small [65 W micro computer](https://www.shuttle.eu/en/products/slim/ds10u/spec) with two Intel Celeron CPUs running @ 1.800GHz. I needed something that is as power efficient as possible while also being able to handle the workloads I intend to run in the future. 65 Watts is 0.065 kW which if you multiply by your electricity provider's cost gets you a good approximation for your bill. Mine is 0.28 euros/kWh = 18 cents per hour, 43 cents per day and 159 euros per year. The power consumption largely depends on the usage so if my system is running at 50% on average I can expect that bill to be cut in half. In the next two sections I'll go over the home lab I built up over the years and the projects I forked or bootstraped myself.

## The home lab

Let's start with an overview of my lab. 

![home-lab](/assets/img/about/backup-strategy.jpg){: width="100%"}


- **2 network attached storage devices (NAS)**: Referred to above as `Netgear Black` and `Netgear Gray`.  `Netgear Gray`'s purpose is solely dedictated to doing snapshots once a day with [rsync](https://linux.die.net/man/1/rsync). The device is mounted as a NFS share on all my devices so that they can write to it. I considered using block storage initially but I want to be able to quickly locate and recover a file or folder on it so I kept the classic file storage system. The advantage of using rsync over other solutions was the ability to do incremental snapshotting as opposed to a complete snapshot from scratch every day. My networking cables can only handle around 80-100 MB per second and I don't want to sleep with a persistent wind turbine noise in the background so I quickly opted for a tool that allowed me to do incremental backups. My second NAS is used to store anything that I don't access every single day. You could call it my artic vault.

- **My lian-li desktop**: This PC is used as my main workstation as well as my development/acceptance testing environment. I'm running the latest version of ubuntu desktop on it because I value my time and having updated consistent packages that 'just work' is invaluable for me. As for the specs they aren't anything special and don't allow me to do any GPU powered brute forcing, video editing or streaming on it. I'm also running an archaic 3rd generation Intel CPU on it and it suits all of my needs perfectly. Here is his technical name: Intel i7-3820 @ 3.800GHz. I do not do any CPU intensive tasks and value memory much more to be able to run all of these memory hungry apps like Electron based ones like Vscode, Spotify and Chrome. I'll probably ramp up on the memory soon because I do run into some bottlenecks sometimes with my 16 Gb of DDR3 RAM

- **The shuttle web server**: This bad boy hosts a variety of programs written in python, javascript and ruby. I'll go in depth into each of them on the next section. As a spoiler I do run docker on two projects but I do not intend on converting all of my projects into containers. Don't get me wrong, I think docker is a game changing technology for large corporations and dev teams in general. Docker gives you a way to attain 100% availablity and scalable services. Its also useful to manage the complexity of service oriented architecture. Another great plus of using docker is the fact you can deploy your app with it on Windows, Linux or Mac infrastructure and it will just work. As a software development tool it allows you to quickly set up all required components of your app as well. I have however 5 reasons for not using it for every single project I host. 

1. I dont have independent lifecycle needs between my apps. If I decide to update postgres I'll do it for all my apps at the same time 
2. I can manage all my workers to scale with apache. Systemd allows me to add workers easily. 
3. If my app bottlenecks on RAM or CPU, installing another 1 Gb service on RAM won't solve anything. Adding docker in this case would be like spraying gasoline on a fire. 
4. I don't do service oriented architecture (SOA) or micro services because i lose the benefit of version control and being able to rollback on my mistakes 
5. I use a similar environment to the target production so i dont need any fancy packaging system. I can see how they are useful in a team of devs and how easy they make lifecycle management in complex organizations but its hard to set up and tricky to debug with all that extra networking layer and configuration involved

## The self hosted programs I run

A picture is worth a thousand words so [here is a link](https://www.craftstudios.shop/) to an overview of some of my projects.

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">

<iframe width="100%" height="400px" src="https://youtube.craftstudios.shop/uploads/netgear/Videos/chirpy/portfolio-presentation-2023-03-28%2019-22-49.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

</div>

I use Upptime's serverless app to monitor my web apps. It's currently hosted [on Github pages](https://github.com/hupratt/upptime/tree/gh-pages) so that I can avoid the cost of spinning up a new virtual machine or virtual private service (VPS) exclusively for it. How it works is pretty simple. The app pings my different endopints every 5 minutes [and updates this page accordingly](https://hupratt.github.io/upptime/). The svelte app re-builds itself on github servers thanks to the [Github actions](https://github.com/features/actions) feature which allows you to run code for free. Thank you microsoft for this awesome feature !

28th of March 2023

