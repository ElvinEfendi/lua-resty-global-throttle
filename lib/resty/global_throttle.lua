local string_format = string.format
local ngx_log = ngx.log

local _M = { _VERSION = "0.1" }
local mt = { __index = _M }

-- should these not be per instance?
local count = 0
local previous_count = 0
-- this variable is needed so that we can know when to reset counters
local current_window_started_at = 0

-- how can we avoid string parsing here?
-- milliseconds
local function window_started_at(self)
  local current_time = ngx.time()
  return (current_time -  (current_time % self.window_size)) * 1000
end

function _M.new(self, name, opts)
  if not name then
    return nil, "name is required"
  end

  if not opts.rate or opts.rate < 0 then
    return nil, "rate is required and has to be greater than or equal to 0"
  end

  return setmetatable({
    name = name,
    rate = opts.rate,
    window_size = opts.window_size or 60, -- seconds
  }, mt), nil
end

function _M.process(self)
  local new_window_starts_at = window_started_at(self)
  if new_window_starts_at > current_window_started_at then
    -- new window started
    current_window_started_at = new_window_starts_at
    previous_count = count
    count = 0
  end


  count = count + 1

  ngx_log(ngx.INFO,
    string_format("count = %s, last_two_counts = %s, window_started_at = %s", count, last_two_counts, window_started_at(self)))
end

function _M.should_throttle(self)
  local elapsed_time = ngx.now() - window_started_at(self) / 1000
  local previous_rate = previous_count / self.window_size
  local current_rate = previous_rate * (self.window_size - elapsed_time) + count

  ngx.log(ngx.INFO, string_format("elapsed_time %s, previous_rate %s, current_rate %s", elapsed_time, previous_rate, current_rate))
  return current_rate > self.rate
end

return _M
