package = "lua-resty-global-throttle"
version = "0.1.0-1"
source = {
   url = "git://github.com/ElvinEfendi/lua-resty-global-throttle",
   tag = "v0.1.0"
}
description = {
   summary = "General purpose flow control with shared storage support.",
   detailed = [[
      A general throttle implementation for Openresty with shared storage support among others.
      It can be used to throttle any action let it be a request or a function call.

      Currently memcached and Lua shared dictionary are supported.
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