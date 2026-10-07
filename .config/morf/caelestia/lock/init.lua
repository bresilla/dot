-- caelestia's lock screen, in two stages -- a phone's, and a desk's too.
--
-- At rest it is a thing to look at: the time, large, the date and the
-- weather under it, whatever is playing as a row with its controls, and a
-- small swell on the frame's bottom edge saying where the way in is. A key,
-- a click or a swipe up and that swell rises into the unlock sheet -- one
-- liquid surface with the frame -- carrying the account in its cookie, the
-- pill for the password and whatever PAM has to say (a face being looked
-- for, a finger). The first key typed is already the password's. Escape on
-- an empty field, or a while with nothing typed, and the sheet sinks back.
-- On a phone (a screen taller than wide, or no keyboard attached) the sheet
-- carries the on-screen keyboard. The right password and all of it sinks
-- into the edge, the frame opens, and the desk is there again.
--
--   morf -c caelestia/lock               the lock, held under ext-session-lock
--   morf -c caelestia/lock -- window     the same, in a window, holding nothing
--
-- Its own file: nothing here reaches into the shell's folder. What the lock
-- and the greeter share is in the library -- lib.auth (PAM and greetd),
-- lib.accounts, lib.lule and lib.material for the colours, lib.osk.

local morf = require("morf")
local accounts = require("lib.services.accounts")
local auth = require("lib.util.auth")
require("themes.ui_scale").apply()

local HELD = morf.operands[1] ~= "window"
-- A fingerprint stack to listen on (tools/pam/readers.sh), said in the hint.
local FINGER = morf.fs.exists("/etc/pam.d/morf-lock-finger")
-- `-- window preview`: never asks PAM -- any password but "wrong" opens it.
-- For pictures and tests: a lock that asked PAM and was killed mid-way
-- would count as a failed login.
local PREVIEW = not HELD and morf.operands[2] == "preview"

local screen = morf.screens[1]
local W = (screen and screen.width) or 1920
local H = (screen and screen.height) or 1080
-- Everything in proportion to a 1080p screen.
-- A phone's design is the upright 1080 x 1920 one.
local s = require("themes.auth_metrics")(W, H, true)

morf.surface.width = W
morf.surface.height = H
morf.surface.anchors = { top = true, left = true, right = true, bottom = true }
morf.surface.layer = "overlay"
morf.surface.keyboard_focus = "exclusive"
-- Colours mix as the shell's do: a translucent tint is as faint as it says.
morf.surface.blend = "srgb"
morf.surface.namespace = "caelestia-lock"
morf.surface.session_lock = HELD

-- Visual design is selected independently from the wallpaper's palette.
local visual = require("themes").current
local C, palette = require("themes.auth_palette")("lock")
local FONT, ICONS = visual.tokens.auth_font or visual.tokens.font, visual.tokens.icon_font
local text, icon = require("themes.typography")(visual.tokens, C, s)
local tool = palette:get()
local WALLPAPER = tool and tool.wallpaper or ""
if WALLPAPER ~= "" and not morf.fs.exists(WALLPAPER) then WALLPAPER = "" end

-- ------------------------------------------------------------------ state --

local me = accounts.me() or { name = "", label = "", initial = "?" }
-- The password is a plain local: never a signal, never kept. The screen
-- needs only how many characters it has.
local password = ""
local typed = morf.signal("lock.typed", 0)
local busy = morf.signal("lock.busy", false)
local message = morf.signal("lock.message", "")
local bad = morf.signal("lock.bad", false)
local shake = morf.signal("lock.shake", 0)
-- "pattern" or "password": what the sheet takes (a pattern where one is set).
local method = morf.signal("lock.method", "password")
local has_pattern -- below, with the pattern pad
-- "closed" (coming in), "rest", "sheet" (the way in is open), "opening"
-- (unlocked: all of it going away).
local stage = morf.signal("lock.stage", "closed")
-- How far a swipe has pulled the sheet up, 0..1, while it is being drawn.
local pull = morf.signal("lock.pull", 0)

local function say(words, wrong)
  message:set(words or "")
  bad:set(wrong == true)
end
local function clear()
  password = ""
  typed:set(0)
end

local door
local function lift()
  stage:set("opening")
  say("")
  morf.timer(560, function()
    if HELD then morf.surface.session_lock = false else morf.quit() end
  end, false)
