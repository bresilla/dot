-- Visibility of named panels/pages, published by their controllers. Views
-- can gate decorative work without importing controllers during construction.
local morf = require("morf")
local M, scopes = {}, {}
local function scope(name)
  if not scopes[name] then scopes[name] = morf.signal("caelestia.presentation." .. name, false) end
  return scopes[name]
end
function M.set(name, shown) scope(name):set(shown == true) end
function M.active(name)
  assert(type(name) == "string", "a presentation scope is required")
  local state = scope(name)
  return function() return state:get() end
end
return M
