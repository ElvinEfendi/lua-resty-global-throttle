local global_throttle = require("resty.global_throttle")

local _M = {}

local lrucache = require("resty.lrucache")
local process_cache, err = lrucache.new(200)
if not process_cache then
  error("failed to create cache: " .. (err or "unknown"))
end

local memc_host = os.getenv("MEMCACHED_HOST")
local memc_port = os.getenv("MEMCACHED_PORT")

local function rewrite_memc(namespace, cache)
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

  local _estimated_final_count, desired_delay, err = my_throttle:process(key)
  if err then
    ngx.log(ngx.ERR, "error while processing key: ", err)
    return ngx.exit(500)
  end

  if desired_delay then
    if cache then
      cache:set(key, value, desired_delay)
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

  local _estimated_final_count, desired_delay, err = my_throttle:process(key)
  if err then
    ngx.log(ngx.ERR, "error while processing key: ", err)
    return ngx.exit(500)
  end

  if desired_delay then
    return ngx.exit(429)
  end
end

return _M