end
local handlers = {
  user = me.name,
  listen = false,
  on_busy = function(b) busy:set(b) end,
  on_info = function(words, wrong) if not busy:get() then say(words, wrong) end end,
  on_failed = function(why)
    say(why ~= "" and why or "Wrong password", true)
    clear()
    shake:set(1)
    morf.timer(70, function() shake:set(0) end, false)
  end,
  on_open = lift,
}
if PREVIEW then
  door = {
    submit = function(_, pw)
      handlers.on_busy(true)
      morf.timer(700, function()
        handlers.on_busy(false)
        if pw == "wrong" then handlers.on_failed("Wrong password") else lift() end
      end, false)
    end,
    listen = function() end, stop = function() end,
  }
else
  door = auth.lock(handlers)
end

-- Back to rest after a while with the sheet up and nothing typed.
local idle
local function poke()
  if idle then idle:cancel() end
  idle = morf.timer(15000, function()
    idle = nil
    if stage:get() == "sheet" and typed:get() == 0 and not busy:get() then
      stage:set("rest")
      say("")
    end
  end, false)
end

local function open_sheet()
  if stage:get() ~= "rest" then return end
  stage:set("sheet")
  pull:set(0)
  method:set(has_pattern() and "pattern" or "password")
  poke()
end

local function submit()
  if busy:get() or stage:get() ~= "sheet" then return end
  if password == "" then
    say("Type your password", false)
    return
  end
  say("")
  door:submit(password)
end

