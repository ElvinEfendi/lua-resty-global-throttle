use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq(
    lua_package_path "$pwd/t/lib/?.lua;$pwd/lib/?.lua;;";
    lua_shared_dict counters 1M;

    init_by_lua_block {
      require "resty.core"
    }
);

run_tests();

__DATA__

=== TEST 1: correctly detects when rate limit is not hit
--- http_config eval: $::HttpConfig
--- config
location = /t {
  content_by_lua_block {
    local global_throttle = require "resty.global_throttle"

    local ip_throttle, err = global_throttle.new("ip_throttle", 100, 2,  { provider = "shared_dict", name = "counters" })
    if err then
      ngx.say(err)
      return
    end

    for i=1,100 do
      ip_throttle:process()
    end
      ngx.sleep(0.2)
    if ip_throttle:should_throttle() then
      ngx.say("failed 0")
      return
    end

    ip_throttle:process()
    if not ip_throttle:should_throttle() then
      return ngx.say("failed")
    end

    ngx.sleep(1.8) -- go to next window
    ip_throttle:process()
    if ip_throttle:should_throttle() then
      ngx.say("failed 1")
      return
    end

    ngx.say("OK")
  }
}
--- request
GET /t
--- response_body
OK
--- error_code: 200
--- ONLY

=== TEST 2: correctly detects when rate limit is hit
--- http_config eval: $::HttpConfig
--- config
location = /t {
  content_by_lua_block {
    local global_throttle = require "resty.global_throttle"

    local ip_throttle = global_throttle:new("ip_throttle", { rate = 600, window_size = 3, subject = "remote_addr" })

    for i=1,60 do
      ip_throttle:process()
    end

    if ip_throttle:should_throttle() then
      ngx.status = 403
      ngx.say("OK")
      return
    end
  }
}
--- request
GET /t
--- response_body
OK
--- error_code: 403
