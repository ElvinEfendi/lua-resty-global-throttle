local global_throttle = require("resty.global_throttle")

local _M = {}

local lrucache = require("resty.lrucache")
local process_cache, err = lrucache.new(200)
if not process_cache then
  error("failed to create cache: " .. (err or "unknown"))
end

local memc_host = os.getenv("MEMCACHED_HOST")
local memc_port = os.getenv("MEMCACHED_PORT")

local function rewrite_memc(cache)
  local key = ngx.req.get_uri_args()['key']
  
  local limit_exceeding
  if cache then
    limit_exceeding = cache:get(key)
    if limit_exceeding then
      return ngx.exit(429)
    end
  end

  local my_throttle, err = global_throttle.new(10, 2, {
    provider = "memcached",
    host = memc_host,
    port = memc_port,
    connect_timeout = 15,
    max_idle_timeout = 10000,
    pool_size = 100,
  })

  local delay_ms, err
  limit_exceeding, delay_ms, err = my_throttle:process(key)
  if err then
    ngx.log(ngx.ERR, "error while processing key: ", err)
    return ngx.exit(500)
  end

  if limit_exceeding then
    if cache then
      local delay = delay_ms / 1000
      if delay > 0 then
        cache:set(key, value, delay)
      end
    end

    return ngx.exit(429)
  end
end

function _M.rewrite_memc_with_lru()
  rewrite_memc(process_cache)
end

function _M.rewrite_memc_with_dict()
  rewrite_memc(ngx.shared.memc_decision_cache)
end

function _M.rewrite_memc()
  rewrite_memc()
end

function _M.rewrite_dict()
  local my_throttle, err = global_throttle.new(10, 2, {
    provider = "shared_dict",
    name = "counters"
  })

  local key = ngx.req.get_uri_args()['key']

  local limit_exceeding, _delay_ms, err = my_throttle:process(key)
  if err then
    ngx.log(ngx.ERR, "error while processing key: ", err)
    return ngx.exit(500)
  end

  if limit_exceeding then
    return ngx.exit(429)
  end
end

return _M