local MAX_DOTS = 18
local function type_text(t)
  if #password >= 256 then return end
  if method:get() == "pattern" then method:set("password") clear() end
  password = password .. t
  typed:set(math.min(#password, MAX_DOTS))
  if bad:get() then say("") end
  poke()
end
local function backspace()
  password = password:sub(1, -2)
  typed:set(math.min(#password, MAX_DOTS))
  poke()
end
local function escape()
  if #password == 0 then
    -- Looked at in a window, it holds nothing: Escape at rest is the way
    -- out, in case the door will not open.
    if stage:get() == "rest" and not HELD then morf.quit() return end
    stage:set("rest")
    say("")
  else
    clear()
    say("")
  end
end

-- --------------------------------------------------------------- the time --

local function now(format) return morf.time.format(format, morf.time.now()) end
local clock = morf.signal("lock.clock", now("%H:%M"))
local day = morf.signal("lock.day", now("%A, %-d %B"))
morf.timer(1000, function()
  clock:set(now("%H:%M"))
  day:set(now("%A, %-d %B"))
end, true)

-- The pattern, and the sources every screen's tree shares.
-- The pattern (tools/pattern): offered where the stack takes one and one
-- is set for this account. Anywhere else a drawn pattern would only be a
-- wrong password, and a failed login counted.
local PATTERN_STACK = (function()
  local ok, t = pcall(morf.fs.read, "/etc/pam.d/morf-lock")
  return ok and type(t) == "string" and t:find("morf-pattern-check", 1, true) ~= nil
end)()
function has_pattern()
  if PREVIEW then return true end
  local name = me.name
  return PATTERN_STACK and name ~= nil and name ~= "" and morf.fs.exists("/etc/morf/pattern/" .. name)
end
local function look()
  return {
    panel = function() return C.surfaceContainer end,
    key = function() return C.surfaceContainerHighest end,
    key_dim = function() return C.surfaceContainerHigh end,
    accent = function() return C.primary end,
    on_accent = function() return C.onPrimary end,
    text = function() return C.onSurface end,
    dim = function() return C.onSurfaceVariant end,
    press = function() return C.secondaryContainer end,
    font = FONT, icons = ICONS,
  }
end

-- The screen the lock is used on; the others show the frame, the desk and
-- the time, and nothing to press. Use the monitor focused when locking,
-- just like desktop authentication prompts; the first output is a fallback.
local main_output = morf.signal("lock.main", (morf.screens and morf.screens[1] and morf.screens[1].name) or "")
pcall(function()
  require("lib.integrations.hyprland").json("monitors", function(list)
    for _, m in ipairs(type(list) == "table" and list or {}) do
      if m.focused and m.name then main_output:set(m.name) return end
    end
  end)
end)

-- --------------------------------------------------------------- a screen --

-- One tree per screen, at that screen's size: a held lock covers every
-- output, and a laptop's panel and a 4K monitor each get their own layout.
-- What they share -- the password, the stage, the door -- is above.
local function pattern(dots)
  if busy:get() then return end
  if #dots < 4 then say("Connect at least four dots", false) return end
  password = table.concat(dots)
  submit()
end
local function key(keysym, typed_text)
        local RETURN, KP_ENTER, BACKSPACE, ESCAPE = 0xff0d, 0xff8d, 0xff08, 0xff1b
        local st = stage:get()
        if st ~= "rest" and st ~= "sheet" then return end
        if busy:get() then return end
        if keysym == ESCAPE then escape() return end
        -- Any other key at rest opens the way in. A character is the
        -- password's first; space, Return and the rest only wake it.
        if st == "rest" then
          open_sheet()
          if not (typed_text and typed_text ~= "" and typed_text:byte(1) > 32) then return end
        end
        if keysym == RETURN or keysym == KP_ENTER then
          submit()
        elseif keysym == BACKSPACE then
          backspace()
        elseif typed_text and typed_text ~= "" and typed_text:byte(1) >= 32 then
          type_text(typed_text)
        end
      end
local desktop = require("models.lock_desktop").new {
  active = function() return stage:get() == "rest" or stage:get() == "sheet" end,
  primary = function(output) return not HELD or main_output:get() == output end,
}
local context = {
  desktop = desktop,
  message = message, bad = bad, clear = clear,
  HELD = HELD,
  main_output = main_output,
  text = text,
  icon = icon,
  C = C,
  WALLPAPER = WALLPAPER,
  stage = stage,
  pull = pull,
  busy = busy,
  say = say,
  submit = submit,
  method = method,
  has_pattern = has_pattern,
  type_text = type_text,
  backspace = backspace,
  escape = escape,
  clock = clock,
  day = day,
  me = me,
  keyboard_attached = function()
    local ok, value = pcall(function() return require("lib.services.keyboards").attached() end)
    return not ok or value
  end,
  typed = typed,
  shake = shake,
  MAX_DOTS = MAX_DOTS,
  open_sheet = open_sheet,
  FINGER = FINGER,
  FONT = FONT,
  ICONS = ICONS,
  look = look,
  pattern = pattern,
  key = key,
}

local function build(width, height, name)
  local ctx = setmetatable({output_name=name}, {__index=context})
  ctx.s = require("themes.auth_metrics")(width, height, context.keyboard_attached())
  ctx.text, ctx.icon = require("themes.typography")(visual.tokens, C, ctx.s)
  return require(visual.lock)(ctx)(width, height, name)
end

-- Output removal must never leave the only password controls on a dead screen.
morf.effect("lock.outputs", function()
  if morf.screens_revision then morf.screens_revision() end
  local selected = main_output:get()
  for _, output in ipairs(morf.screens or {}) do
    if output.name == selected then return end
  end
  main_output:set((morf.screens[1] or {}).name or "")
end)

if HELD and morf.lock_surface then
  -- Called for each output, and again for one plugged in while locked.
  morf.lock_surface(function(output)
    return build(tonumber(output.width) or W, tonumber(output.height) or H, tostring(output.name or ""))
  end)
else
  -- Window/preview surfaces resize too. Keep the controller and its private
  -- draft, replacing only the output's presentation when logical size changes.
  local ui=require("morf.ui")
  local root=ui.Rect {id="lock-output",anchors={fill=true},color=function() return C.surface:alpha(1) end}
  local child,built_w,built_h
  morf.effect("lock.geometry",function()
    local width,height=root.layout_width or W,root.layout_height or H
    if width<=0 or height<=0 then width,height=W,H end
    width,height=math.floor(width+.5),math.floor(height+.5)
    if child and width==built_w and height==built_h then return end
    if child then ui.destroy(child,true) end
    built_w,built_h=width,height
    child=build(width,height,screen and screen.name or "")
    ui.reparent(child,root)
  end,{owner=root})
end

-- The readers (tools/pam): a finger from the start, even at rest -- touch
-- the sensor while the clock shows and the lock goes -- and a face only
-- while the sheet is up, so the camera is not kept on for a glance at the
-- time. With the sheet up they race, and the first yes opens the door.
morf.effect("lock.listen", function()
  local st = stage:get()
  if st == "sheet" then
    door:listen()
  elseif st == "rest" then
    door:stop("morf-lock-face")
    door:stop("morf-lock-reader")
    door:listen("morf-lock-finger")
  else
    door:stop()
  end
end)

-- In a window, `morf ipc call stage sheet` puts it where a test wants it;
-- a held lock answers no such thing.
if not HELD then
  morf.ipc.stage = function(to)
    if to == "sheet" then stage:set("rest") open_sheet() elseif to == "rest" then stage:set("rest") end
    return stage:get()
  end
end

-- In: the frame closes and the bud comes up out of it.
morf.timer(30, function() stage:set("rest") end, false)
