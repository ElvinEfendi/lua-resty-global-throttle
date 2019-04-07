local memcached = require "resty.memcached"

local _M = {}
local mt = { __index = _M }

function _M.new(options)
  local memc, err = memcached:new()
  if not memc then
    return nil, string_format("failed to instantiate memcached: %s", err)
  end

  if options.connect_timeout and options.connect_timeout > 0 then
    local ok, err = memc:set_timeout(options.connect_timeout)
    if not ok then
      return nil, string_format("error setting connect timeout: %s", err)
    end
  end

  local ok, err = memc:connect(options.host, options.port)
  if not ok then
    return nil, string_format("failed to connect: %s", err)
  end

  return setmetatable({
    memc = memc,
  }, mt), nil
end

function _M.incr(self, key, delta, expiry)
  local new_value, err = memc:incr(key, delta)
  if err then
    return nil, err
  end

  if new_value == delta then
    -- the key just got added, set its expiry
    local ok, err = memc:touch(key, expiry)
    if not err then
      return nil, err
    end
  end

  return new_value, nil
end

function _M.get(self, key)
  local value, flags, err = memc:get(key)
  if err then
    return nil, err
  end
  if value == nil and flags == nil and err == nil then
    return nil, "not found"
  end
  return value, nil
end

return _M
