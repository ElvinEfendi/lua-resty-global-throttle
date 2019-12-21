[![Build Status](https://travis-ci.com/ElvinEfendi/lua-resty-global-throttle.svg?branch=master)](https://travis-ci.com/ElvinEfendi/lua-resty-global-throttle)

# lua-resty-global-throttle

A general throttle implementation for Openresty. It can be used to throttle any action let it be a request or a function call.
Currently only approximate sliding window rate limiting is implemented.

First require the module:

```
local global_throttle = require "resty.global_throttle"
```

After that you can create an instance of throttle like following where 100 is the limit that will be enforced per 2 seconds window. The third parameter tells the throttler what store provider it should use to
store its internal statistics.

```
local my_throttle, err = global_throttle.new(100, 2,  { provider = "shared_dict", name = "counters" })
```

Finally you call following everytime before whatever it is you're throttling:

```
local should_throttle, err = my_throttle:process("identifier of whatever it is your are throttling")
```


### Test

There are integration and unit test suits. Integration tests are in folder `t` while unit tests are in `spec`.
In order to run tests, first build the Docker image using `make image` and then
use `make test` for integration and `make spec` for running unit tests.

### Contributions and Development

The library is designed to be extendable. Currently only approximate sliding window algorithm is implemented in `lib/resty/global_throttle/sliding_window.lua`. It can be used as a reference point to implement other algorithms.

Storage providers are implemented in `lib/resty/global_throttle/store/`.

### TODO

 - [ ] Integrate Travis CI
 - [ ] Implement another store based on https://github.com/openresty/lua-resty-lrucache
 - [ ] Support Sliding Window algorithm (where bursts are allowed)
 - [ ] Implement Leaky Bucket
 - [ ] Provide an example use case for every implementation
 - [ ] Redis store provider

### References

- Cloudflare's blog post on approximate sliding window: https://blog.cloudflare.com/counting-things-a-lot-of-different-things/