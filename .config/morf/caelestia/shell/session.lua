-- Session actions and navigation are shared; theme builders own their views.
local morf = require("morf")
local config = require("config")
local drawer = require("drawer")
local M = {}
M.actions = {
  {id="logout", icon="logout", name="Log out", detail="End this session"},
  {id="shutdown", icon="power_settings_new", name="Shut down", detail="Power off the computer"},
  {id="hibernate", icon="downloading", name="Hibernate", detail="Save the session to disk"},
  {id="reboot", icon="cached", name="Restart", detail="Reboot the computer"},
}
M.focus = morf.signal("caelestia.session.focus", 1)
M.opened = morf.signal("caelestia.session.opened", false)
M.username = morf.env("USER") or "user"
local face = morf.fs.home() .. "/.face"
M.picture = morf.fs.exists(face) and face or nil
local function dry_run()
  local v = morf.env and morf.env("CAELESTIA_DRY_RUN")
  return v ~= nil and v ~= "" and v ~= "0"
end

--- The command an action runs: a list of words, `$USER` read from the
--- environment.
function M.command(id)
  local words = config.get("session.commands." .. id)
  if type(words) ~= "table" then return nil end
  local user = (morf.env and morf.env("USER")) or ""
  local out = {}
  for i, w in ipairs(words) do out[i] = (tostring(w):gsub("%$USER", user)) end
  return out
end

--- Runs action `id` (shutting the menu first).
function M.run(id)
  local argv = M.command(id)
  M.drawer.set(false)
  if not argv or #argv == 0 then return false end
  if dry_run() then
    morf.log("info", "caelestia: session " .. id .. " (dry run): " .. table.concat(argv, " "))
    return true
  end
  morf.log("info", "caelestia: session " .. id .. ": " .. table.concat(argv, " "))
  morf.run(argv, {}, function(result)
    if result and not result.ok then
      morf.log("warn", "caelestia: session " .. id .. " failed: " .. tostring(result.stderr or result.code))
    end
  end)
  return true
end


function M.close() M.drawer.set(false) end
function M.accept() return M.run(M.actions[M.focus:get()].id) end
function M.key(_, _, _, _, key)
  local n = #M.actions
  if key == "Up" or key == "ISO_Left_Tab" then M.focus:set((M.focus:get()-2)%n+1) end
  if key == "Down" or key == "Tab" then M.focus:set(M.focus:get()%n+1) end
  return true
end
local view = require("themes").view("session").build(M)
M.drawer = drawer.new { name="session", edge=view.edge, width=view.width, height=view.height,
  content=view.content, props=view.props, close_policy="outside" }
M.dim = view.dim
morf.effect("caelestia.session.open", function()
  local on = M.drawer.open:get()
  M.opened:set(on)
  if on then M.focus:set(1) end
  view.shown(on)
end)
return M
