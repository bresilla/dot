-- caelestia's greeter, in two stages like the lock -- a phone's, and a
-- desk's too.
--
-- At rest: the time, the date, and the accounts as a row of cookies -- the
-- chosen one scalloped and turning -- over caelestia's shapes drifting on
-- a deep surface, the machine's name and the power buttons in the corners,
-- and a bud on the frame's bottom edge. The arrows or a click choose the
-- account; Return, a key, a click on the chosen one or a swipe up swells the
-- bud into the sheet: the account, the password pill, the session to start
-- (a chip; F2), what greetd says, and on a phone the on-screen keyboard.
-- Escape on an empty field sinks it back to choose someone else.
--
-- greetd runs it inside cage, as the user `greeter`:
--
--     [default_session]
--     command = "cage -m last -s -- /usr/bin/morf greet -c caelestia"      (or a bundle of it)
--     user = "greeter"
--
-- Nested, in a session already logged into, it draws the same and says there
-- is no greetd to ask:   cage -- morf -c caelestia/greet
--
-- Its own file. What it shares with the lock is in the library: lib.auth
-- (greetd's conversation), lib.accounts, lib.sessions, lib.material, lib.osk.

local morf = require("morf")
local accounts = require("lib.services.accounts")
local sessions = require("lib.services.sessions")
local auth = require("lib.util.auth")
require("themes.ui_scale").apply()

-- `-- preview`: as if a pattern were set, for pictures and tests.
local PREVIEW = morf.operands[1] == "preview"

local screen = morf.screens[1]
local W = (screen and screen.width) or 1920
local H = (screen and screen.height) or 1080
local function keyboard_attached()
  local ok, value = pcall(function() return require("lib.services.keyboards").attached() end)
  return not ok or value
end
local s = require("themes.auth_metrics")(W, H, keyboard_attached())

morf.surface.width = W
morf.surface.height = H
morf.surface.anchors = { top = true, left = true, right = true, bottom = true }
morf.surface.layer = "overlay"
morf.surface.keyboard_focus = "exclusive"
-- Colours mix as the shell's do: a translucent tint is as faint as it says.
morf.surface.blend = "srgb"
morf.surface.namespace = "caelestia-greet"

-- Visual design is selected independently from the wallpaper's palette.
local visual = require("themes").current
local C, palette = require("themes.auth_palette")("greet")
local FONT, ICONS = visual.tokens.auth_font or visual.tokens.font, visual.tokens.icon_font
local text, icon = require("themes.typography")(visual.tokens, C, s)
local tool = palette:get()
local WALLPAPER = tool and tool.wallpaper or ""
if WALLPAPER ~= "" and not morf.fs.exists(WALLPAPER) then WALLPAPER = "" end

-- ------------------------------------------------------------------ state --

local people = accounts.list()
if #people == 0 then people = { { name = "", label = "Nobody to log in", initial = "?" } } end
local list = sessions.list()

local who = morf.signal("greet.who", 1)
local which = morf.signal("greet.session", sessions.default_index(list))
local password = ""
local typed = morf.signal("greet.typed", 0)
local busy = morf.signal("greet.busy", false)
local message = morf.signal("greet.message", "")
local bad = morf.signal("greet.bad", false)
local shake = morf.signal("greet.shake", 0)
-- "pattern" or "password": what the sheet takes (a pattern where one is set).
local method = morf.signal("greet.method", "password")
local has_pattern -- below, with the pattern pad
-- "closed" (coming in), "rest" (choosing), "sheet" (the way in is open),
-- "leaving" (the session is starting).
local stage = morf.signal("greet.stage", "closed")
local pull = morf.signal("greet.pull", 0)
local outputs

local function person() return people[who:get()] or people[1] end
local function session() return list[which:get()] end

local function say(words, wrong)
  message:set(words or "")
  bad:set(wrong == true)
end
local function clear()
  password = ""
  typed:set(0)
end

local door = auth.greeter {
  enabled = not PREVIEW and morf.env("CAELESTIA_DRY_RUN") ~= "1",
  user = person().name,
  session = session(),
  on_busy = function(b) if b then busy:set(true) end end,
  on_info = function(words, wrong) say(words, wrong) end,
  on_failed = function(why)
    say(why ~= "" and why or "Wrong password", true)
    clear()
    shake:set(1)
    morf.timer(70, function() shake:set(0) end, false)
    if outputs then outputs.release() end
  end,
  -- The session is starting: everything sinks away while greetd replaces
  -- this process with it.
  on_open = function() stage:set("leaving") end,
}
local NOT_GREETD = "Not started by greetd: nothing to log in to"

local function choose(index)
  if busy:get() then return end
  if index == who:get() or not people[index] then return end
  who:set(index)
  clear()
  say("")
  door:switch(person().name)
end
local function step_person(by)
  if #people < 2 then return end
  choose(((who:get() - 1 + by) % #people) + 1)
end
local function step_session(by)
  if busy:get() then return end
  if #list < 2 then return end
  which:set(((which:get() - 1 + by) % #list) + 1)
  door.session = session()
end

local idle
local function poke()
  if idle then idle:cancel() end
  idle = morf.timer(30000, function()
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
  if not door.available then say(NOT_GREETD, false) end
  poke()
end

local function submit_owned()
  -- A pointer handoff or Escape can clear a draft while the public grant
  -- travels between output runtimes. Release it without contacting greetd.
  if stage:get()~="sheet" or password=="" then outputs.release() return end
  if not session() then
    say("No session installed to start", true)
    outputs.release()
    return
  end
  door.session = session()
  say("")
  door:submit(password)
end
local function submit()
  if busy:get() or stage:get() ~= "sheet" or password=="" then return end
  outputs.submit()
end

local MAX_DOTS = 20
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
  if #password > 0 then clear() say("") return end
  if stage:get() == "sheet" then stage:set("rest") say("") end
end

local function power(method, words)
  local ok, why = auth.power(method)
  if not ok then say(why or ("Could not " .. words), true) end
end

-- --------------------------------------------------------------- the time --

local function now(format) return morf.time.format(format, morf.time.now()) end
local clock = morf.signal("greet.clock", now("%H:%M"))
local day = morf.signal("greet.day", now("%A, %-d %B"))
morf.timer(1000, function()
  clock:set(now("%H:%M"))
  day:set(now("%A, %-d %B"))
end, true)

local PATTERN_STACK = (function()
  local ok, t = pcall(morf.fs.read, "/etc/pam.d/greetd")
  return ok and type(t) == "string" and t:find("morf-pattern-check", 1, true) ~= nil
end)()
function has_pattern()
  if PREVIEW then return true end
  local name = person().name
  return PATTERN_STACK and name ~= nil and name ~= "" and morf.fs.exists("/etc/morf/pattern/" .. name)
end
local function pattern(dots)
  if busy:get() then return end
  if #dots < 4 then say("Connect at least four dots", false) return end
  password = table.concat(dots)
  submit()
end
local function key(keysym, typed_text)
      local RETURN, KP_ENTER, BACKSPACE, ESCAPE = 0xff0d, 0xff8d, 0xff08, 0xff1b
      local LEFT, RIGHT, F2 = 0xff51, 0xff53, 0xffbf
      local st = stage:get()
      -- A real compositor key event proves this surface has the keyboard.
      -- Cage may focus a different output before delivering pointer entry.
      if outputs and not outputs.main() then outputs.claim() end
      if st ~= "rest" and st ~= "sheet" then return end
      if busy:get() then return end
      if keysym == ESCAPE then escape() return end
      if keysym == F2 then step_session(1) return end
      if st == "rest" then
        if keysym == LEFT then step_person(-1) return end
        if keysym == RIGHT then step_person(1) return end
        open_sheet()
        -- A character is the password's first; space, Return and the rest
        -- only open the sheet.
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
local hostname = ""
do
  local ok, name = pcall(morf.fs.read, "/proc/sys/kernel/hostname")
  if ok and type(name) == "string" then hostname = name:match("^%s*(.-)%s*$") end
end
-- Cage owns one fullscreen login window on its main output. Authentication
-- and keyboard focus stay here; pointer movement never transfers ownership.
outputs = require("models.greet_canvas_outputs") {
  busy=function(value) busy:set(value) end,
  submit=submit_owned,
}
local context = {
  main=outputs.main,
  claim=outputs.claim,
  hostname = hostname,
  message = message, bad = bad,
  W = W,
  H = H,
  s = s,
  C = C,
  FONT = FONT,
  ICONS = ICONS,
  text = text,
  icon = icon,
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
  people = people,
  person = person,
  session = session,
  list = list,
  who = who,
  which = which,
  keyboard_attached = keyboard_attached,
  typed = typed,
  shake = shake,
  MAX_DOTS = MAX_DOTS,
  open_sheet = open_sheet,
  power = power,
  step_person = step_person,
  step_session = step_session,
  choose = choose,
  clear = clear,
  pattern = pattern,
  key = key,
}
local ui=require("morf.ui")
local root=ui.Item {id="greet-output",anchors={fill=true}}
local child,built
morf.effect("greet.geometry",function()
  -- xdg_toplevel.configure is the authority for this window's logical size.
  -- Do not reconstruct a desktop from output metadata: it may arrive before
  -- Cage finishes disabling secondary monitors and disagree with this view.
  local width,height=root.layout_width or W,root.layout_height or H
  if width<=0 or height<=0 then return end
  width,height=math.floor(width+.5),math.floor(height+.5)
  local signature=tostring(width)..":"..tostring(height)
  if signature==built then return end
  built=signature
  if child then ui.destroy(child,true) end
  local ctx=setmetatable({W=width,H=height,output_name="main"}, {__index=context})
  ctx.s=require("themes.auth_metrics")(width,height,keyboard_attached())
  ctx.text,ctx.icon=require("themes.typography")(visual.tokens,C,ctx.s)
  child=require(visual.greet)(ctx)
  child.id="greet-view.main"
  child.anchors={fill=false}
  child.x,child.y,child.width,child.height=0,0,width,height
  ui.reparent(child,root)
end,{owner=root})
-- For a test or a picture: `morf ipc call stage sheet`.
morf.ipc.stage = function(to)
  if to == "sheet" then stage:set("rest") open_sheet() elseif to == "rest" then stage:set("rest") end
  return stage:get()
end

morf.timer(30, function() stage:set("rest") end, false)
