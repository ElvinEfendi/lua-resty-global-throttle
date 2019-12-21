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

Finally you call

```
should_throttle = my_throttle:process("identifier of whatever it is your are throttling")
```

everytime before whatever it is you're throttling.


### TODO

 - [ ] Integrate Travis CI
 - [ ] Implement another store based on https://github.com/openresty/lua-resty-lrucache
 - [ ] Test with memcached provider
 - [ ] Support Sliding Window algorithm (where bursts are allowed)
 - [ ] Implement Leaky Bucket
 - [ ] Provide an example use case for every implementation
 - [ ] Redis store provider
