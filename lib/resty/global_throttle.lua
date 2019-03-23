local _M = { _VERSION = "0.1" }
local mt = { __index = _M }

function _M.new(self, opts)
  return setmetatable({
    name = opts.name
  }, mt)
end

function _M.process(self)
  return self.name
end

function _M.should_throttle(self)
  return true
end

return _M
