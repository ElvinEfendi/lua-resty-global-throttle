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
end)
