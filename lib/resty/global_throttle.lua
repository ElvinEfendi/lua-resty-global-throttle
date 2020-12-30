local store_new = require("resty.global_throttle.store").new
local sliding_window_new = require("resty.global_throttle.sliding_window").new

local setmetatable = setmetatable
local string_format = string.format

local _M = { _VERSION = "0.2.0" }
local mt = { __index = _M }

local MAX_NAMESPACE_LEN = 35

function _M.new(namespace, limit, window_size_in_seconds, store_options)
  if not namespace then
    return nil, "'namespace' param is missing"
  end

  namespace = namespace:lower()

  if namespace ~= namespace:match("[%a%d-]+") then
    return nil, "'namespace' can have only letters, digits and hyphens"
  end

  if namespace:len() > MAX_NAMESPACE_LEN then
    return nil,
      string_format("'namespace' can be at most %s characters",
        MAX_NAMESPACE_LEN)
  end

  if not store_options then
    return nil, "'store_options' param is missing"
  end

  local store, err = store_new(store_options)
  if not store then
    return nil, string_format("error initiating the store: %s", err)
  end

  local sw
  sw, err = sliding_window_new(namespace, store, limit, window_size_in_seconds)
  if not sw then
    return nil, "error while creating sliding window instance: " .. err
  end

  return setmetatable({
    sliding_window = sw,
  }, mt), nil
end

function _M.process(self, key)
  return self.sliding_window:process_sample(key)
end

return _M
