---
title: "Lifecycle Bugs with Terraform and EC2 instances"
date: 2020-07-08T21:30:46-04:00
draft: true

tags:
 - tech
 - ops
 - aws
 - terraform
---

You wake up, get coffee, mill around the house for a bit and then head to the computer. Rubbing the sleep from your eyes, you open up Slack and your editor to catch up on where you were the day before. Then you get a message. "Hey man, I can't get into the server you made yesterday. Can you look?"

"No problem."

"Thanks."

You look and, strangely, none of the configuration you applied with ansible is there. You shrug it off as a fluke and move on. An hour later, another developer says the same thing about another instance you deployed and configured the day before. Weird, but maybe they both got skipped since they were both built around the same time.

You get them back in, they resume their work, and everyone proceeds about their day as usual.

The next day, you wake up, get coffee, mill around the house for a bit and then head to the computer. 

"Hey, can you look at that machine again? I can't get in."

"You're kidding, right? We just fixed this."

"No, I swear."

Sure enough, it's blank again. Same IP as before, same inital SSH key. Ansible puts everything back to baseline but all the work in progress is gone. Two machines, twce in two days. What happened?

## Investigation

We were deploying these machines with Terraform, so I started looking there. I combed through logs of previous TF runs and sure enough, the previous morning I saw where a TF run triggered a rebuild. Because we were working out some networking issues with forwarding through a bastion, we enabled ephemeral public IPs for these instances and deployed them with the [EC2 instance module](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/2.15.0), setting `associate_public_ip_address` to `true`. However, AWS was reporting this parameter was `false` at the time of the TF run and tried to set it back to `true`, resulting in the resource being replaced. But why was it false to begin with? What was changing the value? Nobody except for me and the Terraform service account had permission to edit the machine except for the developers who could start and stop it.

And there was the first real clue. These were fairly large instances (p2.xlarge) used to ML model training, and expensive to run by the hour so the devs were encouraged to turn them off when not actively being used. The only thing that changed was whether or not they were running, so I had to assume that something there was causing it. Lo and behold, I discoverd that turning off the machine caused AWS to update the `associate_public_ip_address` property in the API to `false`. In a way, that makes sense because stopped machines don't need to retain their ephemeral public IP. Terraform saw this a little differently, however. Because Terraform is a [declarative](https://en.wikipedia.org/wiki/Declarative_programming) language, it takes the desired state you give it (the code) and compares it to reality and makes reality match the desired state. So when it saw that `associate_public_ip_address` was false, it tried to make it `true`. The way it tried to do this was to rebuild the whole EC2 instance rather than the sane action of changing the power state, most likely because it saw "rebuild" as the more direct route to achieve this action.

## Fixes

Normally, you can instruct Terraform to [ignore changes](https://www.terraform.io/docs/configuration/resources.html#lifecycle-lifecycle-customizations) to certain parameters or properties, like so

```
resource "aws_instance" "example" {
  # ...

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      tags,
    ]
  }
  }
```

Unfortunately, we are using a module here and the `lifecycle` block is not available as a meta-parameter as of `0.12.x`. The ideal way to fix this would be to allow `lifecycle` in module blocks to ignore changes, but in the meantime this probably requires a patch to the module itself to allow you specify parameters changes that can be ignored (like they already do with attached EBS volumes).

Other fixes would be to not associate a public IP at all and stritly use bastion servers or to attach an EIP to the instance and connect that way. Each have their advantages and the bastion route is probably generally better than an ephemeral public IP like we were doing as a workaround.

Let this be a warning that when expediency trumps safety, it can bite you in unexpected ways.
