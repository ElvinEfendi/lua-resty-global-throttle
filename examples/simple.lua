local global_throttle = require "resty.global_throttle"

local simple_throttle = global_throttle:new({ name = "Simple throttle" })
simple_throttle:process()
