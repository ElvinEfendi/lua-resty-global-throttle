local tostring = tostring
local string_format = string.format
local math_floor = math.floor
local ngx_now = ngx.now
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local setmetatable = setmetatable

local _M = {}
local mt = { __index = _M }

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

  local last_count, err = self.store:get(last_counter_key)
  if err then
    return nil, err
  end
  if not last_count then
    -- NOTE(elvinefendi): returning 0 as a default value here means
    -- we will allow spike in the first window or in the window that
    -- has no immediate previous window with samples.
    -- What if we default to self.limit here?
    last_count = 0
  end
  if last_count > self.limit then
    -- in process_sample we also reactively check for exceeding limit
    -- after icnrementing the counter. So even though counter can be higher
    -- than the limit as a result of racy behaviour we would still throttle
    -- anyway. That is way it is important to correct the last count here
    -- to avoid over-punishment.
    last_count = self.limit
  end

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
    window_size = window_size
  }, mt), nil
end

local function estimate_final_count(self, remaining_time, last_rate, count)
  return last_rate * remaining_time + count
end

local function get_desired_delay(self, remaining_time, last_rate, count)
  if last_rate == 0 then
    return remaining_time
  end

  local desired_delay = remaining_time - (self.limit - count) / last_rate

  if desired_delay <= 0 or desired_delay > self.window_size then
    ngx_log(ngx_ERR, "unexpected value for delay_ms: ", delay_ms,
      ", when remaining_time = ", remaining_time,
      " last_rate = ", last_rate,
      " count = ", count,
      " limit = ", self.limit,
      " window_size = ", self.window_size)
    return nil
  end

  return desired_delay
end

-- process_sample first checks if limit exceeding for the given sample.
-- If so then, it calculates for how long this sample
-- should be delayed/rejected and returns estimated total count for
-- the current window for this sample along with suggested delay time to bring
-- the rate down below the limit.
-- If limit is not exceeding yet, it increments the counter corresponding
-- to the sample in the current window. Finally it checks if the limit is
-- exceeding again. This check is necessary because between the first check and
-- increment another sliding window instances might have processed enough
-- occurences of this sample to exceed the limit. Therefore if this check shows
-- that the limit is exceeding then we again calculate necessary delay.
--
-- Return values: estimated_count, delay, err
-- `estimated_count` - this is what the algorithm expects number of occurences
-- will be for the sample by the end of current window. It is calculated based
-- on the rate from previous window and extrapolated to the current window.
-- If estimated_count is bigger than the configured limit, then the function
-- will also return delay > 0 to suggest that the sample has to be throttled.
-- `delay`           - this is either strictly bigger than 0 in case limit is
-- exceeding, or nil in case rate of occurences of the sample is under the
-- limit. The unit is second.
-- `err`             - in case there is a problem with processing the sample
-- this will be a string explaining the problem. In all other cases it is nil.
function _M.process_sample(self, sample)
  local now = ngx_now()
  local counter_key = get_counter_key(self, sample, now)
  local remaining_time = self.window_size - now % self.window_size

  local count, err = self.store:get(counter_key)
  if err then
    return nil, nil, err
  end
  if not count then
    count = 0
  end
  if count >= self.limit then
    -- count can be over the limit because of the racy nature
    -- when it is at/over the limit we know for sure what is the final
    -- count and desired delay for the current window, so no need to proceed
    return count, remaining_time, nil
  end

  local last_rate, err = get_last_rate(self, sample, now)
  if err then
    return nil, nil, err
  end

  local estimated_final_count, err =
    estimate_final_count(self, remaining_time, last_rate, count)
  if err then
    return nil, nil, err
  end
  if estimated_final_count >= self.limit then
    local desired_delay =
      get_desired_delay(self, remaining_time, last_rate, count)
    return estimated_final_count, desired_delay, nil
  end

  local expiry = self.window_size * 2
  local new_count, err = self.store:incr(counter_key, 1, expiry)
  if err then
    return nil, nil, err
  end

  -- incr above might take long enough to make difference, so
  -- we recalculate time-dependant variables.
  remaining_time = self.window_size - ngx_now() % self.window_size
  last_rate, err = get_last_rate(self, sample, ngx_now())
  if err then
    return nil, nil, err
  end

  estimated_final_count, err =
    estimate_final_count(self, remaining_time, last_rate, new_count)
  if err then
    return nil, nil, err
  end
  if estimated_final_count > self.limit then
    local desired_delay =
      get_desired_delay(self, remaining_time, last_rate, new_count)
    return estimated_final_count, desired_delay, nil
  end

  return estimated_final_count, nil, nil
end

return _M
