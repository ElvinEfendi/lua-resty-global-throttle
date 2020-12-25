# lua-resty-global-throttle

[![Build Status](https://github.com/ElvinEfendi/lua-resty-global-throttle/workflows/CI/badge.svg?branch=main)](https://github.com/ElvinEfendi/lua-resty-global-throttle/actions?query=workflow%3ACI)

### Installation

```
luarocks install lua-resty-global-throttle
```

### Usage

A generic, distributed throttling implementation for Openresty. It can be used to throttle any action let it be a request or a function call.
Currently only approximate sliding window rate limiting is implemented.

First require the module:

```
local global_throttle = require "resty.global_throttle"
```

After that you can create an instance of throttle like following where 100 is the limit that will be enforced per 2 seconds window.
The third parameter tells the throttler what store provider it should use to store its internal statistics.

```
local memc_host = os.getenv("MEMCACHED_HOST")
local memc_port = os.getenv("MEMCACHED_PORT")

...

local my_throttle, err = global_throttle.new(namespace, 10, 2, {
  provider = "memcached",
  host = memc_host,
  port = memc_port,
  connect_timeout = 15,
  max_idle_timeout = 10000,
  pool_size = 100,
})
```

Finally you call following everytime before whatever it is you're throttling:

```
local estimated_final_count, desired_delay, err = my_throttle:process("identifier of whatever it is your are throttling")
```

When `desired_delay` exists, it means the limit is exceeding and client should be throttled for `desired_delay` seconds.

For more complete understanding of how to use this library, refer to `examples` directory.

### Production considerations

1. Ensure you configure the connection pool size properly. Basically if your store (i.e memcached) can handle `n` concurrent connections and your NGINX has `m` workers,
then the connection pool size should be configured as `n/m`. That is because the configured pool size is per NGINX worker.
For example, if your store usually handles 1000 concurrent requests and you have 10 NGINX workers,
then the connection pool size should be 100. Similarly if you have `p` different NGINX instances, then connection pool size should be `n/m/p`.
2. Be careful when caching decisions based on `desired_delay`, sometimes it is too small that your cache can interpret it as 0 and cache indefinitely.
Also caching for very little time probably does not add any benefit.

### Contributions and Development

The library is designed to be extendable. Currently only approximate sliding window algorithm is implemented in `lib/resty/global_throttle/sliding_window.lua`. It can be used as a reference point to implement other algorithms.

Storage providers are implemented in `lib/resty/global_throttle/store/`.

### TODO

 - [ ] Redis store provider
 - [ ] Support Sliding Window algorithm (where bursts are allowed)
 - [ ] Implement Leaky Bucket

### References

- Cloudflare's blog post on approximate sliding window: https://blog.cloudflare.com/counting-things-a-lot-of-different-things/
