local tostring = tostring
local string_format = string.format
local math_floor = math.floor
local ngx_now = ngx.now

local _M = {}
local mt = { __index = _M }

local DEFAULT_WINDOW_SIZE = 60 * 1000

-- uniquely identifies the window associated with given time
local function get_id(self, time)
  return tostring(math_floor(time / self.window_size))
end

local function get_counter_key(self, time)
  local id = get_id(self, time)
  return string_format("%s.%s.counter", self.name, id)
end

function _M.new(store, name, window_size)
  if not name then
    return nil, "name is required to unambigiously identify the sliding window instance"
  end

  if not store or not store.incr or not store.get then
    return nil, "store parameter is necessary and has to implement \"incr\" and \"get\" functions"
  end

  return setmetatable({
    store = store,
    name = name,
    window_size = window_size or DEFAULT_WINDOW_SIZE, -- milliseconds
  }, mt), nil
end

function _M.add_sample(self)
  local counter_key = get_counter_key(self, ngx_now() * 1000)
  local expiry = self.window_size * 2 / 1000 --seconds

  local count, rolled_over, err = self.store:incr(counter_key, 1, expiry)
  if not err then
    return count, rolled_over, nil
  end

  return nil, nil, err
end

function _M.sample_count(self)
  local counter_key = get_counter_key(self, ngx_now() * 1000)
  return self.store:get(counter_key) or 0
end

function _M.last_sample_count(self)
  local a_window_ago_from_now = ngx_now() * 1000 - self.window_size
  local last_counter_key = get_counter_key(self, a_window_ago_from_now)

  return self.store:get(last_counter_key) or 0
end

return _M
