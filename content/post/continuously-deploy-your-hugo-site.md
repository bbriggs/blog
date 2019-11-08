---
title: "Continuously Deploy Your Hugo Site"
date: 2019-11-07T18:57:25-05:00
draft: false
mermaid: true
---

{{< tweet 1192585307767619584 >}}

This post will explain how to build and continuously deploy and serve Hugo using ansible and a VPS. It's a simple and (mostly) lightweight process that's definitley not bulletproof, but holds up well, is unattended, stable, and more than sufficient for your personal blog.

## Infrastructure setup

For this blog, I use nginx as the reverse proxy, a sidecar for LetsEncrypt, and then finally the app as the backend.

- [nginx-proxy](https://github.com/jwilder/nginx-proxy)
- [letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion)
- [bbriggs/blog](https://github.com/bbriggs/blog)
- [bbriggs/quotes](https://github.com/bbriggs/quotes)

The docker setup is as follows:
{{<mermaid>}}
graph LR;
  jwilder/nginx-proxy<-->jrcs/letsencrypt-nginx-proxy-companion;
  jwilder/nginx-proxy-->blog.fraq.io;
  jwilder/nginx-proxy-->quotes.fraq.io;
  jwilder/nginx-proxy-->yourface.fraq.io;
{{</mermaid>}}

The nginx-proxy container manages vhosts for me and listens for new containers coming up requesting to be proxied. The letsencrypt-proxy-companion container listens for containers requesting certificates. Both of these use an environment variable in the application container to manage this.

And of course, we have the application itself. Below you can see an example of doing this in Ansible, which looks quite similar to docker compose. We setup a few volumes for nginx that it needs to have and share the certs directory so that the LetsEncrypt companion can write certs. 

We mount the socket as read-only so that the containers can peek into others that launch and determine if they need to be proxied.

```
---
- name: Create docker volumes for nginx
  become: yes
  docker_volume:
    name: "{{item}}"
  with_items:
    - nginx-conf
    - nginx-vhost
    - nginx-html
    - nginx-certs
    - nginx-htpasswd

- name: Create ngxinx proxy container
  docker_container:
    name: nginx-web
    image: jwilder/nginx-proxy:latest
    restart_policy: always
    ports:
      - "0.0.0.0:80:80"
      - "0.0.0.0:443:443"
    volumes:
      - nginx-conf:/etc/nginx/conf.d
      - nginx-vhost:/etc/nginx/vhost.d
      - nginx-html:/usr/share/nginx/html
      - nginx-certs:/etc/nginx/certs:ro
      - nginx-htpasswd:/etc/nginx/htpasswd:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
    labels:
      com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy: ""

- name: Create LetsEncrypt container
  docker_container:
    name: nginx-letsencrypt
    image: jrcs/letsencrypt-nginx-proxy-companion
    restart_policy: always
    volumes:
      - nginx-conf:/etc/nginx/conf.d
      - nginx-vhost:/etc/nginx/vhost.d
      - nginx-html:/usr/share/nginx/html
      - nginx-certs:/etc/nginx/certs:rw
      - /var/run/docker.sock:/var/run/docker.sock:ro
    env:
      NGINX_PROXY_CONTAINER: nginx-web
```


The next bit is the app container itself. For any app that needs to be proxied, it's really pretty basic. Make sure that the dockerfile has an `EXPOSE` directive for the webserver port (or you do it at startup time with `docker_container`. This is different than a port mapping, so take note of that.

```yaml
---
- name: Create Blog Webservice
  docker_container:
    name: blog
    image: bbriggs/blog:latest
    pull: true
    restart_policy: always
    state: started
    env:
      VIRTUAL_HOST: "blog.fraq.io"
      LETSENCRYPT_HOST: "blog.fraq.io"
      LETSENCRYPT_EMAIL: "admin@fraq.io"
```

And that's it! If you have a container image hosted and DNS pointing at this server, you should have a working, full HTTPS site within a minute or two.

## Continuous Delivery

Now a quick hack to automate deployments: [watchtower](https://containrrr.github.io/watchtower/)

All we're going to do here is deploy a Watchtower instance to make sure that all our images are up to date for the latest tag. If watchtower sees an update on this tag upstream, it will pull and redeploy automatically. Added bonus: it also artificially inflates your download count on Dockerhub! 
![](/images/absolute-win.gif)

```
---
- name: Deploy Watchtower to auto-update containers
  docker_container:
    name: watchtower
    image: containrrr/watchtower:latest
    pull: true
    restart_policy: always
    state: started
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

Now at this point, you should connect your repo for the app to build (in this case, a Hugo site) up to Dockerhub or whatever registry you want and have it build and publish the artifact automatically for you. Once you've done that and run this ansible (or hacked it up and done it your own way) you should have a fully automated deployment pipeline using Nginx, LetsEncrypt, and Docker for your website!

## Serving a static site using nginx

Let's say you have a static site but don't want to serve it using your SSG (which is totally fair). Here's how you might do that (assuming you have the site in your Ansible role):

```yaml
---
- name: Create app directory
  become: yes
  file:
    owner: root
    group: root
    state: directory
    mode: 0755
    path: /etc/yourface

- name: Copy Yourface app code to directory
  copy:
    src: src
    dest: /etc/yourface

- name: Create Yourface App
  docker_container:
    name: yourface-{{env}}
    image: nginx:stable-alpine
    restart_policy: always
    cap_drop:
      - all
    volumes:
      - /etc/yourface/src:/usr/share/nginx/html:ro
    env:
      VIRTUAL_HOST: "yourface.{{domain}}"
      LETSENCRYPT_HOST: "yourface.{{domain}}"
      LETSENCRYPT_EMAIL: "admin@{{domain}}"

```

## Coda: Is this "production quality"?

Pretty frequently I see objections to serving content directly from Hugo or whatever because it's not "production quality." My answer to this is short: production quality is whatever meets your threat model and workload. For the absolute vast majority of blogs, that means Hugo is more than enough in terms of performance. If you're worried about more nuanced webserver management things, do that at the reverse proxy level. That's why it's there.

Furthermore, if you _think_ you might need that extra oomf of a more performant webserver to do your work for you, then don't do it on intuition alone. Do some measurement, figure out what your limits are, watch traffic, and then make the decision based on that. If you're unsure of what that process looks like, I recommend [this excellent book](https://www.amazon.com/Every-Computer-Performance-Book-Wescott/dp/1482657759/ref=sr_1_1?keywords=every+computer+performance+book&qid=1573175055&sr=8-1).
