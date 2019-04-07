local string_format = string.format

-- providers are lazily loaded based on given options.
-- every store provider should implement `:incr(key, delta, expiry)` that returns new value and an error
-- and `:get(key)` that returns value corresponding to given `ket` and an error if there's any.
local providers = {}

local _M = {}
local mt = { __index = _M }

function _M.new(options)
  if not options then
    return nil, "options param is mandatory"
  end

  if not options.provider then
    options.provider = "shared_dict"
  end

  if not providers[options.provider] then
    providers[options.provider] = require(string_format("resty.global_throttle.store.%s", options.provider))
  end

  return providers[options.provider].new(options), nil
end

return _M
