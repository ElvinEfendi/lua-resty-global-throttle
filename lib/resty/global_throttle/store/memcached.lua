local memcached = require "resty.memcached"

local string_format = string.format

local _M = {}
local mt = { __index = _M }

function _M.new(options)
  local memc, err = memcached:new()
  if not memc then
    return nil, string_format("failed to instantiate memcached: %s", err)
  end

  if options.connect_timeout and options.connect_timeout > 0 then
    local ok
    ok, err = memc:set_timeout(options.connect_timeout)
    if not ok then
      return nil, string_format("error setting connect timeout: %s", err)
    end
  end

  local ok
  ok, err = memc:connect(options.host, options.port)
  if not ok then
    return nil, string_format("failed to connect: %s", err)
  end

  return setmetatable({
    memc = memc,
  }, mt), nil
end

function _M.incr(self, key, delta, expiry)
  local new_value, err = self.memc:incr(key, delta)
  if err then
    if err ~= "NOT_FOUND" then
      return nil, err
    end
    
    local ok
    ok, err = self.memc:add(key, delta, expiry)
    if not ok then
      return nil, err
    end
    new_value = delta
  end

  return new_value, nil
end

function _M.get(self, key)
  local value, flags, err = self.memc:get(key)
  if err then
    return nil, err
  end
  if value == nil and flags == nil and err == nil then
    return nil, "not found"
  end
  return value, nil
end

function _M.__flush_all(self)
  return self.memc:flush_all()
end

return _M
