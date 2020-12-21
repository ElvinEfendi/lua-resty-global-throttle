local memcached_host = os.getenv("MEMCACHED_HOST")
local memcached_port = os.getenv("MEMCACHED_PORT")

local memcached_store = require("resty.global_throttle.store.memcached")

local function with_memc(command)
  local memcached = require "resty.memcached"

  local memc, err = memcached:new()
  local ok, err = memc:connect(memcached_host, memcached_port)
  assert.is_nil(err)
  assert.are.same(1, ok)

  local ret1, ret2, ret3 = command(memc)

  memc:close()

  return ret1, ret2, ret3
end

local function flush_memcached_data()
  with_memc(function(memc)
    return memc:flush_all()
  end)
end

local function assert_in_memcached(expected_key, expected_value)
  local value, flags, err = with_memc(function(memc)
    return memc:get(expected_key)
  end)
  assert.is_nil(err)
  if expected_value == nil then
    assert.are.same(nil, flags)
    assert.is_nil(value)
  else
    assert.are.same('0', flags)
    assert.is_not_nil(value)
    assert.are.same(expected_value, tonumber(value))
  end
end

local function incr_and_assert(store, key, delta, expected_value, expiry)
  local value, err = store:incr(key, delta, expiry)

  assert.is_nil(err)
  assert.are.same(expected_value, value)

  assert_in_memcached(key, expected_value)
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
      flush_memcached_data()

      local err
      store, err = memcached_store.new({ host = memcached_host, port = memcached_port })
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
      assert_in_memcached("client3", nil)
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
