-- caelestia: a clean-room reimplementation of caelestia-dots/shell's look
-- and behaviour on morf, written from watching the original run (its
-- screenshots and films in a sandbox), not from its source. MIT.
--
-- The signature: a thin frame round the whole screen in the surface colour,
-- with rounded inner corners; the workspaces as pills down its left side; and drawers that
-- grow out of the frame with concave fillets -- the launcher at the bottom,
-- the dashboard at the top.
--
--     morf examples/shells/caelestia/shell/init.lua
--     morf ipc call launcher          -- toggle; or `launcher open`, `launcher close`
--     morf ipc call dashboard         -- the same; `session` too
--     morf ipc call close             -- every drawer
--
-- The frame, the rail and the drawers are one fullscreen layer surface; only
-- what can be clicked takes the pointer (the engine derives the input
-- region from the MouseAreas), so the desk under the opening stays usable.
-- The wallpaper, when the shell paints it (`wallpaper.draw`), is a
-- background layer of its own.

local morf = require("morf")
local ui = require("morf.ui")

local config = require("config")
local theme = require("theme")
local drawer = require("drawer")
local wallpaper = require("wallpaper")
local rail = require("rail")

-- Qt mixes translucent colours in sRGB; so does the original.
morf.surface.blend = "srgb"
morf.surface.namespace = "caelestia-drawers"
morf.surface.anchors = { top = true, bottom = true, left = true, right = true }
morf.surface.width = 0
morf.surface.height = 0
morf.surface.layer = "top"
morf.surface.keyboard_focus = "none"
-- The whole output, whatever other surfaces reserve (our own reservers
-- below among them).
morf.surface.exclusive_zone = -1
-- Windows keep inside the frame.

-- ------------------------------------------------------------------ colour --

-- Two palettes: `theme.color`, the Material scheme, built from
-- `theme.source` -- "lule" (the colour tool's accent: lule, pywal; see
-- terminal_colors.lua), "wallpaper", a colour, or "auto" (lule when it has
-- set anything, else the wallpaper) -- and `theme.lule`, the tool's own
-- colours as they are, for whatever wants them.
local terminal_colors = require("terminal_colors")
morf.effect("caelestia.lule", function() theme.apply_lule(terminal_colors.current:get()) end)
morf.effect("caelestia.scheme", function()
  local source = config.get("theme.source")
  local tool = terminal_colors.current:get()
  if (source == "auto" or source == "lule") and tool then
    theme.follow(tool.accent, nil, tool.mode)
  else
    theme.follow(source == "auto" and "wallpaper" or source, wallpaper.current:get())
  end
  -- The variant and mode are read inside `follow`; name them here so a
  -- change of either re-runs this.
  config.get("theme.variant")
  config.get("theme.mode")
end)

-- ------------------------------------------------------------------ scale --

