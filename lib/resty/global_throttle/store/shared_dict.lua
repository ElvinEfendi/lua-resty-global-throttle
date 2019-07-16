local string_format = string.format
local ngx_log = ngx.log
local ngx_WARN = ngx.WARN

local _M = {}
local mt = { __index = _M }

function _M.new(options)
  if not options.name then
    return nil, "shared dictionary name is mandatory"
  end

  local dict = ngx.shared[options.name]
  if not dict then
    return nil, string_format("shared dictionary with name \"%s\" is not configured", options.name)
  end

  return setmetatable({
    dict = dict,
  }, mt), nil
end

function _M.incr(self, key, delta, expiry)
  local new_value, err, forcible = self.dict:incr(key, delta, 0, expiry)
  if err then
    return nil, err
  end

  if forcible then
    ngx_log(ngx_WARN, "shared dictionary is full, removed valid key(s) to store the new one")
  end

  return new_value, nil
end

function _M.get(self, key)
  local value = self.dict:get(key)
  if not value == nil then
    return nil, "not found"
  end

  return value, nil
end

return _M
