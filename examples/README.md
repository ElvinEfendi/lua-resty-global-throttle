# Instructions

In the root directory of the library where `docker-compose.yaml` is run:

```
docker-compose build
```

then:

```
docker-compose up
```

After this you should be able to `curl` `localhost:8080` and get successful response back:

```
> lua-resty-global-throttle (master)$ curl localhost:8080
ok
```

The server has `lua-resty-global-throttle` configured and it will start responding with
HTTP status code 429 when limit is exceeded. Server will use the latest code, which means
you can change code and test quickly using this server.
When you change the code or configuration make sure you run `make reload-proxy`
so the NGINX picks the latest configuration and Lua code.

You can use `hey` (or any other load generator) to test throttling:

```
> lua-resty-global-throttle (main)$ hey -c 2 -q 100 -z 6s http://localhost:8080/memc?key=client

Summary:
  Total:	6.0077 secs
  Slowest:	0.0415 secs
  Fastest:	0.0015 secs
  Average:	0.0035 secs
  Requests/sec:	198.9098

  Total data:	202825 bytes
  Size/request:	169 bytes

Response time histogram:
  0.002 [1]	|
  0.006 [1110]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.010 [75]	|■■■
  0.014 [6]	|
  0.018 [1]	|
  0.022 [0]	|
  0.026 [0]	|
  0.030 [0]	|
  0.033 [0]	|
  0.037 [0]	|
  0.041 [2]	|


Latency distribution:
  10% in 0.0020 secs
  25% in 0.0024 secs
  50% in 0.0033 secs
  75% in 0.0041 secs
  90% in 0.0051 secs
  95% in 0.0060 secs
  99% in 0.0095 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0000 secs, 0.0015 secs, 0.0415 secs
  DNS-lookup:	0.0000 secs, 0.0000 secs, 0.0030 secs
  req write:	0.0000 secs, 0.0000 secs, 0.0005 secs
  resp wait:	0.0034 secs, 0.0015 secs, 0.0358 secs
  resp read:	0.0000 secs, 0.0000 secs, 0.0011 secs

Status code distribution:
  [200]	36 responses
  [429]	1159 responses
```
