# Development instructions

### Build dev server

```
make dev
```

### Start dev server

```
make dev-run
```

After this you will should be able to `curl` `localhost:8080` and get successful response back:

```
> lua-resty-global-throttle (master)$ curl localhost:8080
Halo!
```

The dev server has lua-resty-global-throttle configured and it will start responding with
HTTP status code 429 when limit is exceeded. Dev server will use the latest code, which means
you can change code and test quickly using this server.
You can use `hey` (or any other load generator) to cause throttling:

```
> lua-resty-global-throttle (master)$ hey -c 1 -q 51 -z 4s http://localhost:8080

Summary:
  Total:	4.0069 secs
  Slowest:	0.0880 secs
  Fastest:	0.0012 secs
  Average:	0.0042 secs
  Requests/sec:	50.1632

  Total data:	525 bytes
  Size/request:	2 bytes

Response time histogram:
  0.001 [1]	|
  0.010 [192]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.019 [4]	|■
  0.027 [3]	|■
  0.036 [0]	|
  0.045 [0]	|
  0.053 [0]	|
  0.062 [0]	|
  0.071 [0]	|
  0.079 [0]	|
  0.088 [1]	|


Latency distribution:
  10% in 0.0019 secs
  25% in 0.0022 secs
  50% in 0.0029 secs
  75% in 0.0044 secs
  90% in 0.0066 secs
  95% in 0.0092 secs
  99% in 0.0252 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0001 secs, 0.0012 secs, 0.0880 secs
  DNS-lookup:	0.0000 secs, 0.0000 secs, 0.0066 secs
  req write:	0.0000 secs, 0.0000 secs, 0.0005 secs
  resp wait:	0.0039 secs, 0.0011 secs, 0.0878 secs
  resp read:	0.0001 secs, 0.0000 secs, 0.0014 secs

Status code distribution:
  [200]	198 responses
  [429]	3 responses
```

Nginx configuration can be customized in `dev/nginx.conf`.
