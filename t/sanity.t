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

=== TEST 1: all cases
--- http_config eval: $::HttpConfig
--- config
location /protected {
  content_by_lua_block {
    local global_throttle = require "resty.global_throttle"
    local client_throttle = global_throttle.new(100, 0.5, { provider = "shared_dict", name = "counters" })

    local args, err = ngx.req.get_uri_args()
    if err then
      ngx.status = 500
      ngx.say(err)
      return ngx.exit(ngx.HTTP_OK)
    end

    local key = args.api_client_id
    local should_throttle, err = client_throttle:process(key)
    if should_throttle then
      ngx.status = 429
      ngx.say("throttled")
      return ngx.exit(ngx.HTTP_OK)
    end

    ngx.exit(ngx.HTTP_OK)
  }
}

location = /t {
  content_by_lua_block {
    local res

    res = ngx.location.capture("/protected?api_client_id=1")
    if res.status ~= 200 then
      ngx.status = res.status
      ngx.say("expected request to not be throttled")
      return ngx.exit(ngx.HTTP_OK)
    end

    for i=1,100 do
      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status ~= 200 then
        ngx.status = res.status
        ngx.say("expected burst to be allowed in the first window")
        return ngx.exit(ngx.HTTP_OK)
      end
    end

    ngx.sleep(0.5) -- next window
    local throttled = false
    for i=1,100 do
      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status == 429 then
        throttled = true
        goto continue1
      end
    end
    ::continue1::
    if not throttled then
      ngx.status = 500
      ngx.say("expected subsequent burst to be throttled")
    end

    for i=1,120 do
      -- ensure we are sending requests under the configured rate
      local jitter = math.random(10) / 10000
      local delay = 0.5 / 100 + jitter
      ngx.sleep(delay)

      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status ~= 200 then
        ngx.status = res.status
        ngx.say("expected all requests to be succeeded since they we being sent under the configured rate")
        return ngx.exit(ngx.HTTP_OK)
      end
    end

    throttled = false
    for i=1,100 do
      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status == 429 then
        throttled = true
        goto continue2
      end
      -- ensure we are sending requests over (delay < 0.5 / 100) the configured rate
      local delay = math.random(5) / 1000
      ngx.sleep(delay)
    end
    ::continue2::
    if not throttled then
      ngx.status = 500
      ngx.say("expected requests to be throttled because they were being sent faster than configured rate")
      return ngx.exit(ngx.HTTP_OK)
    end
    ngx.status = res.status
    ngx.print(res.body)
    ngx.exit(ngx.HTTP_OK)
  }
}
--- request
GET /t
--- response_body
throttled
--- error_code: 429
