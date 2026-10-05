-- The polkit dialog: when a program asks for something only root may do
-- (starting a service, mounting a disk, pkexec), a panel drops out of the
-- frame's top edge asking for the password, and goes back up with the
-- verdict. The shell is the session's polkit agent (lib/polkit_agent.lua);
-- this is what it draws.
--
-- A session has one agent. While another holds the job (hyprpolkitagent,
-- polkit-gnome) the authority refuses this one, and it asks again every
-- minute, so it takes over as soon as the other is gone. `polkit.agent`
-- "off" leaves the job to the other for good.
--
-- Every screen runs the shell, and one of them (`morf.primary()`) is the
-- agent; the dialog opens on the screen in use. The agent tells every
-- screen how each request stands (`morf.broadcast("polkit", "view", ...)`),
-- the focused one draws it, and the answer goes back the same way to the
-- one holding the request -- inside this process, through the shell's own
-- IPC socket, never on a command line.
--
local morf = require("morf")
local ui = require("morf.ui")
local config = require("config")
local drawer = require("drawer")

local M = {}

local MAX_DOTS = 18
local RETRIES = 5

-- What is being asked, without the secret: `{ message, action, user,
-- prompt, echo }`, or false with nothing open.
M.request = morf.signal("caelestia.polkit.request", false)
-- "waiting" for PAM (including biometrics), then an actual input prompt.
M.phase = morf.signal("caelestia.polkit.phase", "waiting")
-- What PAM had to say ("touch the sensor", "wrong PIN"), or "".
M.info = morf.signal("caelestia.polkit.info", "")
local typed = morf.signal("caelestia.polkit.typed", 0)
M.opened = morf.signal("caelestia.polkit.opened", false)
M.pending = morf.signal("caelestia.polkit.pending", false)
M.registered = morf.signal("caelestia.polkit.registered", false)

