local tostring = tostring
local string_format = string.format
local math_floor = math.floor
local ngx_now = ngx.now
local setmetatable = setmetatable

local _M = {}
local mt = { __index = _M }

local DEFAULT_WINDOW_SIZE = 60 * 1000 -- milliseconds

-- uniquely identifies the window associated with given time
local function get_id(self, time)
  return tostring(math_floor(time / self.window_size))
end

-- counter key is made of the identifier of current sliding window instance,
-- and identifier of the current window. This makes sure it is unique
-- per given sliding window instance in the given window.
local function get_counter_key(self, sample, time)
  local id = get_id(self, time)
  return string_format("%s.%s.counter", sample, id)
end

local function last_sample_count(self, sample, now_ms)
  local a_window_ago_from_now = now_ms - self.window_size
  local last_counter_key = get_counter_key(self, sample, a_window_ago_from_now)

  return self.store:get(last_counter_key) or 0
end

function _M.new(store, limit, window_size)
  if not store then
    return nil, "'store' parameter is missing"
  end
  if not store.incr then
    return nil, "'store' has to implement 'incr' function"
  end
  if not store.get then
    return nil, "'store' has to implement 'get' function"
  end

  return setmetatable({
    store = store,
		limit = limit, -- TODO: what if this is not given?
    window_size = window_size or DEFAULT_WINDOW_SIZE, -- milliseconds
		throttled_keys = ngx.shared.throttled_keys, -- TODO: make this better
  }, mt), nil
end

function _M.add_sample(self, sample)
  local now_ms = ngx_now() * 1000

  local counter_key = get_counter_key(self, sample, now_ms)

  local expiry = self.window_size * 2 / 1000 --seconds

  local _, err = self.store:incr(counter_key, 1, expiry)
  if err then
    return err
  end

  return nil
end

function _M.estimated_total_count(self, sample)
  local now_ms = ngx_now() * 1000

  local counter_key = get_counter_key(self, sample, now_ms)

  local count, err = self.store:get(counter_key)
  if err then
    return nil, err
  end
  if not count then
    count = 0
  end

  local last_count = last_sample_count(self, sample, now_ms)
  local last_rate = last_count / self.window_size
  local elapsed_time = now_ms % self.window_size
  local estimated_total_count = last_rate * (self.window_size - elapsed_time) + count

	local delay = self.window_size - (self.limit - count) / last_rate - elapsed_time
	print("delay: ", delay, ", throttled: ", estimated_total_count >= self.limit)

  return estimated_total_count, nil
end

function _M.add_sample_and_estimate_total_count(self, sample)
  local now_ms = ngx_now() * 1000

  local counter_key = get_counter_key(self, sample, now_ms)

  local expiry = self.window_size * 2 / 1000 --seconds

  local count, err = self.store:incr(counter_key, 1, expiry)
  if err then
    return nil, err
  end

  local last_count = last_sample_count(self, sample, now_ms)
  local last_rate = last_count / self.window_size
  local elapsed_time = now_ms % self.window_size
  local estimated_total_count = last_rate * (self.window_size - elapsed_time) + count

  print("estimated_total_count: ", estimated_total_count, ", limit: ", self.limit, ", last_rate: ", last_rate)

  -- if last_rate is 0, then we allow burst of limit in the current window
	if estimated_total_count >= self.limit and last_rate > 0 and not self:should_throttle(sample) then
		local delay_ms = self.window_size - (self.limit - count) / last_rate - elapsed_time
    print("throttling for ", delay_ms)
		self.throttled_keys:set(sample, true, delay_ms / 1000)
	end

  return estimated_total_count, nil
end

function _M.should_throttle(self, sample)
  return self.throttled_keys:get(sample) == true
end

return _M
