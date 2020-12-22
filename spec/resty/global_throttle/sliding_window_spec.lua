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

local function exhaust_limit_and_assert_without_previous_window(sw, sample, limit)
  for i=1,limit,1 do
    local estimated_count, delay, err = sw:process_sample(sample)
    assert.is_nil(err)
    assert.is_nil(delay)
    assert.are.same(i, estimated_count)
  end
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
    local limit = 5
    local window_size = 1
    local frozen_ngx_now = 1608261277.678
    local window_start = 1608261277 -- math.floor(frozen_ngx_now / window_size)
    local elapsed_time = 0.678 -- (frozen_ngx_now - window_start)
    local remaining_time = 0.322 -- (window_size - elapsed_time)
    local sample = "client1"
    local counter_key = get_counter_key(sample, frozen_ngx_now, window_size)

    before_each(function()
      memcached.flush_all()

      sw = new_sliding_window(limit, window_size)
    end)

    it("correctly surfaces store errors")

    describe("when there's no previous window", function()
      it("returns precise count and no delay when limit is not exceeding", function()
        ngx_freeze_time(frozen_ngx_now, function()
          local estimated_count, delay, err = sw:process_sample(sample)
          assert.is_nil(err)
          assert.is_nil(delay)
          assert.are.same(1, estimated_count)

          estimated_count, delay, err = sw:process_sample(sample)
          assert.is_nil(err)
          assert.is_nil(delay)
          assert.are.same(2, estimated_count)
        end)
      end)

      it("returns precise count and delay when limit is exceeding", function()
        ngx_freeze_time(frozen_ngx_now, function()
          exhaust_limit_and_assert_without_previous_window(sw, sample, limit)

          local estimated_count, delay, err = sw:process_sample(sample)
          assert.is_nil(err)
          assert.are.same(remaining_time, delay)
          assert.are.same(limit, estimated_count)
        end)
      end)

      it("differentiates samples from one another", function()
        ngx_freeze_time(frozen_ngx_now, function()
          exhaust_limit_and_assert_without_previous_window(sw, sample, limit)
          exhaust_limit_and_assert_without_previous_window(sw, "another_sample", limit)
        end)
      end)

      it("detects exceeding limit in case other sliding window instances increments counter right before the current instance increments", function()
        for i=1,(limit-2),1 do
          local estimated_count, delay, err = sw:process_sample(sample)
          assert.is_nil(err)
          assert.is_nil(delay)
          assert.are.same(i, estimated_count)
        end

        local mocked_memcached_store = require("resty.global_throttle.store.memcached")
        local original_memc_get = mocked_memcached_store.get
        local mocked_memc_get = function(self, key)
          local value, err = original_memc_get(key)
          memcached.with_client(function(memc)
            memc:incr(key, 2)
          end)
          return value, err
        end
        mocked_memcached_store.get = mocked_memc_get

        local store, err = mocked_memcached_store.new({ host = memcached.host, port = memcached.port })
        assert.is_nil(err)
        assert.is_not_nil(store)

        sw, err = sliding_window_new(store, limit, window_size)
        assert.is_nil(err)
        assert.is_not_nil(sw)

        local estimated_count, delay, err = sw:process_sample(sample)
        assert.is_nil(err)
        assert.are.same(remaining_time, delay)
        assert.are.same(limit + 1, estimated_count)
      end)
    end)

    describe("when a window is over and a new one starts", function()
      it("returns estimated count and no delay when limit is not exceeding", function()
        ngx_freeze_time(frozen_ngx_now, function()
          exhaust_limit_and_assert_without_previous_window(sw, sample, limit)

          -- we travel to the next window
          local new_elapsed_time = 0.2
          ngx_time_travel(remaining_time + new_elapsed_time, function()
            local estimated_count, delay, err = sw:process_sample(sample)
            assert.is_nil(err)
            -- in the previous window the rate was 5/1 = 5 occurences per second
            -- and in the current window we have had only one occurences of the sample
            -- so our estimated count for current window would be following
            local expected_estimated_count = 5 -- 0.8 * 5 + 1
            -- where 0.8 is (window_size - new_elapsed_time), i.e new remaining_time
            assert.are.same(expected_estimated_count, estimated_count)

            -- since limit is not exceeding, delay should be nil
            assert.is_nil(delay)
          end)
        end)
      end)

      it("returns estimated count and correct delay when limit is exceeding", function()
        ngx_freeze_time(frozen_ngx_now, function()
          exhaust_limit_and_assert_without_previous_window(sw, sample, limit)

          -- we travel to the next window
          local new_elapsed_time = 0.2
          ngx_time_travel(remaining_time + new_elapsed_time, function()
            local estimated_count, delay, err = sw:process_sample(sample)
            assert.is_nil(err)
            assert.is_nil(delay)

            estimated_count, delay, err = sw:process_sample(sample)
            assert.is_nil(err)

            -- in the previous window the rate was 5/1 = 5 occurences per second
            -- and in the current window we have had two occurences of the sample
            -- so our estimated count for current window would be following
            local expected_estimated_count = 6 -- 0.8 * 5 + 2
            -- where 0.8 is (window_size - new_elapsed_time), i.e new remaining_time
            assert.are.same(expected_estimated_count, estimated_count)

            -- since limit is exceeding, we will also have the following delay
            local expected_delay = 0.8 - (5 - 2) / 5
            -- the formula above is obtained by solving (0.8 - elapsed_time) * 5 + 2 = 5
            assert.are.same(expected_delay, delay)
          end)
        end)
      end)

      it("looks back at only immediate previous window", function()
        ngx_freeze_time(frozen_ngx_now, function()
          exhaust_limit_and_assert_without_previous_window(sw, sample, limit)

          -- travel to next to next window
          ngx_time_travel(remaining_time + window_size, function()
            exhaust_limit_and_assert_without_previous_window(sw, sample, limit)
          end)
        end)
      end)

      it("is aware that as a result of racy behaviour counter value can be over the limit but we still did not allow more than limit occurences of sample", function()
        local ok, err = memcached.with_client(function(memc)
          return memc:add(counter_key, limit + 1, window_size * 2)
        end)
        assert.is_nil(err)
        assert.is_true(ok)

        -- the above counter key was for previous window, and now we move to next window
        ngx_freeze_time(frozen_ngx_now + remaining_time + 0.1, function()
          local estimated_count, delay, err = sw:process_sample(sample)
          assert.is_nil(err)
          -- the main point in the below expectation is that previous rate is
          -- calculated as 5(correct counter value)/1 and not as 6(actual counter value)/1.
          local expected_estimated_count = 5 * 0.9 + 1
          assert.are.same(1, estimated_count)
          local expected_delay = 0.9 - (5 - 1) / 5
          assert.are.same(expected_delay, delay)
        end)
      end)
    end)
  end)
end)
