describe("global_throttle", function()
  local global_throttle

  before_each(function()
    ngx.shared.my_global_throttle:flush_all()
    global_throttle = require("resty.global_throttle")
  end)

  after_each(function()
    package.loaded["resty.global_throttle"] = nil
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
      it("does not throttle when within limits", function()
        local my_throttle, err = global_throttle.new(10, 2,
          { provider = "shared_dict", name = "my_global_throttle" } )

        local exceeding_limit, err
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client1")
        end

        assert.is_nil(err)
        assert.is_false(exceeding_limit)
      end)

      it("throttles when over limit", function()
        local my_throttle, err = global_throttle.new(10, 2,
          { provider = "shared_dict", name = "my_global_throttle" } )

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
        local my_throttle, err = global_throttle.new(10, 2,
          { provider = "shared_dict", name = "my_global_throttle" } )

        local exceeding_limit, err
        for i=1,10,1 do
          exceeding_limit, err = my_throttle:process("client1")
        end

        assert.is_nil(err)
        assert.is_false(exceeding_limit)

        ngx.sleep(1.5)

        exceeding_limit, err = my_throttle:process("client1")

        assert.is_nil(err)
        assert.is_false(exceeding_limit)
      end)
    end)

    describe("with memcached", function()
    end)
  end)
end)
