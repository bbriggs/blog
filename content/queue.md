---
title: Queue
slug: queue
---

Posts, talks, or essays planned. No particular order.

## Google Doc Backlog
### Why to use python virtualenvs
### My journey into immutable infra
### Building with ansible and packer 
   - Deploying on DigitalOcean
   - Managing changes
   - Drawbacks
### Oh god kubernetes!
 - This could be a book. Or a therapy session.
### Building a storage API for Legobot
 - Motivation: needed state
 - Legobot philosophy: universal APIs
 - Design problems: REST and CRUD interfaces
 - Problems: Masking unique features of certain storage backends
### Zero to consul and consul-template with Legobot
### Bang commands?
### “Ops for hackers”
 - C&C clusters
 - Bitcoin 101 
 - Opsec for bitcoin
  - Mixers and tumblers
  - Payment systems
  - Hot and cold wallets
  - Deanonymizing users
  - Tracking tools
### Building a quick-deploy hackbox with Packer and CoreOS
  - superseded by [axiom](https://github.com/pry0cc/axiom)
## Hackathon Series
### ~Why bother~
 - What can you actually, meaningfully accomplish in 24 hours?
### Moving the Needle
 - A practical look at what "moving the needle" looks like and means
   - Hackathons build communities, not products

### The sprint and the marathon
- A look at the role of the hackathon in the lifecycle of a product
    - Products born from hackathons
        - Many die from lack of investment (time _and_ money)
        - Many die from lack of leadership
- Products augmented by hackathons
    - Many are not ready for the sprint that hackathons bring
    - Hackathons often create more problems than they solve
    - It takes time to get contributors used to your products
### Building communities
- As a followup to "moving the needle", a look at what goes into a community
    - Communities happen on purpose
    - Communities must be welcoming and inclusive
    - Communities must offer value to participants
    - Points (ii) and (iii) can override one another if strong enough. this is not desirable.
### You should not host a hackathon
- Why and why not to host a hackathon

## Other Essays
### Update to Hacker Ethos (2020)
### DevOps Archaeology
- What to do when you inherit an undocumented infrastructure
### Facebook, dead trees, and ephemerality
Trees evolved before organisms who specialized in breaking them down, so for millions of years, we had piles of dead trees everywhere. They were recycled and cleaned up through massive conflagrations which wiped out whole areas rather than building a sustainable ecosystem and returning nutrients to the soil.

In the same way, our development and adoption of social media outpaced our notion of ephemerality. So much content we have created will be around forever because we simply didn’t consider the consequences of systems that didn’t clean up or age out old content. Do your facebook statuses about going to the beach or eating a sandwich need to live forever? Do you want those idiotic things you said as a teenager lingering for the rest of that platform’s life, waiting to surprise you decades later?

Ephemerality is quickly becoming a core feature of products today, and some existing products are adopting the concept. This essay explores the need for ephemerality as well as the benefits and dangers of a history that cleans up after itself. This talk is about being forgotten, for better or worse.
### The Best Year I Ever Regretted: My intro to eng management
The "red wedding" at COTA.

### The Dwight Schrute Guide to Threat Models
virtually all of Dwight Schrute‘s behavior can be explained through poor threat modeling. he is zealous about security but a poor threat modeler, so he ends up over fitting for some imaginary problem and misses the obvious one that ends up literally smacking him in the face (Jim, over and over).
### Umwelt and DevOps
Umwelt - (in ethology) the world as it is experienced by a particular organism.

As applied to organizations, the idea that different specialists working on the same project or even team can have radically different experiences of the world based on their specialties, past experience, and current role

Quick example: a DevOps engineer, web dev, and a data scientist all working on the same project will have very different views of the same stack. To the ops engineer, she will have a large, detailed, and nuanced view of the infrastructure that supports the apps, the deployment models, the failure modes, and the data is just “data” and the web stack are just a handful of processes running on her infrastructure.

## Staged in git
### Communicating your limits, part 1: technical reality
### Communicating your limits, part 2: personal limitations
### DevOps in a day
If I only had one working day with someone to pass on the most important principles of DevOps, what would I say?
### First Wave DevOps
When did it stop becoming a culture and start becoming "just a sysadmin"?
### Defenders Paradox: SecOps edition
### Visualizing chat data with Prometheus and Grafana

## The Whiteboard Ideas
Mostly problems I want to solve for myself
### Effective onboarding through automation and culture
### Dependency injection for Flux and Terraform
### CIS benchmarking TF and EKS
### IAM management via Service Control Policies
### Software Supply Chain concerns, gaps, tooling landscape
### Productive chatops
- What makes chatops successful and adopted in an organization? Should you even pursue it?
- What is the difference between "chatops" and having some push notifications in a channel?