-- The request this screen is showing, by id, and the password: plain
-- locals, never signals.
local viewing
local password = ""
local seen_failures = 0
local dismiss
local SUCCESS_HOLD = 2500
-- Broadcasts already queued before Cancel may arrive afterwards. Keep a
-- bounded set of completed IDs so they cannot reopen an abandoned dialog.
local retired, retirement_order = {}, {}
local function retire(id)
  if not id or retired[id] then return end
  retired[id] = true
  retirement_order[#retirement_order + 1] = id
  if #retirement_order > 128 then retired[table.remove(retirement_order, 1)] = nil end
end

function M.can_answer()
  local phase = M.phase:get()
  return M.opened:get() and (phase == "asking" or phase == "wrong")
end

local function dry_run()
  local v = morf.env and morf.env("CAELESTIA_DRY_RUN")
  return v ~= nil and v ~= "" and v ~= "0"
end

local keys
local function clear()
  password = ""
  typed:set(0)
  if keys then keys.text = "" end
end

-- To every screen, or to this one alone where there is no shell socket to
-- broadcast through (a headless test).
local send
local function close_view(id)
  retire(id)
  if id and viewing ~= id then return end
  viewing = nil
  if dismiss then dismiss:cancel() dismiss = nil end
  M.pending:set(false)
  keys.focus = false
  clear()
  M.drawer.set(false)
  M.request:set(false)
  M.info:set("")
end

function M.submit()
  if not viewing or not M.can_answer() then return end
  if password == "" then return end
  local answer = password
  clear()
  M.phase:set("checking")
  M.info:set("")
  send("answer", viewing, answer)
end

function M.cancel()
  local id = viewing
  -- Releasing input must never depend on a helper or another output replying.
  close_view(id)
  if id then send("cancel", id) end
end

function M.dismiss()
  if M.phase:get() ~= "done" and M.phase:get() ~= "refused" then return end
  close_view()
end

-- A kit password field, hidden: the view draws the dots.
local keys_node
keys_node, keys = require("kit").text_field("password", {
  id = "polkit-keys", reveal = false,
  width = 1, height = 1, opacity = 0, tab_navigation = false,
  password = true,
  read_only = function()
    return not M.can_answer()
  end,
  on_text_changed = function(text)
    password = text or ""
    typed:set(math.min(#password, MAX_DOTS))
    if M.phase:get() == "wrong" and #password > 0 then M.phase:set("asking") end
  end,
  on_accepted = function() M.submit() end,
  on_escape = function() if viewing then M.cancel() else M.dismiss() end end,
})


-- Themes see only request metadata, phase and the masked character count.
-- The hidden input and its raw text remain inside this controller.
local visual = require("themes").view("polkit").build {
  request=M.request, phase=M.phase, info=M.info, typed=typed, opened=M.opened,
  can_answer=M.can_answer,submit=M.submit, cancel=M.cancel,dismiss=M.dismiss,
  focus=function() keys.focus=M.can_answer() end,
}
function M.shake() visual.shake() end
ui.reparent(keys_node,visual.content)
M.drawer = drawer.new {name="polkit",edge=visual.edge,width=visual.width,height=visual.height,
  -- A dialog: only its own buttons and Escape answer it, Tab stays in it.
  close_policy="none",modal=true,
  content=visual.content,props=visual.props}
morf.effect("caelestia.polkit.open",function()
  local open=M.drawer.open:get()
  M.opened:set(open)
  keys.focus=open and M.pending:get()
  if not open then clear() end
end)
-- Closing animation is decorative: its children stop taking clicks at once.
visual.content.visible = function() return M.opened:get() end

-- --------------------------------------------------------------- the view --

local services = require("services")
local here = services.here

--- How a request stands, from the screen that holds it. The screen in use
--- opens the dialog on a request it has not seen; the rest leave it be.
local function view(id, message, action, user, prompt, phase, info, failures, output)
  if retired[id] then return end
  failures = tonumber(failures) or 0
  local final = phase == "done" or phase == "refused"
  if viewing ~= id then
    if final then return end
    if output and output~="" and services.output then
      if output~=services.output() then return end
    elseif not here() then return end
    viewing = id
    if dismiss then dismiss:cancel() dismiss=nil end
    seen_failures = 0
    clear()
    -- The dashboard hangs from the same edge.
    local ok, dashboard = pcall(require, "dashboard")
    if ok and dashboard.drawer then dashboard.drawer.set(false) end
    M.drawer.set(true)
  end
  M.request:set({
    message = (message and message ~= "") and message or "An application needs your authorization.",
    action = action or "", user = user or "", prompt = prompt or "",
  })
  M.phase:set(phase or "waiting")
  M.pending:set(not final)
  M.info:set(info or "")
  if failures > seen_failures then
    seen_failures = failures
    M.shake()
  end
  if final then
    retire(id)
    viewing = nil
    clear()
    if dismiss then dismiss:cancel() end
    dismiss=morf.timer(phase == "done" and SUCCESS_HOLD or 900, function()
      dismiss=nil
      if not viewing then
        M.drawer.set(false)
        M.request:set(false)
        M.info:set("")
      end
    end, false)
  end
end

-- ------------------------------------------------------------ the holder --

-- The requests this screen holds -- the agent's, or a demo's -- by id:
-- `{ request, phase, info, failures }`.
local held = {}
local count = 0

local function publish(id)
  local entry = held[id]
  if not entry then return end
  local r = entry.request
  send("view", id, r.message or "", r.action_id or "", r.user or "", r.prompt or "",
    entry.phase, entry.info, entry.failures, entry.output)
  if entry.phase == "done" or entry.phase == "refused" then held[id] = nil end
end

--- Takes a request in and says how it stands; `request.id` is its id here.
local function hold(request)
  if request._morf_closed then return end
  local id = request.id
  if not id then
    count = count + 1
    id = tostring(morf.screens and morf.screens[1] and morf.screens[1].name or "") .. "." .. count
    request.id = id
  end
  local entry = held[id]
  if not entry then
    entry = { request = request, phase = "waiting", info = "", failures = 0,
      output = services.active_output and services.active_output() or nil }
    held[id] = entry
  end
  -- What PAM said: a prompt, or a line to show ("look at the camera").
  if request.info and request.info ~= "" then
    entry.info = request.info
    if not request.prompt and request.info:lower():find("look at the camera",1,true) then entry.method="face" end
    request.info = nil
  end
  if request.prompt ~= nil then
    entry.phase,entry.method = "asking","prompt"
  elseif entry.phase ~= "checking" then entry.phase = "waiting" end
  publish(id)
end

local function wrong(request)
  local entry = held[request.id]
  if not entry then return end
  entry.phase = request.prompt ~= nil and "wrong" or "waiting"
  entry.info, entry.failures = "Authentication failed. Try again.", entry.failures + 1
  publish(request.id)
end

local function finished(request, ok, why)
  request._morf_closed = true
  local entry = held[request.id]
  if not entry then return end
  if not ok and why and tostring(why):find("cancel", 1, true) then
    held[request.id] = nil
    close_view(request.id)
    send("closed", request.id)
    return
  end
  entry.phase = ok and "done" or "refused"
  if ok then entry.info=entry.method=="face" and "Face verified · Access granted" or "Identity verified · Access granted"
  else entry.info=(why and not tostring(why):find("cancel")) and tostring(why) or "" end
  publish(request.id)
end

local function answer(id, pw)
  local entry = held[id]
  if not entry or entry.request.prompt == nil or (entry.phase~="asking" and entry.phase~="wrong") then return end
  entry.request.prompt = nil
  entry.phase, entry.info = "checking", ""
  publish(id)
  entry.request.answer(pw or "")
end

local function cancel(id)
  close_view(id)
  local entry = held[id]
  if not entry then return end
  held[id] = nil
  entry.request._morf_closed = true
  send("closed", id)
  local ok = pcall(entry.request.cancel)
  if not ok then morf.log("warn", "caelestia: polkit cancellation transport failed") end
end

--- Every screen's `polkit` verb, for what the screens say to each other.
function M.message(kind, ...)
  if kind == "view" then view(...)
  elseif kind == "answer" then answer(...)
  elseif kind == "cancel" then cancel(...)
  elseif kind == "closed" then close_view(...) end
end

function send(kind, ...)
  if morf.broadcast and morf.broadcast("polkit", kind, ...) then return end
  M.message(kind, ...)
end

--- A request as polkit would send one, for trying the dialog out
--- (`morf ipc call polkit demo`): any password but "wrong" is taken, and
--- it goes nowhere.
function M.demo()
  local fake = { action_id = "org.freedesktop.systemd1.manage-units", user = morf.env("USER") or "you",
    message = "Authentication is required to start 'tor.service'.", prompt = "Password: " }
  function fake.answer(pw)
    morf.timer(900, function()
      if pw == "wrong" then fake.prompt="Password: " wrong(fake) else finished(fake, true) end
    end, false)
  end
  function fake.cancel() finished(fake, false, "cancelled") end
  hold(fake)
end

-- -------------------------------------------------------------- the agent --

local agent
local function register()
  if agent or config.get("polkit.agent") == "off" or dry_run() then return true end
  -- One screen is the agent; the rest only ever draw.
  if morf.primary and not morf.primary() then return false, "not the primary screen" end
  local ok, lib = pcall(require, "lib.services.polkit_agent")
  if not ok then return true end
  local served, a, why = pcall(lib.serve, {
    retries = RETRIES,
    on_request = hold,
    on_failure = wrong,
    on_done = function(request, ok2, reason) finished(request, ok2, reason) end,
  })
  if served and a then
    agent = a
    M.registered:set(true)
    morf.log("info", "caelestia: the polkit agent")
    return true
  end
  return false, served and why or a
end

-- A moment after the shell is up, and then every minute while another
-- agent has the job (or this screen becomes the primary one).
local retry
morf.timer(1500, function()
  local ok, why = register()
  if ok then return end
  morf.log("info", "caelestia: not the polkit agent yet: " .. tostring(why))
  retry = morf.timer(60000, function()
    if register() and retry then retry:cancel() retry = nil end
  end, true)
end, false)

return M
