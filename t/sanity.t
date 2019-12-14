use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq(
    lua_package_path "$pwd/t/lib/?.lua;$pwd/lib/?.lua;;";
    lua_shared_dict counters 1M;
);

run_tests();

__DATA__

=== TEST 1: all cases
--- http_config eval: $::HttpConfig
--- config
location /protected {
  content_by_lua_block {
    local global_throttle = require "resty.global_throttle"
    local client_throttle = global_throttle.new(10, 0.2, { provider = "shared_dict", name = "counters" })

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

    ngx.log(ngx.NOTICE, "Expect spike to be allowed in the beginning.")
    for i=1,10 do
      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status ~= 200 then
        ngx.status = res.status
        return ngx.exit(ngx.HTTP_OK)
      end
    end

    ngx.log(ngx.NOTICE, "Expect no throttling since requests will be sent under the configured rate.")
    ngx.sleep(0.19) -- we have to wait here because the first 10 requests were sent too fast
    for i=1,12 do
      -- ensure we are sending requests under the configured rate
      local jitter = math.random(10) / 10000
      local delay = 0.2 / 12 + jitter
      ngx.sleep(delay)

      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status ~= 200 then
        ngx.status = res.status
        return ngx.exit(ngx.HTTP_OK)
      end
    end

    ngx.log(ngx.NOTICE, "Expect spike to be throttled because the algorithm remembers previous rate and smothen the load.")
    ngx.sleep(0.15)
    local throttled = false
    for i=1,10 do
      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status == 429 then
        throttled = true
        goto continue1
      end
    end
    ::continue1::
    if not throttled then
      ngx.status = 500
      return ngx.exit(ngx.HTTP_OK)
    end

    ngx.log(ngx.NOTICE, "Expect requests to be throttled because they will be sent faster.")
    ngx.sleep(0.15)
    throttled = false
    for i=1,15 do
      res = ngx.location.capture("/protected?api_client_id=2")
      if res.status == 429 then
        throttled = true
        goto continue2
      end
      -- ensure we are sending requests over the configured rate
      local delay = 0.15 / 15

      ngx.sleep(delay)
    end
    ::continue2::
    if not throttled then
      ngx.status = 500
      return ngx.exit(ngx.HTTP_OK)
    end

    ngx.log(ngx.NOTICE, "Expect spike when using different key because this will be the first spike.")
    for i=1,10 do
      res = ngx.location.capture("/protected?api_client_id=1")
      if res.status ~= 200 then
        ngx.status = res.status
        return ngx.exit(ngx.HTTP_OK)
      end
    end

    ngx.status = res.status
    ngx.print(res.body)
    ngx.exit(ngx.HTTP_OK)
  }
}
--- request
GET /t
--- response_body
--- error_code: 200
