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

=== TEST 1: throttle correctly counts samples and slides window
--- http_config eval: $::HttpConfig
--- config
location /protected {
  content_by_lua_block {
    local global_throttle = require "resty.global_throttle"
    local client_throttle = global_throttle.new(100, 1, { provider = "shared_dict", name = "counters" })

    local args, err = ngx.req.get_uri_args()
    if err then
      ngx.exit(500)
      return
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
    for i=1,100 do
      res = ngx.location.capture("/protected?api_client_id=1")
      if res.status ~= 200 then
        ngx.exit(500)
      end
    end
    res = ngx.location.capture("/protected?api_client_id=1")
    if res.status ~= 429 then
      return ngx.exit(500)
    end

    ngx.sleep(0.5) -- TODO(elvinefendi) come up with a better calculated number here
    res = ngx.location.capture("/protected?api_client_id=1")
    if res.status ~= 200 then
      return ngx.exit(500)
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
