---
title: Opinions on an android Remote Access Trojan (RAT)
author: hugo
date: 2023-04-04 09:11:00 +0200
categories: [Tutorial, security]
tags: [hacking, android]
render_with_liquid: false
---


> This tutorial will guide you through the process of infecting Android phones with a trojan. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }

## The art of deception

_The best defense is a good offense_. Once you're able to write this up and distribute it yourself you'll get a good grasp of how this attack works and what to look out for to stay protected on the internet. Let's define what a trojan is and what we intend to do here today.

<em>In computing, a Trojan horse is any malware that misleads users of its true intent by disguising itself as a real program. The term is derived from the ancient Greek story of the deceptive Trojan Horse that led to the fall of the city of Troy.</em> [`Wikipedia`](https://en.wikipedia.org/wiki/Trojan_horse_(computing)).

To perform this attack you will need to have physical access to the phone you're targeting because Android is able to identify it as a trojan and tries to prevent you from installing it.
