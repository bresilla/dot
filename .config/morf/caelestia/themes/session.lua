-- One in-memory handoff for a visual-theme switch. No history or drafts on disk.
local morf = require("morf")
local bank = morf.reloadable("caelestia.theme.session", {})
local saved = bank:get()
local M = { restoring = saved.switching == true, target = saved.target, font = saved.font, transition = saved.transition }
local readers = {}
function M.keep(name, initial)
  local value = saved[name]
  if value == nil then value = initial end
  local signal = morf.signal(name, value)
  readers[name] = function() return signal:get() end
  return signal
end
function M.restore(name, initial)
  local value = saved[name]
  if value == nil then return initial end
  return value
end
function M.snapshot() return bank:get() end
function M.register(name, reader) readers[name] = reader end
function M.capture(target, font, transition)
  local values = { switching = true, target = target, font = font, transition = transition }
  for name, read in pairs(readers) do values[name] = read() end
  bank:set(values)
end
function M.finish()
  bank:set({ target = M.target, font = M.font })
  saved = {}
  M.restoring = false
end
function M.abort()
  bank:set({ target = M.target, font = M.font })
end
return M
