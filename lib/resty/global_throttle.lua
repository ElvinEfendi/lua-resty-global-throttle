local store_new = require("resty.global_throttle.store").new
local sliding_window_new = require("resty.global_throttle.sliding_window").new

local string_format = string.format
local ngx_log = ngx.log

local _M = { _VERSION = "0.1" }
local mt = { __index = _M }

local function window_started_at(self)
  local current_time = ngx.time()
  return (current_time -  (current_time % self.window_size)) * 1000
end

-- TODO: name does not make sense, token maybe?
function _M.new(name, max_rate, window_size_in_seconds, options)
  local store, err = store_new(options)
  if err then
    return nil, string_format("error initiating a store: %s", err)
  end
  
  local window_size = window_size_in_seconds * 1000
  local sw, err = sliding_window_new(store, name, window_size)
  if err then
    return nil, string_format("error while creating sliding window instance: %s", err)
  end

  return setmetatable({
    sliding_window = sw,
    max_rate = max_rate,
    window_size = window_size
  }, mt), nil
end

function _M.process(self)
  self.sliding_window:add_sample()
end

function _M.should_throttle(self)
  local last_count = self.sliding_window:last_sample_count()
  local count = self.sliding_window:sample_count()
  local last_rate = last_count / self.window_size
  local elapsed_time = ngx.now() * 1000 - window_started_at(self)
  local rate = last_rate * (self.window_size - elapsed_time) + count

  return rate > self.max_rate
end

return _M
