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

local function get_last_rate(self, sample, now_ms)
  local a_window_ago_from_now = now_ms - self.window_size
  local last_counter_key = get_counter_key(self, sample, a_window_ago_from_now)

  -- NOTE(elvinefendi): returning 0 as a default value here means
  -- we will allow spike in the first window or in the window that
  -- has no immediate previous window with samples.
  -- What if we default to self.limit here?
  local last_count = self.store:get(last_counter_key) or 0

  return last_count / self.window_size
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

function _M.is_limit_exceeding(self, sample)
  local now_ms = ngx_now() * 1000

  local counter_key = get_counter_key(self, sample, now_ms)

  local count, err = self.store:get(counter_key)
  if err then
    return nil, nil, err
  end
  if not count then
    count = 0
  end

  local last_rate = get_last_rate(self, sample, now_ms)
  local elapsed_time = now_ms % self.window_size
  local estimated_total_count =
    last_rate * (self.window_size - elapsed_time) + count

  local limit_exceeding = estimated_total_count >= self.limit
  local delay_ms = nil

  if limit_exceeding then
    if last_rate == 0 then
      -- When the last rate is 0, and limit is exceeding that means the limit
      -- in the current window is precisely met (without estimation,
      -- refer to the above formula). Which means we have to wait until the
      -- next window to allow more samples.
      delay_ms = self.window_size - elapsed_time
    else
      -- The following formula is obtained by solving the following equation
      -- for `delay_ms`:
      -- last_rate * (self.window_size - (elapsed_time + delay_ms)) + count =
      --   self.limit - 1
      -- This equation is comparable to total count estimation for the current
      -- window formula above. Basically the idea is, how long more (delay_ms)
      -- should we wait before estimated total count is below the limit again.
      delay_ms =
        self.window_size - (self.limit - count) / last_rate - elapsed_time
    end

    --[[
    -- 2020/12/21 16:01:06 [error] 55#55: *2063 [lua] app.lua:37: rewrite_memc(): error while processing key: failed to check if limit is exceeding: wrong value for delay_ms: 2264.0909090909, client: 172.30.0.1, server: localhost, request: "GET /memc?key=m1 HTTP/1.1", host: "localhost:8080"
    --]]
    -- Unless weird time drifts happen or counter is borked,
    -- this should never be true.
    if delay_ms > self.window_size or delay_ms < 0 then
      local msg = string_format("wrong value for delay_ms: %s. \z
        window_size: %s, limit: %s, count: %s, last_rate: %s, \z
        elapsed_time: %s",
        delay_ms, self.window_size, self.limit, count, last_rate, elapsed_time)
      return limit_exceeding, nil, msg
    end
  end

  return limit_exceeding, delay_ms, nil
end

local function is_limit_exceeding(self, sample, now_ms, count, sample_processed) 
  local last_rate = get_last_rate(self, sample, now_ms)
  local elapsed_time = now_ms % self.window_size
  local estimated_total_count =
    math.floor(last_rate * (self.window_size - elapsed_time)) + count

  local limit_exceeding
  if sample_processed then
    -- When the sample is processed and we are at the limit,
    -- we don't need to reject the current request. The current request
    -- related to the sample should be rejected when we are strictly over
    -- the limit.
    limit_exceeding = estimated_total_count > self.limit
  else
    -- Since at this point we haven't processed the sample yet,
    -- we should reject the request even if we are at the limit because
    -- we know that after processing the sample we will be over the limit.
    limit_exceeding = estimated_total_count >= self.limit
  end

  print("sample = ", sample, " now_ms = ", now_ms, " count = ", count, " sample_processed = ", sample_processed,
    " last_rate = ", last_rate, " elapsed_time = ", elapsed_time, " limit = ", self.limit, " limit_exceeding = ", limit_exceeding)
  local delay_ms = nil

  if limit_exceeding then
    if last_rate == 0 or count >= self.limit then
      -- When the last rate is 0, and limit is exceeding that means the limit
      -- in the current window is precisely met (without estimation,
      -- refer to the above formula). Which means we have to wait until the
      -- next window to allow more samples.
      --
      -- Because of the racy behaviur, it is possible that `count` goes over
      -- the limit. Similar to the last_rate = 0 case, we should also wait
      -- until the next window in this case because limit in the current window
      -- is already exceeded.
      delay_ms = self.window_size - elapsed_time
    else
      -- The following formula is obtained by solving the following equation
      -- for `delay_ms`:
      -- last_rate * (self.window_size - (elapsed_time + delay_ms)) + count =
      --   self.limit - 1
      -- This equation is comparable to total count estimation for the current
      -- window formula above. Basically the idea is, how long more (delay_ms)
      -- should we wait before estimated total count is below the limit again.
      delay_ms =
        self.window_size - (self.limit - count) / last_rate - elapsed_time
    end

    -- Unless weird time drifts happen or counter is borked,
    -- this should never be true.
    if delay_ms > self.window_size or delay_ms < 0 then
      local msg = string_format("wrong value for delay_ms: %s. \z
        window_size: %s, limit: %s, count: %s, last_rate: %s, \z
        elapsed_time: %s",
        delay_ms, self.window_size, self.limit, count, last_rate, elapsed_time)
      return limit_exceeding, nil, msg
    end
  end

  return limit_exceeding, delay_ms, nil
end

function _M.process_sample(self, sample)
  -- TODO: do you really need to freeze now_ms like this?
  local now_ms = ngx_now() * 1000

  local counter_key = get_counter_key(self, sample, now_ms)
  local count, err = self.store:get(counter_key)
  if err then
    return nil, nil, err
  end
  if not count then
    count = 0
  end

  local limit_exceeding, delay_ms, err =
    is_limit_exceeding(self, sample, now_ms, count, false)
  if err then
    return nil, nil, err
  end
  if limit_exceeding then
    print("limit_exceeding = ", limit_exceeding)
    return true, delay_ms, nil
  end

  -- Limit is not exceeding, so process the sample.
  local expiry = self.window_size * 2 / 1000 --seconds
  local new_count, err = self.store:incr(counter_key, 1, expiry)
  print("new_count = ", new_count)
  if err then
    return false, nil, err
  end

  -- Since this is a distributed throttler, there's a inherent race.
  -- Every instance is trying trying to increment the counter, so it is
  -- possible that when we calculate limit above, it is not exceeding yet.
  -- But by the time we process the sample by incrementing its counter,
  -- other throttle instances might have incremented the same counter large
  -- enough that after we increment it here we are already over the limit.
  -- That is why we have to recalculate and see if we are over the limit after
  -- adding this, if so the current request should be rejected too.
  -- In other words, there are two scenarios where limit can be exceeded:
  -- 1. before processing a given sample
  -- 2. after processing a given sample
  return is_limit_exceeding(self, sample, now_ms, new_count, true)
end

return _M
