---
title: "Abstraction and Juvenoia 1"
date: 2018-03-07T12:07:22-04:00

categories:
  - tech
tags:
  - opinion

---

_This is part 1 of a 3 part series._

## Introduction

This is most definitely a "kids these days" type of piece, but not the one you've probably already read so many times over. Instead of leaning back in my rocking chair, sucking on my corn cob pipe, and muttering about the good old days, I implore you the reader to walk with me on a short journey of reflection as I discuss a sentiment I hear often: That "our job", that is writing software and breaking into digital things, has gotten too easy. Kids are too soft. They don't know anything. I mean, I bet they don't even know how a compiler optimizes data structure alignment! How dare they call themselves programmers! When I was their age, I was practicing converting from hex to octal to decimal and back in my head while I walked 6 miles barefoot in the snow uphill both ways just to get to my PDP-11. 

Okay, that's a stretch, but not by much. There's definitely a "kids these days" sentiment I catch from folks, so let's talk about whether or not they're onto something. However, let's handle first things first. Let's talk about the thing I hear most as the culprit for "dumbing down" the work: that horrible beast, _Abstraction_.


## Abstraction

[Abstraction](https://en.wikipedia.org/wiki/Abstraction_(software_engineering)): A technique for arranging complexity of computer systems. It works by establishing a level of simplicity on which a person interacts with the system, suppressing the more complex details below the current level.

Anecdotally, the word _abstraction_ probably occurs more in Computer Science-related fields than anywhere else. Other career fields and majors may have their uses for the word and it may be part of the lexicon for them, but for us in CS it is _fundamental_. Our world is quite intentionally built on abstractions baked into all areas of computing. One excellent example is the elegant design of the _OSI Reference Model_ for networking stacks. Within the seven layers described, duties and tasks are neatly divided and organized. Modulation and demodulation of signals cleanly belongs to layer 1 whereas routing decisions to move from network to network live at layer 3. Devices that concern themselves with the statefulness of a conversation need not worry about how signals were interpreted from the wire. They were simply handed a message encoded in their preferred format (hopefully!). Herein lies the beauty of abstraction: it provides a separation of concerns within systems, allowing engineers and the protocols, interfaces, and algorithms they design to reap the vast benefits of having a tighter scope of concern, such as the philosophy of "Do one thing and do it well" that Unix and Perl espouse.

Consider a second example from the world of programming languages: without abstraction, programming and software development on the scale it currently exists would be impossible. Every representation of instructions today in a programming language is an abstraction of a lower-level structure, all the way down to the binary itself within the CPU. As languages pass through their interpreter or compiler, they are rendered into machine-code instructions that the particular CPU being used can understand. Even these instructions are themselves abstractions of actions within the CPU. The breakthrough of the C programming language was in being able to break this paradigm of programming for the CPU and programming in an "abstract" language instead, which would then be compiled for the particular machine it was destined to operate with. The same C program could look different depending on the machine's CPU!

Furthermore, modern configuration management languages are in my highly biased and completely untrustworthy opinion one of the most interesting places to observe abstraction, primarily because the layers they are abstracting are easy to see and the languages themselves have abstraction nailed into the very core of how they operate: they are designed to be extended, modified, and added onto in order to produce useful work with less input effort. For example, Puppet provides interfaces for adding new users to a server, adding their ssh public keys, adding users to groups, and other tasks involved with creating a new user. However, these are mostly separate modules and interfaces! If a user is to be implemented in the same way each time using the same resources, these should be combined and only the information that may change should be considered for input. Seeing this obvious need, many people wrote their own abstraction layer on top of a language that was already highly abstracted (see for example Rob Nelson's [puppet-local_user](https://github.com/rnelson0/puppet-local_user)). 

At each layer, abstraction then becomes a matter of interfaces: How does one represent and communicate with other objects? If this service or language is abstracting a deeper structure, how does one represent what it does in a meaningful way? That's an interface, and interfaces are critically important if an abstrction is to be useful.

Therefore, abstraction lets us focus on our work that matters, not on reimplementing the whole stack each time. When writing a little script in python to [start a server that serves malicious gifs](https://blog.fraq.io/tech/gif-javascript-polyglots/), I don't have to reimplement code that reads bits off the wire, interprets ethernet, de-encapsulates data at the network layer, tracks the TCP conversation, or learn and implement the whole HTTP protocol. Does that mean I know less about each step of the process then if I had done each part of it manually? Almost certainly. Do I need to know those things? Not in that level of detail. I was able to get right to the work that matters in a minimal amount of time and test out my idea without worrying about the vast amounts of underlying tech. 

Thanks to abstraction, we can focus on the work that matters, not on reinventing every wheel. And if you ask me, that's pretty cool.

----
