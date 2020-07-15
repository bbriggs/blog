---
title: "Bootstrapping FluxCD with Terraform"
date: 2020-07-08T23:50:00-04:00
draft: false

tags:
 - tech
 - ops
 - kubernetes
 - terraform
---

Quickly get your Kubernetes cluster going with Terraform and FluxCD. The one catch here is you _will_ have to provide an SSH to the helm provider. Instructions provided below.

## Terraform

```
// k8s.tf
// Assumes a working terraform environment for Digital Ocean already

provider "kubernetes" {
  load_config_file = false
  host             = digitalocean_kubernetes_cluster.example.endpoint
  token            = digitalocean_kubernetes_cluster.example.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.example.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host             = digitalocean_kubernetes_cluster.example.endpoint
    token            = digitalocean_kubernetes_cluster.example.kube_config[0].token
    load_config_file = false

    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.example.kube_config[0].cluster_ca_certificate)
    client_key             = digitalocean_kubernetes_cluster.example.kube_config[0].client_key
    client_certificate     = digitalocean_kubernetes_cluster.example.kube_config[0].client_certificate
  }
}

resource "digitalocean_kubernetes_cluster" "example" {
  name   = "example"
  region = "nyc1"
  # Grab the latest version slug from `doctl kubernetes options versions`
  version = "1.17.5-do.0"

  node_pool {
    name       = "example-worker-pool"
    size       = "s-1vcpu-2gb"
    node_count = 3
  }
}

resource "helm_release" "flux" {
  name             = "flux"
  repository       = "https://charts.fluxcd.io"
  chart            = "flux"
  namespace        = "flux"
  create_namespace = true

  set {
    name  = "git.url"
    value = var.flux_git_url
  }

  set {
    name  = "git.pollInterval"
    value = "20m"
  }

  set {
    name  = "git.user"
    value = "flux"
  }

  set {
    name  = "git.email"
    value = "flux@localhost"
  }

  set {
    name  = "git.ciSkip"
    value = "true"
  }

  set {
    name  = "syncGarbageCollection.enabled"
    value = "true"
  }

}

resource "helm_release" "flux_helm_operator" {
  name             = "flux-helm-operator"
  repository       = "https://charts.fluxcd.io"
  chart            = "helm-operator"
  namespace        = "flux"
  create_namespace = true

  set {
    name  = "git.ssh.secretName"
    value = "helm-ssh"
  }

  set {
    name  = "helm.versions"
    value = "v3"
  }

  set {
    name  = "git.timeout"
    value = "2m"
  }

  set {
    name  = "git.pollInterval"
    value = "2m"
  }

}

// For some reason, Flux didn't want to install cert-manager correctly so I did this via helm provider
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "global.rbac.create"
    value = "true"
  }

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "cainjector.image.tag"
    value = "v0.15.1"
  }

  set {
    name  = "webhook.image.tag"
    value = "v0.15.1"
  }
}
```

### Get your SSH public key from Flux
First, set your flux namespace as an env var. I tend to leave mine in my `~/.bashrc`

```
export FLUX_FORWARD_NAMESPACE=flux
```

Flux generates an SSH key pair for you once it deploys. After [installing fluxctl](https://docs.fluxcd.io/en/1.18.0/references/fluxctl.html), use `fluxctl identity` to get the public key and add it to your git repo as a deploy key. If you want flux to be able to automate updating images and commit them to git, give it write access as well.

### Add an SSH key to the Flux Helm Operator
I stumbled over this for a while. If you want to pull helm charts from private repos, you have to give it an SSH key. It doesn't magically know what the SSH key is that the Flux operator uses. If you're on github and your charts repo is separate from your flux repo, you also cannot add the same deploy key to two separate repos. In any event, it's best to have two separate keys. 

Generate an SSH key.
```
ssh-keygen -t rsa -b 4096 -f flux
```

Then create your secret in the flux namespace

```
kubectl create secret generic helm-ssh --from-file=identity=./flux
```

And don't forget to add the public half of this key pair to your private helm repo. At this point, both the flux and flux helm operators should be able to access their respective repos. Save that keypair to your password manager and clean up your artifacts. Congratulations, you should now be ready to use flux!
