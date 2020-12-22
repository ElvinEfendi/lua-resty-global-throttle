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

local function get_counter_key(sample, ngx_now, window_size)
  return string.format("%s.%s.counter", sample, tostring(math.floor(ngx_now * 1000 / window_size)))
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

    it("correctly surfaces store errors")

    describe("when there's no previous window", function()
      it("returns precise number of occurences of a sample", function()
        local window_size = 1000
        local frozen_ngx_now = 1608261277.678
        local sample = "client1"

        ngx_freeze_time(frozen_ngx_now, function()
          local count, delay, err = sw:process_sample(sample)
          assert.is_nil(err)
          assert.is_nil(delay)
          assert.are.same(1, count)

          count, delay, err = sw:process_sample(sample)
          assert.is_nil(err)
          assert.is_nil(delay)
          assert.are.same(2, count)
        end)
      end)

      it("differentiates samples from one another")

      it("calculates correct delay when the limit is exceeding", function()
        local window_size = 1000
        local frozen_ngx_now = 1608261277.678
        local sample = "client1"
        local remaining

        ngx_freeze_time(frozen_ngx_now, function()
          local count, delay, err
          for i=1,5,1 do
            count, delay, err = sw:process_sample(sample)
            assert.is_nil(err)
            assert.is_nil(delay)
            assert.are.same(i, count)
          end

          local elapsed_time = 0.5
          ngx_time_travel(elapsed_time, function()
            count, delay, err = sw:process_sample(sample)
            assert.is_nil(err)
            assert.are.same(ngx.now() - elapsed_time, delay)
            assert.are.same(5, count)
          end)
        end)
      end)

      it("detects exceeding limit in case other sliding window instances increments counter right before the current instance increments")
    end)

    describe("when a window is over and a new one starts", function()
      it("returns estimated number of occurences of a sample based on rate from previous window")
      it("calculates correct delay when the limit is exceeding")
      it("looks back to only immediate previous window")
    end)
  end)
end)
