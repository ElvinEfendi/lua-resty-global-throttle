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

  local window_size = window_size_in_seconds * 1000
  local sw
  sw, err = sliding_window_new(store, limit, window_size)
  if not sw then
    return nil, "error while creating sliding window instance: " .. err
  end

  return setmetatable({
    sliding_window = sw,
    limit = limit,
    window_size = window_size
  }, mt), nil
end

function _M.process(self, key)
  local estimated_total_count, err =
    self.sliding_window:estimated_total_count(key)
  if not estimated_total_count then
    return nil, "estimated_total_count failed with: " .. err
  end

  local should_throttle = estimated_total_count >= self.limit
  if should_throttle then
    -- we don't count throttled samples
    return true, nil
  end

  err = self.sliding_window:add_sample(key)
  if err then
    return should_throttle, "add_sample failed with: " .. err
  end

  return should_throttle, nil
end

function _M.process_fast(self, key)
  if self.sliding_window:should_throttle(key) then
    return true
  end

  -- this should be done only when using external store like memcached
  -- this way we don't add latency to request
  -- gotta be careful to not exhaust all timers here when nginx can not expire them timely
  -- also if ngixn is already under load, these will not fire on time
  -- which means the throttling decision will delay.
  ngx.timer.at(0, function()
	  self.sliding_window:add_sample_and_estimate_total_count(key)
  end)
  
  return false
end

return _M
