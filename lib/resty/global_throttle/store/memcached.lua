local memcached = require("resty.memcached")

local string_format = string.format
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local setmetatable = setmetatable
local tonumber = tonumber

local _M = {}
local mt = { __index = _M }

function _M.new(options)
  if not options.host or not options.port then
    return nil, "'host' and 'port' options are required"
  end

  return setmetatable({
    options = options,
  }, mt), nil
end

local function with_client(self, action)
  local memc, err = memcached:new()
  if not memc then
    return nil, string_format("failed to instantiate memcached: %s", err)
  end

  if self.options.connect_timeout and self.options.connect_timeout > 0 then
    local ok
    ok, err = memc:set_timeout(self.options.connect_timeout)
    if not ok then
      return nil, string_format("error setting connect timeout: %s", err)
    end
  end

  local ok
  ok, err = memc:connect(self.options.host, self.options.port)
  if not ok then
    return nil, string_format("failed to connect: %s", err)
  end

  local ret1, ret2 = action(memc)

  if self.options.max_idle_timeout and self.options.pool_size then
    ok, err =
      memc:set_keepalive(self.options.max_idle_timeout, self.options.pool_size)
  else
    ok, err = memc:close()
  end
  if not ok then
    ngx_log(ngx_ERR, err)
  end

  return ret1, ret2
end

function _M.incr(self, key, delta, expiry)
  return with_client(self, function(memc)
    local err_pattern =
      string_format("%%s failed for key '%s', expiry '%s': %%s", key, expiry)
    local new_value, err = memc:incr(key, delta)
    if err then
      if err ~= "NOT_FOUND" then
        return nil, string_format(err_pattern, "increment", err)
      end

      local ok
      ok, err = memc:add(key, delta, expiry)
      if ok then
        new_value = delta
      elseif err == "NOT_STORED" then
        -- possibly the other worker added the key, so attempting to incr again
        new_value, err = memc:incr(key, delta)
        if err then
          return nil, string_format(err_pattern, "increment", err)
        end
      else
        return nil, string_format(err_pattern, "add", err)
      end
    end

    return tonumber(new_value), nil
  end)
end

function _M.get(self, key)
  return with_client(self, function(memc)
    local value, flags, err = memc:get(key)
    if err then
      return nil, string_format("'get' failed for '%s': %s", key, err)
    end
    if value == nil and flags == nil and err == nil then
      return nil, nil
    end
    return tonumber(value), nil
  end)
end

function _M.__flush_all(self)
  return with_client(self, function(memc)
    return memc:flush_all()
  end)
end

return _M
