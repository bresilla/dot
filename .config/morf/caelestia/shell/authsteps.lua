-- Authentication marker state/watcher; themes own the status presentation.
local morf = require("morf")
local drawer = require("drawer")
local M = {}
M.steps = require("lib.util.authsteps").new()
M.steps.watch()
M.opened = morf.signal("caelestia.authsteps.opened",false)
local visual = require("themes").view("authsteps").build {state=M.steps.state,opened=M.opened}
M.drawer = drawer.new {name="authsteps",edge=visual.edge,width=visual.width,height=visual.height,
  content=visual.content,props=visual.props}
local here = require("services").here
local function active() return M.steps.state.step~="idle" and here() end
morf.effect("caelestia.authsteps.open",function()
  active() -- Subscribe to marker and focused-output changes.
  -- Read current state when the deferred update runs. An initial idle
  -- callback must not close a marker that arrived in the same frame.
  morf.timer(1,function() M.drawer.set(active()) end,false)
end)
morf.effect("caelestia.authsteps.presented",function() M.opened:set(M.drawer.open:get()) end)
return M
