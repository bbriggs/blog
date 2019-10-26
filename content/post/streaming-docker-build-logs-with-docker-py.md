---
title: "Streaming Docker Build Logs With Docker Py"
date: 2018-04-26T12:03:12-04:00
categories:
  - tech
tags:
  - docker
  - python
  - ops

---

We've been building docker images and pushing them to custom repos using CircleCI and some other build tools. Recently we had a container build fail, but in one of the worst ways: it just hung. Forever. Hours, actually. What the heck was it doing? It built just fine locally! We needed log output.

Our build function looked something like this (using the "high-level" API):

```python
    def build(self, repository, tag, path=".", cache_from=[""], build_args="", dockerfile=""):
        args={"path": path, "tag": "{}:{}".format(repository, tag)}
        if cache_from != [""]:
            args.update({'cache_from': cache_from})
        if build_args != "":
            args.update({'buildargs': build_args})
        if dockerfile != "":
            args.update({'dockerfile': dockerfile})

        response = self.client.images.build(**args)
        print("*** BUILD OUTPUT:")
        for object in response[1]:
            print(object)
```

That should tell us what happened, right? Nope. 

If you look at the source code to docker-py, the following line actually waits for the build to finish before sending output:

```
response = self.client.images.build(**args)
```

And here's the [source code](https://github.com/docker/docker-py/blob/master/docker/models/images.py#L258-L277) for that call to `client.images.build()` in docker-py:

```python
    def build(self, **kwargs):
    '''
    a long docstring
    '''
        resp = self.client.api.build(**kwargs)
        if isinstance(resp, six.string_types):
            return self.get(resp)
        last_event = None
        image_id = None
        result_stream, internal_stream = itertools.tee(json_stream(resp))
        for chunk in internal_stream:
            if 'error' in chunk:
                raise BuildError(chunk['error'], result_stream)
            if 'stream' in chunk:
                match = re.search(
                    r'(^Successfully built |sha256:)([0-9a-f]+)$',
                    chunk['stream']
                )
                if match:
                    image_id = match.group(2)
            last_event = chunk
        if image_id:
            return (self.get(image_id), result_stream)
        raise BuildError(last_event or 'Unknown', result_stream)
```

See how it calls `client.api.build()`? That's a call out to the low-level version of the API. Let's dig into that now. We actually don't need to get all the way into the source for this. A peek at [the docs for this method](https://docker-py.readthedocs.io/en/stable/api.html#module-docker.api.build) tells us what we need to know:
> Returns:	
> A generator for the build output.

K then. Now what? Well, it turns out we can stream logs from the build by calling the low-level API and then iterating over the response. Generators, what can't they do?

Note that we initialize both a low-level and a high-level API client for this.

```python
import logging
import docker
import os
from docker import APIClient


logger = logging.getLogger(__name__)

class Docker():
    def __init__(self, token=None, registry=None):

        cert_path = os.environ['DOCKER_CERT_PATH'].replace('tcp://', 'https://')
        tls = docker.tls.TLSConfig(
                client_cert=(os.path.join(cert_path, 'cert.pem'),
                            os.path.join(cert_path, 'key.pem')),
                ca_cert=os.path.join(cert_path, 'ca.pem'),
                verify=True,
                ssl_version="PROTOCOL_TLSv1_2",
                assert_hostname=False,
        )

        self.client = docker.from_env()
        self.cli = APIClient(base_url=os.environ['DOCKER_HOST'], tls=tls)
        if token and registry:
            self.client.login("oauth2accesstoken", token, "", registry)
            self.cli.login("oauth2accesstoken", token, "", registry)

    # Build the container!
    def build(self, repository, tag, path=".", cache_from=[""], build_args="", dockerfile=""):
        args={"path": path, "tag": "{}:{}".format(repository, tag)}
        if cache_from != [""]:
            args.update({'cache_from': cache_from})
        if build_args != "":
            d = {build_args.split('=',1)[0]: build_args.split('=',1)[1]}
            args.update({'buildargs': d})
        if dockerfile != "":
            args.update({'dockerfile': dockerfile})

        logger.debug("*** BUILD OUTPUT:")
        for line in self.cli.build(**args):
          logger.info(line)
```

So using this new setup, we can use the high level API to do the easy and simple stuff, and the the low-level API to get access to build logs in real time and stream them to the logger. 

If this helped you out or if you have questions or improvements, feel free to Tweet me. Happy hacking!


---


