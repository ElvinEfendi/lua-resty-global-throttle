local memcached_store = require("resty.global_throttle.store.memcached")
local sliding_window_new = require("resty.global_throttle.sliding_window").new

local function new_sliding_window(limit, window_size)
  local store, err = memcached_store.new({ host = memcached.host, port = memcached.port })
  assert.is_nil(err)
  assert.is_not_nil(store)

  local sw
  sw, err = sliding_window_new(store, limit, window_size)
  assert.is_nil(err)
  assert.is_not_nil(sw)

  return sw
end

describe("sliding_window", function()
  describe("new", function()
    it("requires 'store' argument", function()
    end)

    it("requires 'store' to response to 'incr' and 'get'", function()
    end)

    it("requires 'limit' argument", function()
    end)

    it("requires 'window_size' argument", function()
    end)

    it("is successful when all arguments are provided correctly", function()
    end)
  end)

  describe("process_sample", function()
    local sw
    before_each(function()
      memcached.flush_all()

      sw = new_sliding_window(5, 1000)
    end)

    it("increments counter for the given sample independent of instances", function()
      local window_size = 1000
      local frozen_ngx_now = 1608261277.678
      local sample = "client1"
      local counter_key = string.format("%s.%s.counter", sample, tostring(math.floor(frozen_ngx_now * 1000 / window_size)))

      ngx_freeze_time(frozen_ngx_now, function()
        local new_count, err = sw:process_sample(sample)
        assert.is_nil(err)
        assert.are.same(1, new_count)

        local new_sw = new_sliding_window(5, window_size)
        new_count, err = sw:process_sample(sample)
        assert.is_nil(err)
        assert.are.same(2, new_count)

        local actual_count, _, err = memcached.get(counter_key)
        assert.is_nil(err)
        assert.are.same(2, tonumber(actual_count))
      end)
    end)

    it("detects exceeding limit and calculates correct delay")
    it("detects exceeding limit and calculates correct delay when there's a previous window counter")
    it("detects exceeding limit even if the limit is exceeded only after current instance gets the counter value")
  end)
end)
