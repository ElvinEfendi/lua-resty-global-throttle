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
		limit = limit,
    window_size = window_size or DEFAULT_WINDOW_SIZE, -- milliseconds
  }, mt), nil
end

function _M.process_sample(self, sample)
  local now_ms = ngx_now() * 1000

  local counter_key = get_counter_key(self, sample, now_ms)

  local expiry = self.window_size * 2 / 1000 --seconds

  local count, err = self.store:incr(counter_key, 1, expiry)
  if err then
    return nil, nil, err
  end

  local last_count = last_sample_count(self, sample, now_ms)
  local last_rate = last_count / self.window_size
  local elapsed_time = now_ms % self.window_size
  local estimated_total_count =
    last_rate * (self.window_size - elapsed_time) + count

  --[[
  print(
    "estimated_total_count: ", estimated_total_count,
    ", last_rate: ", last_rate,
    ", limit: ", self.limit
  )
  --]]

  -- if last_rate is 0, then we allow burst of limit in the current window
	if estimated_total_count >= self.limit then
    -- when limit is hit and last_rate is 0, then we have to throttle until the next window
		local delay_ms
    if last_rate == 0 then
      delay_ms = self.window_size - elapsed_time
    elseif last_rate > 0 then
      delay_ms =
        self.window_size - (self.limit - count) / last_rate - elapsed_time
    else
      -- TODO: can this happen?
    end
    if not delay_ms then
      error("XIYAR")
    end
    -- TODO: should we guard against delay_ms == 0, which would mean indefinite throttle
    -- something like forcing delay_ms to be at max self.window_size
    return true, delay_ms / 1000, nil
	end

  return false, nil, nil
end

return _M
