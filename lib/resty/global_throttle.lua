local store_new = require("resty.global_throttle.store").new
local sliding_window_new = require("resty.global_throttle.sliding_window").new

local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN
local ngx_timer_at = ngx.timer.at
local setmetatable = setmetatable
local string_format = string.format

local _M = { _VERSION = "0.1.0" }
local mt = { __index = _M }

function _M.new(limit, window_size_in_seconds, decision_cache, store_options)
  if not store_options then
    return nil, "'store_options' param is missing"
  end

  local store, err = store_new(store_options)
  if not store then
    return nil, string_format("error initiating the store: %s", err)
  end

  local window_size = window_size_in_seconds * 1000
  local sw
  sw, err = sliding_window_new(store, limit, window_size, decision_cache)
  if not sw then
    return nil, "error while creating sliding window instance: " .. err
  end

  return setmetatable({
    sliding_window = sw,
    limit = limit,
    window_size = window_size,
    process_async = store.is_remote,
    decision_cache = decision_cache,
  }, mt), nil
end

local function process(self, key)
  local limit_exceeding, delay, err = self.sliding_window:process_sample(key)
  if err then
    ngx_log(ngx_ERR, "error while processing sample '", key, "': ", err)
  elseif limit_exceeding then
    local ok, forcible
    ok, err, forcible = self.decision_cache:set(key, true, delay)
    if not ok then
      ngx_log(ngx_ERR, "error while caching a decision: ", err)
    elseif forcible then
      ngx_log(ngx_WARN, "removed previous one while caching a decision: ", err)
    end
  end
end

function _M.process(self, key)
  local limit_exceeding = (self.decision_cache:get(key) == true)
  if limit_exceeding then
    return true
  end

  if self.process_async then
    local ok, err = ngx_timer_at(0, process, self, key)
    if not ok then
      ngx_log(ngx_ERR, "error while creating a timer: ", err)
    end
  else
    process(self, key)
  end

  return false
end

return _M
