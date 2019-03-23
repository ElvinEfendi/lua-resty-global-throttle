use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq(
    lua_package_path "$pwd/t/lib/?.lua;$pwd/lib/?.lua;;";
);

run_tests();

__DATA__

=== TEST 1: hello, world
Description of test.
--- http_config eval: $::HttpConfig
--- config
location = /t {
  access_by_lua_block {
    local global_throttle = require "resty.global_throttle"

    local ip_throttle = global_throttle:new("ip_throttle", { rate = 200, window_size = 60, subject = "remote_addr" })
    ip_throttle:process()

    if ip_throttle:should_throttle() then
      ngx.status = 403
      ngx.say("hello, world!")
    end
  }
}
--- request
GET /t
--- response_body
hello, world!
--- error_code: 403
