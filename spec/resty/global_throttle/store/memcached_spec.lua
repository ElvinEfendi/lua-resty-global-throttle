local memcached_store = require("resty.global_throttle.store.memcached")

local function incr_and_assert(store, key, delta, expected_value, expiry)
  local new_value, err = store:incr(key, delta, expiry)

  assert.is_nil(err)
  assert.are.same(expected_value, new_value)

  local actual_value, flags, err = memcached.get(key)
  assert.are.same('0', flags)
  assert.are.same(expected_value, tonumber(actual_value))
end

describe("memcached", function()
  describe("new", function()
    it("requires host and port options", function()
      local store, err = memcached_store.new({})
      assert.is_nil(store)
      assert.are.equals("'host' and 'port' options are required", err)

      stire, err = memcached_store.new({ host = "127.0.0.1" })
      assert.is_nil(store)
      assert.are.equals("'host' and 'port' options are required", err)

      store, err = memcached_store.new({ port = "11211" })
      assert.is_nil(stire)
      assert.are.equals("'host' and 'port' options are required", err)

      store, err = memcached_store.new({ host = "127.0.0.1", port = "11211" })
      assert.is_not_nil(store)
      assert.is_nil(err)
    end)
  end)

  describe("incr and get", function()
    local store
    before_each(function()
      memcached.flush_all()

      local err
      store, err = memcached_store.new({ host = memcached.host, port = memcached.port })
      assert.is_nil(err)
    end)

    it("adds new key", function()
      incr_and_assert(store, "client1", 1, 1, 2)
    end)

    it("increments existing key", function()
      incr_and_assert(store, "client2", 1, 1, 2)
      incr_and_assert(store, "client2", 2, 3, 2)
    end)

    it("sets correct expiry", function()
      incr_and_assert(store, "client3", 1, 1, 1)
      ngx.sleep(1)
      local value, flags, err = memcached.get("client3")
      assert.is_nil(value)
      assert.is_nil(flags)
      assert.is_nil(err)
    end)

    it("returns value for existing key", function()
      local key = "client4"
      local expected_value = 2

      incr_and_assert(store, key, 2, expected_value, 4)

      local value, err = store:get(key)
      assert.is_nil(err)
      assert.are.same(expected_value, value)
    end)

    it("returns value for existing key", function()
      local key = "client4"
      local value, err = store:get(key)
      assert.is_nil(err)
      assert.is_nil(value)
    end)
  end)
end)
