describe("global_throttle", function()
  local global_throttle

  setup(function()
    global_throttle = require("resty.global_throttle")
  end)

  describe("new", function()
    it("requires store parameter", function()
      local my_throttle, err = global_throttle.new(100, 5)

      assert.is_nil(my_throttle)
      assert.are.equals("'store_options' param is missing", err)
    end)

    it("requires store param to have provider attribute defined", function()
      local my_throttle, err = global_throttle.new(100, 5, {})

      assert.is_nil(my_throttle)
      assert.are.equals("error initiating the store: 'provider' attribute is missing", err)
    end)

    it("returns global throttle instance for Lua shared dict backend store", function()
      local my_throttle, err = global_throttle.new(100, 5, { provider = "shared_dict", name = "my_global_throttle" } )

      assert.is_nil(err)
      assert.is_not_nil(my_throttle)
    end)

    it("returns global throttle instance for memcached backend store", function()
      local my_throttle, err = global_throttle.new(100, 5,
        { provider = "memcached", host = os.getenv("MEMCACHED_HOST"), port = "11211" } )

      assert.is_nil(err)
      assert.is_not_nil(my_throttle)
    end)
  end)

  describe("process", function()
    describe("with Lua shared dict", function()
      local my_throttle

      before_each(function()
        local err
        my_throttle, err = global_throttle.new(10, 2,
          { provider = "shared_dict", name = "my_global_throttle" } )
        assert.is_nil(err)
      end)

      after_each(function()
        ngx.shared.my_global_throttle:flush_all()
      end)

      it("does not throttle when within limits", function()
        local exceeding_limit, err
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client1")
        end

        assert.is_nil(err)
        assert.is_false(exceeding_limit)
      end)

      it("throttles when over limit", function()
        local exceeding_limit, err
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client1")
        end

        assert.is_nil(err)
        assert.is_false(exceeding_limit)

        exceeding_limit, err = my_throttle:process("client1")

        assert.is_nil(err)
        assert.is_true(exceeding_limit)
      end)

      it("does not throttle if enough time passed", function()
        local exceeding_limit, err
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client1")
          assert.is_nil(err)
          assert.is_false(exceeding_limit)
        end

        -- make sure we go to next window
        ngx_time_travel(2.1, function()
          exceeding_limit, err = my_throttle:process("client1")
          assert.is_nil(err)
          assert.is_false(exceeding_limit)
        end)
      end)

      it("does not throttle when rate is under the limit", function()
        local exceeding_limit, err
        local offset = 0
        -- this is chosen based on window size / limit
        -- extra 0.05 seconds added to avoid race
        local step = 0.25
        for i=1,100,1 do
          ngx_time_travel(offset, function()
            exceeding_limit, err = my_throttle:process("client1")
            assert.is_nil(err)
            assert.is_false(exceeding_limit)
          end)
          offset = offset + step
        end
      end)

      it("does not allow spike in the subsequent window", function()
        local exceeding_limit, err
        local frozen_ngx_now = 1608261277.678
        -- Since we configured out throttler with the window size of 2 seconds,
        -- freezing time below means all requests in this loop happens in the
        -- window starting at 1608261276.000 and 1.678s have elapsed in that
        -- window so far.
        ngx_freeze_time(frozen_ngx_now, function()
          for i=1,10,1 do
            exceeding_limit, err = my_throttle:process("client1")
            assert.is_nil(err)
            assert.is_false(exceeding_limit)
          end
          assert.are.equals(frozen_ngx_now, ngx.now())

          -- make sure we go to next window
          -- stating at 1608261276.000 + 2 = 21608261278.000
          ngx_time_travel(2, function()
            for i=1,10,1 do
              exceeding_limit, err = my_throttle:process("client1")
              assert.is_nil(err)
            end
            assert.are.equals(frozen_ngx_now + 2, ngx.now())
          end)
        end)
        assert.is_true(exceeding_limit)
      end)

      it("shares counter between different instances given the same store", function()
        local exceeding_limit
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client1")
        end

        assert.is_nil(err)
        assert.is_false(exceeding_limit)

        local my_other_throttle, err = global_throttle.new(10, 2,
          { provider = "shared_dict", name = "my_global_throttle" } )
        assert.is_nil(err)
        
        exceeding_limit, err = my_other_throttle:process("client1")

        assert.is_nil(err)
        assert.is_true(exceeding_limit)
      end)
    end)

    describe("with memcached", function()
      local my_throttle

      before_each(function()
        local err
        my_throttle, err = global_throttle.new(10, 2, {
          provider = "memcached",
          host = os.getenv("MEMCACHED_HOST"),
          port = os.getenv("MEMCACHED_PORT"),
        })
        assert.is_nil(err)
      end)

      after_each(function()
        my_throttle.sliding_window.store:__flush_all()
      end)

      it("does not throttle when within limits", function()
        local exceeding_limit, err
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client1")
        end

        assert.is_nil(err)
        assert.is_false(exceeding_limit)
      end)

      it("throttles when over limit", function()
        local exceeding_limit, err
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client2")
        end

        assert.is_nil(err)
        assert.is_false(exceeding_limit)

        exceeding_limit, err = my_throttle:process("client2")

        assert.is_nil(err)
        assert.is_true(exceeding_limit)
      end)
    end)
  end)
end)
