-- Compact capture popup, opened explicitly by a key, button or IPC.
-- Captures close the drawer before a cancellable delay. Recording state
-- follows the child process; only that recording is stopped.
local morf = require("morf")
local theme = require("theme")
local config = require("config")
local drawer = require("drawer")
local M = {}
M.editor=require("capture_editor")
local screen = morf.screens and morf.screens[1] or { width = 1920, height = 1080 }
M.WIDTH = math.min(480, screen.width - theme.LEFT - theme.BORDER - 20)
M.target = morf.signal("caelestia.capture.target", "region")
M.delay = morf.signal("caelestia.capture.delay", 0)
M.recording = morf.signal("caelestia.capture.recording", false)
M.phase = morf.signal("caelestia.capture.phase", "ready")
M.message = morf.signal("caelestia.capture.message", "")
M.elapsed = morf.signal("caelestia.capture.elapsed", 0)
M.countdown = morf.signal("caelestia.capture.countdown", 0)
local pending, ticker, process, d
local sequence, generation = 0, 0
local function dry_run()
  local v = morf.env("CAELESTIA_DRY_RUN")
  return v and v ~= "" and v ~= "0"
end
local function expand(word)
  local home = morf.fs.home()
  return (tostring(word):gsub("^~/", function() return home .. "/" end):gsub("%$HOME", function() return home end))
end
function M.folder() return expand(config.get("capture.folder") or "~/Pictures/Captures") end
local function fail(message)
  M.message:set(message)
  M.phase:set("error")
  M.recording:set(false)
  if d then d.set(true) end
end
local function run(name, extra, done)
  local words = config.get("capture.commands." .. name)
  if type(words) ~= "table" or #words == 0 then
    fail("No command configured for " .. name .. ".")
    return false
  end
  sequence = sequence + 1
  local file = M.folder() .. "/capture_" .. morf.time.format("%Y%m%d_%H-%M-%S") .. ("_%03d"):format(sequence)
  local argv = {}
  for i, word in ipairs(words) do argv[i] = expand(word):gsub("%$FILE", function() return file end) end
  for _, word in ipairs(extra or {}) do argv[#argv + 1] = word end
  if dry_run() then
    morf.log("info", "caelestia: capture " .. name .. " (dry run): " .. table.concat(argv, " "))
    if done and name:match("^screenshot") then done { ok = true } end
    return true
  end
  if name ~= "open" then
    local ok, made, why = pcall(morf.fs.mkdir, M.folder())
    if not ok or not made then fail("Cannot create capture folder: " .. tostring(why or made)) return false end
  end
  local ok, child = pcall(morf.run, argv, {}, function(result)
    if done then done(result or { ok = false })
    elseif result and not result.ok then M.message:set(result.error or result.stderr or "Could not open capture.") end
  end)
  if not ok then fail(tostring(child)) return false end
  return true, child
end
function M.open(path) return run("open", { path or M.folder() }) end
local function stop_ticker()
  if ticker then ticker:cancel() ticker = nil end
end
function M.cancel()
  if M.editor.running() then M.editor.cancel() return true end
  if not pending then return false end
  generation = generation + 1
  pending:cancel() pending = nil
  stop_ticker()
  M.recording:set(false)
  M.phase:set("ready")
  M.countdown:set(0)
  return true
end
local function after_shutting(fn)
  if d then d.set(false) end
  if drawer.bottom then drawer.bottom.set(false) end
  local delay = M.delay:get() or 0
  M.phase:set("countdown")
  M.countdown:set(delay)
  stop_ticker()
  if delay > 0 then ticker = morf.timer(1000, function() M.countdown:set(math.max(0, M.countdown:get() - 1)) end, true) end
  pending = morf.timer(theme.duration.drawer_close + 50 + delay * 1000, function()
    pending = nil
    stop_ticker()
    fn()
  end, false)
end
local function checked(what)
  what = what or M.target:get()
  if what ~= "region" and what ~= "window" and what ~= "screen" then error("Choose region, window or screen") end
  return what
end
local function busy()
  local phase = M.phase:get()
  return phase ~= "ready" and phase ~= "error"
end
function M.shoot(what,quick)
  what = checked(what)
  if busy() then return "busy" end
  M.message:set("")
  if morf.broadcast then morf.broadcast("capture-claim",screen.name) end
  after_shutting(function()
    if config.get("capture.editor") and not quick and not dry_run() then
      M.phase:set("editing")
      M.editor.start(what,function(ok,message)
        if ok then M.phase:set("ready") M.message:set(message or "Capture closed.")
        else fail(message or "Capture failed.") end
      end)
      return
    end
    M.phase:set("saving")
    run("screenshot_" .. what, nil, function(result)
      if result.ok then M.phase:set("ready") M.message:set("Screenshot saved.")
      else fail(result.error or result.stderr or "Screenshot cancelled or failed.") end
    end)
  end)
  return what
end
function M.record(what)
  if M.recording:get() then
    if M.cancel() then return "stopped" end
    if M.phase:get() == "stopping" then return "stopping" end
    M.phase:set("stopping")
    if dry_run() then
      stop_ticker() M.recording:set(false) M.phase:set("ready")
    elseif process then
      local ok, sent = pcall(function() return process:kill("INT") end)
      if not ok or not sent then
        M.phase:set("recording")
        M.message:set("Could not stop the recorder. Try again.")
      end
    else
      fail("No recorder process is running.")
    end
    return "stopped"
  end
  if busy() then return "busy" end
  what = checked(what)
  M.message:set("") M.elapsed:set(0) M.recording:set(true)
  generation = generation + 1
  local current = generation
  after_shutting(function()
    M.phase:set("recording")
    local ok, child = run("record_" .. what, nil, function(result)
      if current ~= generation then return end
      local stopped = M.phase:get() == "stopping"
      process = nil
      stop_ticker()
      M.recording:set(false)
      if result.ok or (stopped and result.signal == 2) then
        M.phase:set("ready") M.message:set("Recording saved.")
      else fail(result.error or result.stderr or "Recording cancelled or failed.") end
    end)
    if not ok then return end
    if M.phase:get() ~= "recording" then return end
    process = child
    ticker = morf.timer(1000, function() M.elapsed:set(M.elapsed:get() + 1) end, true)
  end)
  return what
end
function M.height() return 264 end
M.drawer = drawer.new {
  name = "capture", edge = "bottom", width = M.WIDTH, height = M.height,
  content = require("capture_view").build(M, M.WIDTH, M.height), close_policy = "outside",
}
d = M.drawer
return M
