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

busted_runner({ standalone = false })
