---
title: "Consul Template"
date: 2017-06-03T12:16:27-04:00

categories:
  - tech
tags:
  - consul
  - consul-template
  - ops
  - tutorial
---

## Introduction

In this tutorial, we will be using Consul and consul-template to fetch configuration values for a simple application (a chatbot), then watch for updates to the configuration values and automatically restart the service if a value changes. Finally, we will wrap all of this in a Docker container.

This tutorial also assumes you have a Consul cluster up and running. If you don't have one, set one up a dev instance real fast and expose it on localhost like this:

```
docker run -d --name=dev-consul -p 8500:8500 consul
```

This will expose a single-node consul cluster which other containers or local apps can use either by linking or addressing http://localhost:8500 from your host machine. *Do not use this in prod*, this is just for a demonstration.

-------

### What even is consul-template

First, a quick explanation of [Consul](https://www.consul.io/) and [consul-template](https://github.com/hashicorp/consul-template). 

Consul, in Hashicorp's own words: 

> Consul has multiple components, but as a whole, it is a tool for discovering and configuring services in your infrastructure. 

and one key feature of Consul:

> KV Store: Applications can make use of Consul's hierarchical key/value store for any number of purposes, including dynamic configuration, feature flagging, coordination, leader election, and more. The simple HTTP API makes it easy to use.

In other words, you can set an arbitrary key to an arbitrary value (like `app/foo="bar"`) which applications can read back (ie `GET app/foo` returns `"bar"`) and use for configuration or other things. Hashicorp's consul-template takes that key/value store and integrates it with Go's templating language to allow users to build configuration files from a mix of static and dynamic data. It also provides an additional feature that watches keys rendered and "manages" a child process by attempting to restart it if a value changes. This is ideal for applications that consume config files and require restarts to pick up changes to those files. 

-------

### The demo application

As our demo application, we'll use a [Legobot](https://github.com/bbriggs/MissMoneyPenney) I deployed to an IRC community I hang out in. If you want to follow along at home, go ahead and clone this down.

There are a few files in root, but only 3 are important for this: 
 - `chatbot.py`
 - `requirements.txt`
 - `config.ini`

I wrap all this in a Python docker container (see `run.sh`) but the workflow is the same: Install requirements in `requirements.txt`, then start it with `python ./chatbot.py`, which loads its configs from `config.ini`. The goal here is to replace the hardcoded values in the config file with dynamically generated content from Consul. 

Here is the original `config.ini`:

```
[irc1]
channels=#0x00sec,#rp
username=MissMoneyPenney
password=
host=irc.0x00sec.org
port=6697
ssl=True
```

Let's go ahead and replace these with values we have set in our Consul cluster (connecting to the UI at http://127.0.0.1:8500 in your browser is useful for this next part). Call it `config.ini.tmpl`:

```
[irc1]
channels={{ '{{ key "bots/mmp/channels" ' }}}}
username={{ '{{key "bots/mmp/username" ' }}}}
password={{ '{{ keyOrDefault "bots/mmp/password" "" ' }}}}
host={{ '{{ key "bots/mmp/host ' }}}}
port={{ '{{ keyOrDefault "bots/mmp/port" "6697" ' }}}}
ssl={{ '{{keyOrDefault "bots/mmp/ssl" "True" ' }}}}
```

Notice that I used a different function for some keys: `keyOrDefault` does just what it sounds like: It looks for a key at the given location and adds the second argument if the key isn't found. As you're setting these keys in your Consul cluster, I recommend using values for your own desired IRC server and channel.

### Running the app

I have published this container on [Docker Hub](https://hub.docker.com/r/bbriggs/consul-template-demo/) for your convenience, but I'm going to go ahead and show the Dockerfile with a breakdown of each section:

```
# Use whatever base works for your app
FROM python:3

# Install consul-template
WORKDIR /tmp
RUN curl https://releases.hashicorp.com/consul-template/0.18.5/consul-template_0.18.5_linux_amd64.tgz -o consul-template.tgz
RUN gunzip consul-template.tgz
RUN tar -xf consul-template.tar
RUN mv consul-template /opt/consul-template
RUN rm -rf /tmp/consul-template*

# I use /usr/src for this app. Again, whatever works for you
WORKDIR /usr/src

# I did this wrong and ended up with multiple instances of the same bot in a channel, so this will gets its own paragraph
CMD pip install -r ./requirements.txt && /opt/consul-template -config "consul-template.hcl" --template "config.ini.tmpl:config.ini" -exec "python ./chatbot.py"
```

This Dockerfile assumes that you have a consul-template config called `consul-template.hcl` in the working dir and you have a template called `config.ini.tmpl` that consul-template will consume. Since we are linking the consul container, the consul-template config points to a hostname of `consul`.

```
docker run -it --name mmp --link dev-consul:consul -v `pwd`:/usr/src bbriggs/consul-template-demo
```

Check and see that the bot is running in your IRC channel, and follow the docker logs to watch it build:

```
docker logs -f consul-template-demo
```
---------

### Watching exec mode magic

Consul-template's exec mode allows consul-template to watch for changes in keys it has rendered in the template while managing the a child process you tell it to start. In our case, we told it to start a python application.

Now that the container is running and hopefully responding to commands in the IRC channel (try sending `!help` in the channel to test), open up the Consul web UI, navigate to the key-value store, and change the username/nickname of the bot while watching the docker logs. If everything was done right, consul-template will send a SIGTERM to the `python chatbot.py` process then start it again. As the python process starts again, it will consume the new config that consul-tempalte has generated. Ta-da! We now have an application that automatically updates on changes to consul values, even if it wasn't exactly consul-friendly to begin with!

### A small caveat

While it's handy, you should also take note of how exec mode handles the process you give it: exec mode will attempt to send a SIGTERM to the process and then start it again. Remember when I said I accidentally ended up with lots of legobot instances running around? That's actually what happened here. The original:

```
CMD /opt/consul-template --template "config.ini.tmpl:config.ini" -exec "pip install -r ./requirements.txt && python ./chatbot.py"
```

This meant that the sigterm was getting sent to pip install and not python. I tried this again by putting both into a bash script, but the same problem happened. Two solutions:
  1. Trap the SIGTERM in bash, like Hashicorp suggests
  1. Arrange your CMD or ENTRYPOINT so that non-persistent tasks (like a `pip install`) are ordered first and the SIGTERM gets sent to the right place.

Read more on this in the consul-template [documentation on exec mode](https://github.com/hashicorp/consul-template#exec-mode).

### Homework

Experiment with Consul and consul-temaplte for yourself by applying this to other services such as Nginx. You can also play around with different ways of getting consul template to talk to consul, such as using the `--net=host` option, linking containers, or port forwarding.

Happy hacking!
