---
title:  "Exposing local services to Minikube using SSH"
date: 2017-06-21T12:14:54-04:00

categories:
  - tech
tags:
  - kubernetes
  - ops
  - linux
  - networking

---

_Edit: Looks like I lost some image assets when I migrated over and broke the links. Sorry! Let this be a lesson about rebasing._

We already know we can port forward to reach services in Minikube, but what abot the other way around? What if a pod needs an external service on your laptop? There's a [pure Kubernetes way of doing it](https://stackoverflow.com/questions/43530039/on-a-mac-what-ip-will-represent-my-laptop-from-within-a-minikube-cluster/43530279?noredirect=1#comment74114215_43530279), but this is more of an interesting SSH trick that exposes how Kubernetes and Minikube work. Plus, it's always fun to do tricks with SSH.

### The setup

Consider the following diagram:

![SSH forwarding 1]({{ site.url }}{{ site.baseurl }}/assets/images/vault-diagram-1.png)

Vault is only accessible via the Elastic Load Balancer, which itself is only accessible to select security groups within our VPC. In order to issue Vault commands from my laptop, I have to use SSH local port forwarding. This sets up a tunnel over SSH that allows me to connect _through_ my SSH destination (Bastion in this case) which can connect to Vault.

This is what the local forward looks like in my `~/.ssh/config`:

```
Host Bastion
  Hostname mybastion.mysite.org
  LocalForward 55555 vault.mysite.org:443
  ControlMaster auto
```

And just connecting to the server sets up the forwarder: `ssh Bastion`

However, we have a problem: Minikube needs to connect to Vault as well but is on an isolated network on my laptop. How do I expose Vault to Kubernetes inside this onion of networks? Let's do it the hard way.

### The Solution

Answer: MORE SSH!

Since I've already forwarded the connection from somewhere off in Internetland, as far as Minikube is concerned, Vault may as well be living locally on my laptop at `127.0.0.1:8200`. This works well for us, since the next step is just to cross that last gap between local laptop and kubernetes pod. After doing lots of digging around on Minikube port forwarding, I was disappointed that I couldn't find much in the way of Github issues, StackOverflow questions, blog posts, etc. on Minikube reaching _out_. There was plenty on forwarding _in_ to services on Minikube, however. Finally, I remembered that this SSH thing can go both ways: If I can forward my connection out to a destination, I can also invite a destination to connect inbound to me. In SSH parlance, that's called a "remote forward."

The idea was to make one giant SSH pipeline: A remote forward from my laptop to the Minikube VM would allow connections from the pods to the forwarded port on Minikube VM to reach my laptop. Since my laptop is already forwarding the port all the way over to AWS, that would complete the SSH tunnel over multiple hops and allow pods on Minikube to reach Vault as though it was local.


![SSH forwarding 2]({{ site.url }}{{ site.baseurl }}/assets/images/vault-diagram-2.png)

Spoiler alert: It didn't work right away.

The normal syntax for an SSH remote forward looks like this: `ssh -R remoteport:localaddress:localport host`. 

An actual example: `ssh -R 9999:127.0.0.1:8200 myserver` would open a connection on port 9999 on the remote host, forwarding any traffic they send it to `127.0.0.1:8200` on your local machine. I'll stop for a second to allow you to imagine the really dangerous possibilities of a tool like SSH. Better yet, go read these awesome blog posts on the topic:

[How to lose your job with SSH, part 1](https://blather.michaelwlucas.com/archives/945)

[How to lose your job with SSH, part 2](https://blather.michaelwlucas.com/archives/959)

Back? Was that cool or what? Let's move on...

So we're going to forward some port on Minikube VM over to our already-forwarded Vault connection. First, let's figure out what the Minikube IP is:  `minikube ip`

Okay, that was easy. How do we get in now? A lucky google search turned up this SSH string, actually: `ssh -i ~/.minikube/machines/minikube/id_rsa docker@$(minikube ip)` which Aaron Prindle (aprindle on the Kubernetes Slack) helpfully shortened to `ssh -i $(minikube ssh-key) docker@$(minikube ip)`. That gets us into the Minikube container, but how do we forward the connection back out?

We start with this (bear in mind that vault is forwarded to `127.0.0.1:55555` on my laptop):

```
ssh -i $(minikube ssh-key) docker@$(minikube ip) -R 8200:127.0.0.1:55555
```

By default this will only bind to localhost on the remote machine, so we need to expand it a bit:

```
ssh -i $(minikube ssh-key) docker@$(minikube ip) -R 10.0.2.15:8200:127.0.0.1:55555
```

Here I have told SSH to bind to the eth0 interface of the minikube machine instead of localhost. Did it work?

```
$ ssh -i ~/.minikube/machines/minikube/id_rsa docker@$(minikube ip) -R 10.0.2.15:8200:localhost:55555
$ netstat -ant | grep 8200
tcp        0      0 127.0.0.1:8200          0.0.0.0:*               LISTEN
tcp        0      0 ::1:8200                :::*                    LISTEN
```

That's a solid "no". For some reason, even when explicitly told to use an IP other than localhost, it binds to localhost anyways. Turns out there was an issue opened on this: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=228064 and the answer was to update `/etc/ssh/sshd_config` to have the following line: 

```
GatewayPorts yes
```

This apparently allows remote forwarding to bind to interfaces other than localhost.

Now restart the ssh service:

```
sudo systemctl restart sshd
```

And reconnect:

```
ssh -i $(minikube ssh-key) docker@$(minikube ip) -R 8200:localhost:55555
```

Now observe our listening interfaces:

```
$ netstat -ant | grep 8200
tcp        0      0 0.0.0.0:8200            0.0.0.0:*               LISTEN
tcp        0      0 :::8200                 :::*                    LISTEN
```

We are listening on all interfaces, ready to forward!

Now in any of your services, you can reach out to the minikube IP on port 8200 to forward your traffic!

Here's what our service file looks like now:

```
# kubernetes-vault.yaml

apiVersion: v1
kind: Service
metadata:
  name: kubernetes-vault
  labels:
    run: kubernetes-vault
spec:
  clusterIP: None
  selector:
    run: kubernetes-vault
  # Kubernetes-Vault does not need to expose any ports through a headless service.
  # However, there's a Kubernetes bug where the pods won't be registered in the API,
  # so we need to use this hack. See kubernetes/kubernetes#32796
  ports:
    - name: port
      port: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubernetes-vault
data:
  kubernetes-vault.yml: |-
    vault:
      addr: http://10.0.2.15:8200  # Notice the IP address?
      token: aaaa-bbbb-cccc

    kubernetes:
      watchNamespace: ${KUBERNETES_NAMESPACE}
      serviceNamespace: ${KUBERNETES_NAMESPACE}
      service: kubernetes-vault

    prometheus:
      tls:
        vaultCertBackend: intermediate-ca
        vaultCertRole: kubernetes-vault
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kubernetes-vault
spec:
  replicas: 3
  template:
    metadata:
      labels:
        run: kubernetes-vault
    spec:
      containers:
      - name: kubernetes-vault
        image: boostport/kubernetes-vault
        env:
        - name: KUBERNETES_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: config-volume
          mountPath: /kubernetes-vault
      volumes:
        - name: config-volume
          configMap:
            name: kubernetes-vault
```

