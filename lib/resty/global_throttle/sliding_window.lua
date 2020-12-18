local tostring = tostring
local string_format = string.format
local math_floor = math.floor
local ngx_now = ngx.now

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

function _M.new(store, window_size)
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
    window_size = window_size or DEFAULT_WINDOW_SIZE, -- milliseconds
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

  return estimated_total_count, nil
end

return _M
