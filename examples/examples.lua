local memcached = require("resty.memcached")
local global_throttle = require("resty.global_throttle")

local _M = {}

-- it does not make sense to cache decision for too little time
-- the benefit of caching likely is negated if we cache for too little time
local CACHE_THRESHOLD = 0.001

local lrucache = require("resty.lrucache")
local process_cache, err = lrucache.new(200)
if not process_cache then
  error("failed to create cache: " .. (err or "unknown"))
end

local memc_host = os.getenv("MEMCACHED_HOST")
local memc_port = os.getenv("MEMCACHED_PORT")

local function rewrite_memc(namespace, cache)
  --ngx.log(ngx.NOTICE, "timestamp: ", ngx.now())

  local key = ngx.req.get_uri_args()['key']

  local limit_exceeding
  if cache then
    limit_exceeding = cache:get(key)
    if limit_exceeding then
      return ngx.exit(429)
    end
  end

  local my_throttle, err = global_throttle.new(namespace, 10, 2, {
    provider = "memcached",
    host = memc_host,
    port = memc_port,
    connect_timeout = 15,
    max_idle_timeout = 10000,
    pool_size = 100,
  })
  if err then
    ngx.log(ngx.ERR, err)
    return ngx.exit(500)
  end

  local _estimated_final_count, desired_delay, remaining_time, err = my_throttle:process(key)
  if err then
    ngx.log(ngx.ERR, "error while processing key: ", err)
    return ngx.exit(500)
  end

  if desired_delay then
    if cache then
      if desired_delay > CACHE_THRESHOLD then
        cache:add(key, value, desired_delay)
      end
    end

    return ngx.exit(429)
  end
end

function _M.rewrite_memc_with_lru()
  rewrite_memc("memc-lru", process_cache)
end

function _M.rewrite_memc_with_dict()
  rewrite_memc("memc-dict", ngx.shared.memc_decision_cache)
end

function _M.rewrite_memc()
  rewrite_memc("memc")
end

function _M.rewrite_dict()
  local my_throttle, err = global_throttle.new("dict", 10, 2, {
    provider = "shared_dict",
    name = "counters"
  })

  local key = ngx.req.get_uri_args()['key']

  local _estimated_final_count, desired_delay, remaining_time, err = my_throttle:process(key)
  if err then
    ngx.log(ngx.ERR, "error while processing key: ", err)
    return ngx.exit(500)
  end

  if desired_delay then
    return ngx.exit(429)
  end
end

function _M.process_output()
  local my_throttle, err = global_throttle.new("dict", 10, 60, {
    provider = "shared_dict",
    name = "counters"
  })

  local key = ngx.req.get_uri_args()['key']

  local _estimated_final_count, desired_delay, remaining_time, err = my_throttle:process(key)

  return ngx.say(string.format("\nestimated_final_count=%s\ndesired_delay=%s\nremaining_time=%s\nerr=%s",
   _estimated_final_count, desired_delay, remaining_time,err))  
  
end


-- This can be used to inspect what is in the
-- store. It assumes you disable expiry in the store.
-- You can obtain `ts` and `te` by logging ngx.now().
function _M.stats()
  local test_start = ngx.req.get_uri_args()['ts']
  local test_end = ngx.req.get_uri_args()['te']
  local namespace = ngx.req.get_uri_args()['ns']
  local sample = ngx.req.get_uri_args()['s']
  local window_size = ngx.req.get_uri_args()['ws']

  local memc, err = memcached:new()
  if err then
    ngx.log(ngx.ERR, err)
    return ngx.exit(500)
  end

  local ok
  ok, err = memc:connect(memc_host, memc_port)
  if not ok then
    ngx.log(ngx.ERR, err)
    return ngx.exit(500)
  end

  local namespace = "memc"
  local sample = "client"
  local window_size = 2
  local window_id_start = math.floor(test_start / 2)
  local window_id_end = math.floor(test_end / 2)

  local response = ""
  for i=window_id_start,window_id_end,1 do
    local counter_key = string.format("%s.%s.%s.counter", namespace, sample, i)
    local value, _, err = memc:get(counter_key)
    if err then
      ngx.log(ngx.ERR, "error when getting key: ", err)
    end
    response = response .. "\n" .. counter_key .. " : " .. tostring(value)
  end

  ok, err = memc:set_keepalive(10000, 100)
  if not ok then
    ngx.log(ngx.ERR, err)
    return ngx.exit(500)
  end

  ngx.say(response)
end

return _M
