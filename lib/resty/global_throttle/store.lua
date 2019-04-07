local memcached_store = require "resty.global_throttle.store.memcached"
local shared_dict_store = require "resty.global_throttle.store.shared_dict"

local _M = {}
local mt = { __index = _M }

function _M.new(options)
  if not options then
    return nil, "options param is mandatory"
  end

  if options.provider == "memcached" then
    return memcached_store.new(options)
  end

  if options.provider == "shared_dict" then
    return shared_dict_store.new(options)
  end

  return nil, "only memcached is supported"
end

return _M
