local busted_runner
do 
  -- avoid warning during test runs caused by
  -- https://github.com/openresty/lua-nginx-module/blob/2524330e59f0a385a9c77d4d1b957476dce7cb33/src/ngx_http_lua_util.c#L810

  local traceback = require "debug".traceback

  setmetatable(_G, { __newindex = function(table, key, value) rawset(table, key, value) end })
  busted_runner = require "busted.runner"

  -- if there's more constants need to be whitelisted for test runs, add here.
  local GLOBALS_ALLOWED_IN_TEST = {
    _TEST = true,
    ngx_time_travel = true,
    ngx_freeze_time = true,
    memcached = true,
  }
  local newindex = function(table, key, value)
    rawset(table, key, value)

    local phase = ngx.get_phase()
    if phase == "init_worker" or phase == "init" then
      return
    end

    -- we check only timer phase because resty-cli runs everything in timer phase
    if phase == "timer" and GLOBALS_ALLOWED_IN_TEST[key] then
      return
    end

    local message = "writing a global lua variable " .. key ..
      " which may lead to race conditions between concurrent requests, so prefer the use of 'local' variables " .. traceback('', 2)
    -- it's important to do print here because ngx.log is mocked below
    print(message)
  end
  setmetatable(_G, { __newindex = newindex })
end

do
  -- following mocking let's us travel in time
  -- and freeze time

  local time_travel = 0
  local frozen_time

  local ngx_now = ngx.now
  _G.ngx.now = function()
    if frozen_time then
      return frozen_time + time_travel
    end
    return ngx_now() + time_travel
  end

  -- this function can be used in tests to travel in time
  _G.ngx_time_travel = function(offset, f)
    time_travel = offset
    f()
    time_travel = 0
  end

  _G.ngx_freeze_time = function(time, f)
    frozen_time = time
    f()
    frozen_time = nil
  end

  local memcached_host = os.getenv("MEMCACHED_HOST")
  local memcached_port = os.getenv("MEMCACHED_PORT")
  local with_memcached_client = function(command)
    local rm = require("resty.memcached")
    local memc, err = rm:new()
    local ok, err = memc:connect(memcached_host, memcached_port)
    if err then
      assert(err, "failed to connect to memcached: " .. err)
    end

    local ret1, ret2, ret3 = command(memc)

    memc:close()

    return ret1, ret2, ret3
  end

  _G.memcached = {
    host = memcached_host,
    port = memcached_port,
    with_client = with_memcached_client,
    flush_all = function()
      return with_memcached_client(function(memc)
        return memc:flush_all()
      end)
    end,
    get = function(key)
      return with_memcached_client(function(memc)
        return memc:get(key)
      end)
    end,
  }
end

busted_runner({ standalone = false })
