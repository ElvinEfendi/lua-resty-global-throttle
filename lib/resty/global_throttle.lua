local store_new = require("resty.global_throttle.store").new
local sliding_window_new = require("resty.global_throttle.sliding_window").new

local setmetatable = setmetatable
local string_format = string.format

local _M = { _VERSION = "0.1.0" }
local mt = { __index = _M }

function _M.new(limit, window_size_in_seconds, store_options)
  if not store_options then
    return nil, "'store_options' param is missing"
  end

  local store, err = store_new(store_options)
  if not store then
    return nil, string_format("error initiating the store: %s", err)
  end

  local sw
  sw, err = sliding_window_new(store, limit, window_size_in_seconds)
  if not sw then
    return nil, "error while creating sliding window instance: " .. err
  end

  return setmetatable({
    sliding_window = sw,
    limit = limit,
  }, mt), nil
end

function _M.process(self, key)
  return self.sliding_window:process_sample(key)
end

return _M