-- The scale slider (quick settings): everything drawn bigger or smaller,
-- from -1 (half) through 0 (the compositor's own scale) to 1 (twice). The
-- windows follow at once; once the slider rests, the shell is built again
-- in place (no teardown: what is open stays open) so every layout -- a
-- panel's four fifths, a phone's column -- is worked out for the new size.
local function zoom()
  -- (A stand-in configuration, a test's, may have no `get`.)
  local v = config.get and tonumber(config.get("appearance.zoom")) or 0
  return math.max(-1, math.min(1, v))
end
local zoom_first, zoom_settle = true, nil
morf.effect("caelestia.scale", function()
  local v = zoom()
  if morf.density then morf.density(v ~= 0 and { zoom = 2 ^ v } or nil) end
  if zoom_first then zoom_first = false return end
  if zoom_settle then zoom_settle:cancel() end
  zoom_settle = morf.timer(300, function() zoom_settle = nil morf.reload() end, false)
end)

-- ---------------------------------------------------------------- drawers --

local launcher = require("launcher")
local dashboard = require("dashboard")
local session = require("session")
local polkit = require("polkit")
local keyring = require("keyring")
local authsteps = require("authsteps")
local headphones = require("headphones")
local osd = require("osd")
local notifs = require("notifs")
local sidebar = require("sidebar")
local leftbar = require("leftbar")
local capture = require("capture")
local bottom = require("bottom")
-- These two drawers occupy the same edge; only one can be open.
for _, pair in ipairs { { capture.drawer, bottom.drawer }, { bottom.drawer, capture.drawer } } do
  local own, other = pair[1], pair[2]
  function own.set(on)
    if on then other.open:set(false) end
    own.open:set(on and true or false)
  end
  function own.toggle() own.set(not own.open:get()) end
end
local keyboard = require("keyboard")
local bar = require("bar")

-- One policy for the shared surface. Closing a launcher or auth dialog
-- must not disable typing in the task editor that is still open.
morf.effect("caelestia.keyboard.focus", function()
  local exclusive = launcher.drawer.open:get() or session.drawer.open:get()
    or (polkit.drawer.open:get() and polkit.pending:get()) or keyring.drawer.open:get() or capture.editor.active:get()
  -- Typed into on a click: the planner, the terminal, Lule's page.
  local editor_open = leftbar.drawer.open:get()
    or (dashboard.drawer.open:get() and dashboard.tab:get() == dashboard.TERMINAL_TAB)
    or (sidebar.drawer.open:get() and require("utilities").displayed:get() == "theme/lule")
  morf.surface.keyboard_focus = exclusive and "exclusive" or editor_open and "on_demand" or "none"
end)

-- ------------------------------------------------------------------- frame --

-- Frame geometry and composition belong to the selected visual theme.
local rail_node=rail.build()
local levels=require("levels")
local levels_node=levels.build()
local overlays={
  -- The desk dims under the session menu.
  session.dim(),
  -- A press on the desk shuts what is open: each drawer's close policy
  -- (shell/drawer.lua), not catchers here.
}
local triggers=require("responsive").portrait() and {
  -- A phone: the top edge brings quick settings down, the bottom one the
  -- dashboard up; the side edges are left to the workspace gestures, and
  -- the planner and the assistant wait for theirs.
  require("hover").edge {
    name = "sidebar", drawer = sidebar.drawer, edge = "top",
    length = function() local _, _, w = bar.desk() return w - 2 * (theme.BORDER + theme.ROUNDING) end,
    setting = "sidebar.hover",
  },
  dashboard.edge_trigger(),
} or {
  dashboard.edge_trigger(),
  -- The bottom edge opens the tabbed assistant workspace.
  require("hover").edge {
    name = "bottom", drawer = bottom.drawer, edge = "bottom",
    length = bottom.width, setting = "bottom.hover",
    enabled = function()
      local phase = capture.phase:get()
      return not capture.drawer.open:get() and (phase == "ready" or phase == "error")
    end,
  },
  -- Near the right edge, anywhere down it, the sidebar opens; near the
  -- left edge (the rail's pills with it), the left panel.
  require("hover").edge {
    name = "sidebar", drawer = sidebar.drawer, edge = "right",
    from = function() return theme.BORDER + theme.ROUNDING end,
    length = function()
      local _, _, _, h = bar.desk()
      return h - 2 * (theme.BORDER + theme.ROUNDING)
    end,
    setting = "sidebar.hover",
  },
  require("hover").edge {
    name = "leftbar", drawer = leftbar.drawer, edge = "left",
    from = function() return theme.BORDER + theme.ROUNDING end,
    length = function()
      local _, _, _, h = bar.desk()
      return h - 2 * (theme.BORDER + theme.ROUNDING)
    end,
    setting = "leftbar.hover",
  },
}
local frame_view=require("themes").view("frame")
local frame_root=frame_view.build {desk=bar.desk,bar=bar.build(),drawers=drawer.all,
  rail={node=rail_node,shape=rail.shape},levels={node=levels_node,shape=levels.shape},
  overlays=overlays,triggers=triggers}
require("phone_gestures").attach(frame_root)
-- The shell's window, to a screen reader.
frame_root.accessible_name = "Caelestia"
ui.reparent(capture.editor.node,frame_root)
capture.editor.on_export=function(action,result)
  notifs.push {summary=action=="copy" and "Capture copied" or action=="save" and "Capture saved" or "Capture uploaded",
    body=action=="upload" and tostring(result or "Link copied to clipboard") or action=="save" and tostring(result or "") or "",app="Morf"}
end
-- Authentication can interrupt editing without ending up behind its overlay.
morf.effect("caelestia.capture.authentication",function()
  if (polkit.pending:get() or keyring.request:get()) and capture.editor.running() then capture.cancel() end
end)

-- Windows keep inside the opening: the frame, and the bar when it is up.
morf.effect("caelestia.bar.reserve", function()
  morf.surface.reserve = frame_view.insets(bar.insets())
end)

if config.get("wallpaper.draw") then wallpaper.open_layer() end

-- -------------------------------------------------------------------- ipc --

-- Every screen runs the shell and hears every verb. What opens appears on
-- the focused screen only (`services.here()`); a close shuts it wherever it
-- is. A screen that does nothing answers nothing, so the reply is the one
-- that acted.
-- Every verb is kept here as well as given to `morf.ipc` (which only
-- takes them), so the shell's keyboard shortcuts can call the same ones.
local ipc = setmetatable({}, { __newindex = function(t, k, v) rawset(t, k, v) morf.ipc[k] = v end })
local here = require("services").here
local function verb(d)
  return function(how)
    how = how or "toggle"
    if how == "close" then
      d.set(false)
      if here() then return d.is_open() end
      return
    end
    if how ~= "open" and how ~= "toggle" and how ~= "state" then
      error("`" .. tostring(how) .. "`: open, close, toggle or state")
    end
    if not here() then
      -- Opened elsewhere now: shut here, so one screen has it at a time.
      if how ~= "state" then d.set(false) end
      return
    end
    if how == "open" then d.set(true)
    elseif how == "toggle" then d.toggle() end
    return d.is_open()
  end
end

-- `launcher [how]`, or `launcher apps` / `launcher web`: the launcher on
-- one of the author's own menus (menus.lua: appy's apps, browsy's web).
ipc.launcher = function(how)
  if how == "apps" or how == "web" then
    if not here() then return nil end
    require("menus").open(how)
    launcher.drawer.set(true)
    return true
  end
  return verb(launcher.drawer)(how)
end
ipc.dashboard = verb(dashboard.drawer)
-- Builds the shell again from its files, in place.
ipc.reload = function() morf.reload() return true end
-- The scale, as the slider sets it: `scale -0.25` (smaller), `scale 0`
-- (the compositor's), `scale 0.5` (bigger), or nothing to ask.
ipc.scale = function(value)
  if value ~= nil then config.set("appearance.zoom", math.max(-1, math.min(1, tonumber(value) or 0))) end
  return config.get("appearance.zoom")
end
-- The screen as the shell sees it: its size in the shell's pixels, the
-- scale it is drawn at, and what the compositor and the panel say.
ipc.screen = function()
  local s = morf.screens[1] or {}
  return { width = s.width, height = s.height, scale = s.density_scale,
    logical_width = s.logical_width, pixel_width = s.pixel_width }
end
ipc["dashboard-history"] = function(output)
  local name = (morf.screens[1] or {}).name
  if output and output ~= name then return end
  local status = require("dashboard_state").history_status()
  status.output = name
  return status
end
ipc.session = verb(session.drawer)
-- `polkit` says whether this screen is the agent and what it is asking;
-- `polkit demo` opens the dialog on a made-up request (any password but
-- "wrong" is taken, and it goes nowhere). `view`, `answer` and `cancel`
-- are the screens talking to each other (polkit.lua).
ipc.polkit = function(how, ...)
  if how == "demo" then
    if not here() then return nil end
    polkit.demo()
    return true
  end
  if how == "cancel" and select("#", ...) == 0 then polkit.cancel() return true end
  if how == "view" or how == "answer" or how == "cancel" or how == "closed" then
    polkit.message(how, ...)
    return nil
  end
  -- The state, from the agent's screen.
  if not polkit.registered:get() then return nil end
  local r = polkit.request:get()
  return { agent = true, open = polkit.drawer.open:get(), phase = polkit.phase:get(), action = r and r.action or "" }
end

-- `auth-step STEP [SERVICE]`: the markers in a PAM stack (tools/pam)
-- saying where sudo has got to: face, finger, password, ok.
ipc["auth-step"] = function(step, service) return authsteps.steps.mark(step, service) end

-- `sidebar [how [TAB]]`: TAB is settings or notifications. `utilities`
-- is the sidebar on its settings; `settings PAGE` opens one of their pages
-- (network, bluetooth, sound).
ipc.sidebar = function(how, tab)
  if tab and here() then
    if not sidebar.select(tab) then error("`" .. tostring(tab) .. "`: no such tab") end
  end
  return verb(sidebar.drawer)(how)
end
ipc.utilities = function(how)
  if here() and how ~= "close" then sidebar.select("settings") end
  return verb(sidebar.drawer)(how)
end
ipc.settings = function(page)
  if not here() then return nil end
  if not require("utilities").request(page or "") then error("No such Settings page: " .. tostring(page)) end
  sidebar.select("settings")
  sidebar.drawer.set(true)
  return page or ""
end
ipc.leftbar = function(how, tab)
  if tab and here() and not leftbar.panel.select(tab) then error("No such left panel tab: " .. tostring(tab)) end
  return verb(leftbar.drawer)(how)
end
for _, tab in ipairs { "tasks", "calendar" } do
  ipc[tab] = function(how)
    if here() and how ~= "close" then leftbar.panel.select(tab) end
    return verb(leftbar.drawer)(how or "open")
  end
end
-- PrintScreen opens the original bottom capture panel. Screenshot/Record
-- choose the action and target there; only screenshots enter the editor.
local capture_popup=verb(capture.drawer)
ipc.capture = function(how)
  how=how or "toggle"
  if how=="menu" then how="open" end
  if how=="close" or ((how=="open" or how=="toggle") and capture.editor.running()) then capture.cancel() end
  return capture_popup(how)
end
ipc.bottom = function(how, tab)
  if tab and here() and not bottom.panel.select(tab) then error("No such bottom panel tab: " .. tostring(tab)) end
  return verb(bottom.drawer)(how)
end
ipc.assistant = function(how)
  if here() and how ~= "close" then bottom.panel.select("assistant") end
  return verb(bottom.drawer)(how or "open")
end
-- `keyboard [how]`: the on-screen keyboard, for a key to bind. `how` is
-- open, close, toggle or state, or a mode to open it in: full, dev,
-- letters, numbers, phone or pattern.
do
  local open_close = verb {set=keyboard.set,toggle=keyboard.toggle,is_open=keyboard.drawer.is_open}
  local MODES = { full = true, dev = true, letters = true, numbers = true, phone = true, pattern = true }
  ipc.keyboard = function(how)
    if MODES[how] then
      if not here() then return nil end
      keyboard.show(how)
      return true
    end
    return open_close(how)
  end
end
ipc["capture-claim"]=function(name)
  local own=(morf.screens or {})[1]
  if own and own.name~=name then capture.cancel() capture.drawer.set(false) end
end
ipc["capture-editor"] = function(action,...)
  if action=="cancel" then capture.cancel() return true end
  if not here() then return end
  if action=="tool" then capture.editor.choose(...) return true end
  if action=="copy" or action=="save" or action=="upload" then capture.editor.export(action) return true end
  return {open=capture.editor.active:get(),pending=capture.editor.pending:get(),busy=capture.editor.busy:get(),phase=capture.editor.phase:get()}
end
ipc.screenshot = function(what,how)
  if not here() then return nil end
  return capture.shoot(what,how=="quick")
end
ipc.record = function(what)
  if not here() then return nil end
  return capture.record(what)
end
ipc.workspace = function(n)
  if not here() then return nil end
  require("services").workspace.go(n)
  return require("services").workspace.active()
end
-- `lule open|close|toggle`: the studio. With no argument, keep the
-- existing terminal/accent diagnostics used by colour-tool integrations.
ipc.lule = function(how)
  if how then
    if here() and how ~= "close" then
      sidebar.select("settings")
      require("utilities").detail:set("theme/lule")
    end
    return verb(sidebar.drawer)(how)
  end
  local tty = require("terminal_colors").tty
  return tty and tty.path or "", theme.lule.accent:hex(), theme.color.primary:hex()
end
ipc.osd = function(kind)
  if not here() then return nil end
  osd.flash(kind)
  return true
end
-- `notify SUMMARY [BODY [critical|normal [APP]]]` raises a notification of
-- the shell's own, as the reference's toaster does.
ipc.notify = function(summary, body, urgency, app)
  return notifs.push { summary = summary, body = body, urgency = urgency == "critical" and 2 or 1, app = app }
end
ipc.close = function()
  capture.cancel()
  drawer.close_all()
  return true
end
-- `drawers` lists the open drawers; `drawers toggle NAME` (open, close)
-- acts on one by name, as the reference's IPC does.
ipc.drawers = function(how, name)
  if how ~= nil and how ~= "list" then
    local d = drawer[name or ""]
    if not d then error("`" .. tostring(name) .. "`: no such drawer") end
    return verb(d)(how)
  end
  local open = {}
  for _, d in ipairs(drawer.all) do
    if d.is_open() then open[#open + 1] = d.name end
  end
  return table.concat(open, " ")
end

-- Metadata only: never expose keyring answers through IPC.
ipc.keyring = function(how,mode)
  if here() then
    if how=="demo" then
      if mode and mode~="unlock" and mode~="new" and mode~="confirm" then
        error("Use `keyring demo [unlock|new|confirm]`.")
      end
      return keyring.demo(mode=="confirm" and "confirm" or "password",mode=="new")
    elseif how then error("Use `keyring` or `keyring demo [unlock|new|confirm]`.") end
    return {agent=keyring.registered:get(),open=keyring.drawer.open:get()}
  end
end


require("themes.switcher").start(function()
  if polkit.request:get() or keyring.request:get() or authsteps.steps.state.step ~= "idle" then
    return "Finish the authentication request before changing theme."
  end
  local phase = capture.phase:get()
  if phase ~= "ready" and phase ~= "error" then return "Finish the capture before changing theme." end
  if require("lule_studio").busy:get() then return "Wait for Lule to finish applying." end
  if require("planner").client.busy:get() then return "Wait for the task update to finish." end
end)

-- The verbs above as keys, wherever the shell has the keyboard.
frame_root.shortcuts = require("shortcuts").table(ipc)
