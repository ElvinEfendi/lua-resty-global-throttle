package = "lua-resty-global-throttle"
version = "0.2.0-1"
source = {
   url = "git://github.com/ElvinEfendi/lua-resty-global-throttle",
   tag = "v0.2.0"
}
description = {
   summary = "Distributed flow control middleware for Openresty.",
   detailed = [[
      A generic, distributed throttle implementation for Openresty with memcached storage support among others.
      It can be used to throttle any action let it be a request or a function call.
   ]],
   homepage = "https://github.com/ElvinEfendi/lua-resty-global-throttle",
   license = "MIT"
}
build = {
  type    = "builtin",
  modules = {
    ["resty.global_throttle.store.memcached"] = "lib/resty/global_throttle/store/memcached.lua",
    ["resty.global_throttle.store.shared_dict"] = "lib/resty/global_throttle/store/shared_dict.lua",
    ["resty.global_throttle.store"] = "lib/resty/global_throttle/store.lua",
    ["resty.global_throttle.sliding_window"] = "lib/resty/global_throttle/sliding_window.lua",
    ["resty.global_throttle"] = "lib/resty/global_throttle.lua"
  }
}
