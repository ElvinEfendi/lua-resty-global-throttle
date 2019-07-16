local string_format = string.format

-- providers are lazily loaded based on given options.
-- every store provider should implement `:incr(key, delta, expiry)` that returns new value and an error
-- and `:get(key)` that returns value corresponding to given `ket` and an error if there's any.
local providers = {}

local _M = {}

function _M.new(options)
  if not options then
    return nil, "'options' param is missing"
  end

  if not options.provider then
    return nil, "'provider' attribute is missing"
  end

  if not providers[options.provider] then
    local provider_implementation_path = string_format("resty.global_throttle.store.%s", options.provider)
    local provider_implementation = require(provider_implementation_path)

    if not provider_implementation then
      return nil, string_format("given 'store' implementation was not found in: '%s'", provider_implementation_path)
    end

    providers[options.provider] = provider_implementation
  end

  local provider_implementation_instance, err = providers[options.provider].new(options)
  if not provider_implementation_instance then
    return nil, err
  end

  return provider_implementation_instance, nil
end

return _M
