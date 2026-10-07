-- An on-screen keyboard, whole: for a shell on a desk, a phone and a lock
-- screen alike. The host places it and says which keyboard it wants; the
-- keyboard says what was struck.
--
--   local osk = require("lib.util.osk")
--   local kb = osk.new {
--     width = 900,                    -- laid out across this
--     mode = "full",                  -- see MODES
--     numbers = false,                -- "full": a number row over the letters (kb.numbers)
--     look = { ... },                 -- colours and face; see `look` below
--     send = osk.sender(),            -- where keys go (the default)
--     on_pattern = function(dots) end,-- "pattern": { 1, 5, 9, ... }
--   }
--   place(kb.node); height = kb.height   -- a function: it changes with the mode
--   kb.mode:set("numbers")
--
-- Optional theme hooks: `action(props)` constructs the pointer target and
-- `key_face(key)` (an option, or `look.key_face`) draws its face (id, width, height, kind, label(), icon(),
-- hint, down(), lit(), accent, dim, mirror). Faces do not handle input.
-- `metrics` can override gap, key_height and alternate_cell; `look` also
-- styles previews and pattern input. Defaults retain the original rendering.
-- `active()` gates interaction and cancels held keys when the host hides or
-- disables the board. Layout changes, kb.cancel() and kb.reset() cancel
-- pending repeats, previews and alternates as well.
-- Destroying the board also cancels them, including when a resized output
-- replaces its tree while a key is still held.
--
-- MODES
--   full      letters, the number row (hideable), two pages of symbols;
--             hold a key for its alternates (accents, the digit above it)
--   dev       laid out for code: Esc before the q-row, Tab and Del about
--             the a-row, and Ctrl, Alt, Super, space, arrows and Enter along
--             the bottom. Each letter offers two symbols on a long press,
--             with the first selected by default (digits on the top row). The
--             modifiers stick for one key, twice to lock
--   letters   letters only
--   numbers   a number pad
--   phone     a dial pad: digits, * # +
--   pattern   a 3x3 grid of dots, drawn through; says the dots on release
--
-- Everything a phone keyboard does: shift once, twice for caps lock; a
-- preview over the key while it is held; alternates on a long press, picked
-- by sliding along them; backspace, space and the arrows repeat when held.
--
-- A struck key goes to `send(event)`: `{ text = "é" }` for text, or
-- `{ key = "backspace" | "enter" | "tab" | "escape" | "left" | ..., mods }`
-- with `mods = { ctrl, alt, super, shift }`. `osk.sender` is the usual one:
-- text through the input method when a text field is asking (any character,
-- any layout), else as key presses on a virtual keyboard (ASCII, US layout
-- positions); keys, and anything with a modifier, always as key presses.

local morf = require("morf")
local ui = require("morf.ui")

local osk = {}

osk.MODES = { "full", "dev", "letters", "numbers", "phone", "pattern" }

-- ------------------------------------------------------------ the sender --

-- evdev codes, and US-layout positions for ASCII.
local KEYS = {
  escape = 1, backspace = 14, tab = 15, enter = 28, space = 57,
  left = 105, right = 106, up = 103, down = 108, home = 102, ["end"] = 107,
  pageup = 104, pagedown = 109, delete = 111, insert = 110,
  f1 = 59, f2 = 60, f3 = 61, f4 = 62, f5 = 63, f6 = 64, f7 = 65, f8 = 66, f9 = 67, f10 = 68, f11 = 87, f12 = 88,
}
local ASCII = {}
do
  local function put(chars, codes, shift)
    for i = 1, #chars do ASCII[chars:sub(i, i)] = { codes[i], shift } end
  end
  local letters = "qwertyuiopasdfghjklzxcvbnm"
  local lcodes = { 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44, 45, 46, 47, 48, 49, 50 }
  put(letters, lcodes, false)
  put(letters:upper(), lcodes, true)
  put("1234567890", { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, false)
  put("!@#$%^&*()", { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, true)
  put("-=[];'`\\,./", { 12, 13, 26, 27, 39, 40, 41, 43, 51, 52, 53 }, false)
  put("_+{}:\"~|<>?", { 12, 13, 26, 27, 39, 40, 41, 43, 51, 52, 53 }, true)
  ASCII[" "] = { 57, false }
end
-- xkb modifier masks: Shift, Control, Mod1 (Alt), Mod4 (Super).
local MASK = { shift = 1, ctrl = 4, alt = 8, super = 64 }

--- The usual sender. `options.ime` is a function saying whether a text
--- field is asking through the input method (text is committed there then);
--- without it, or when it says no, text goes as key presses.
function osk.sender(options)
  options = options or {}
  local vk = function() return morf.virtual_keyboard end
  local function press(code, mods)
    local k = vk()
    if not k then return end
    local mask = 0
    for name, on in pairs(mods or {}) do if on and MASK[name] then mask = mask | MASK[name] end end
    if mask ~= 0 then k.modifiers(mask, 0, 0, 0) end
    k.key(code, true)
    k.key(code, false)
    if mask ~= 0 then k.modifiers(0, 0, 0, 0) end
  end
  return function(e)
    local mods = e.mods or {}
    local modded = mods.ctrl or mods.alt or mods.super
    if e.text then
      local ime = options.ime and options.ime()
      if ime and not modded and morf.input_method and morf.input_method.commit then
        pcall(morf.input_method.commit, e.text)
        return
      end
      for _, codepoint in utf8.codes(e.text) do
        local char = utf8.char(codepoint)
        local at = ASCII[char] or (#char == 1 and ASCII[char:lower()])
        if at then
          local m = { ctrl = mods.ctrl, alt = mods.alt, super = mods.super, shift = at[2] or mods.shift }
          press(at[1], m)
        elseif morf.input_method and morf.input_method.commit then
          -- Not on the keyboard's keys: only a text field can take it.
          pcall(morf.input_method.commit, char)
        end
      end
    elseif e.key and KEYS[e.key] then
      press(KEYS[e.key], mods)
    end
  end
end

-- ---------------------------------------------------------------- layouts --

-- A key: `{ label, text?, key?, action?, w (units), alts?, hint?, repeat?, kind }`.
-- `kind`: "char" (a character, shifted with shift), "key" (a named key),
-- "action" (the keyboard's own: shift, a page, the mode, hide).
local function c(ch, alts, w) return { kind = "char", label = ch, text = ch, alts = alts, w = w or 1 } end
local function k(label, key, w, extra)
  local t = { kind = "key", label = label, key = key, w = w or 1 }
  for name, v in pairs(extra or {}) do t[name] = v end
  return t
end
local function a(label, action, w, extra)
  local t = { kind = "action", label = label, action = action, w = w or 1 }
  for name, v in pairs(extra or {}) do t[name] = v end
  return t
end
local function gap(w) return { kind = "gap", w = w } end

-- What a long press offers, the first also the key's small hint.
local ALTS = {
  q = { "1" }, w = { "2" }, e = { "3", "è", "é", "ê", "ë", "ē", "€" }, r = { "4" }, t = { "5", "þ" },
  y = { "6", "ý", "ÿ", "¥" }, u = { "7", "ù", "ú", "û", "ü", "ū" }, i = { "8", "ì", "í", "î", "ï", "ī" },
  o = { "9", "ò", "ó", "ô", "ö", "õ", "ø", "œ" }, p = { "0", "¶" },
  a = { "@", "á", "à", "â", "ä", "ã", "å", "æ", "ā" }, s = { "#", "ß", "ś", "š", "$" }, d = { "&", "ð" },
  f = { "*" }, g = { "-", "ğ" }, h = { "+" }, j = { "=" }, k = { "(" }, l = { ")", "ł" },
  z = { "_", "ž", "ź", "ż" }, x = { "$" }, c = { "\"", "ç", "ć", "č", "©" }, v = { "'" }, b = { ":" },
  n = { ";", "ñ", "ń" }, m = { "/", "µ" },
  ["1"] = { "!", "¹", "½", "⅓", "¼" }, ["2"] = { "@", "²", "⅔" }, ["3"] = { "#", "³", "¾" }, ["4"] = { "$", "⁴" },
  ["5"] = { "%", "⁵" }, ["6"] = { "^" }, ["7"] = { "&" }, ["8"] = { "*" }, ["9"] = { "(" }, ["0"] = { ")", "∅", "ⁿ" },
  ["."] = { ",", "?", "!", "'", "\"", ":", ";", "…", "-", "/" }, [","] = { ";", ":", "…" },
  ["$"] = { "€", "£", "¥", "¢", "₹", "₩" }, ["-"] = { "–", "—", "_", "·" }, ["?"] = { "¿" }, ["!"] = { "¡" },
  ["\""] = { "“", "”", "«", "»" }, ["'"] = { "‘", "’", "‚", "‹", "›" }, ["%"] = { "‰" }, ["+"] = { "±" },
  ["="] = { "≠", "≈", "∞" }, ["<"] = { "≤", "«", "‹" }, [">"] = { "≥", "»", "›" }, ["/"] = { "\\", "÷" },
  ["*"] = { "†", "‡", "★" }, ["("] = { "[", "{", "<" }, [")"] = { "]", "}", ">" },
}
local function ch(char, w) return c(char, ALTS[char], w) end

local function row(chars) local out = {} for i = 1, #chars do out[#out + 1] = ch(chars:sub(i, i)) end return out end
-- Dev stays on one page. Hold for the first symbol, or slide to the second;
-- the ordinary keyboard keeps its longer accented-character menus.
local DEV_ALTS = {
  q = { "1", "!" }, w = { "2", "@" }, e = { "3", "#" }, r = { "4", "$" }, t = { "5", "%" },
  y = { "6", "^" }, u = { "7", "&" }, i = { "8", "*" }, o = { "9", "(" }, p = { "0", ")" },
  a = { "@", "&" }, s = { "#", "|" }, d = { ":", ";" }, f = { "\\", "`" }, g = { "-", "_" },
  h = { "+", "=" }, j = { "'", "\"" }, k = { "(", "{" }, l = { ")", "}" },
  z = { "[", "]" }, x = { "<", ">" }, c = { "=", "!" }, v = { "$", "%" },
  b = { ".", "," }, n = { "~", "^" }, m = { "/", "?" },
}
local function dev_row(chars)
  local out = {}
  for i = 1, #chars do
    local char = chars:sub(i, i)
    local key = c(char, DEV_ALTS[char])
    key.dual_hints = true
    out[#out + 1] = key
  end
  return out
end
local function with(list, ...) for _, v in ipairs({ ... }) do list[#list + 1] = v end return list end
local function front(list, ...) local out = { ... } for _, v in ipairs(list) do out[#out + 1] = v end return out end

local BACKSPACE = k("⌫", "backspace", 1.5, { rep = true, dim = true, icon = "backspace" })
local ENTER = k("⏎", "enter", 1.5, { accent = true, icon = "keyboard_return" })
local SPACE = function(w) return k("", "space", w, { rep = true, text = " " }) end

local PAGES = {}
PAGES.numrow = row("1234567890")
PAGES.letters = {
  row("qwertyuiop"),
  front(with(row("asdfghjkl"), gap(0.5)), gap(0.5)),
  front(with(row("zxcvbnm"), BACKSPACE), a("⇧", "shift", 1.5, { dim = true, icon = "shift" })),
  { a("?123", "page:symbols", 1.5, { dim = true }), ch(","), SPACE(5), ch("."), ENTER },
}
PAGES.letters_only = {
  PAGES.letters[1], PAGES.letters[2], PAGES.letters[3],
  { ch(","), SPACE(6.5), ch("."), ENTER },
}
PAGES.symbols = {
  row("1234567890"),
  row("@#$_&-+()/"),
  front(with(row("*\"':;!?"), BACKSPACE), a("=\\<", "page:symbols2", 1.5, { dim = true })),
  { a("ABC", "page:letters", 1.5, { dim = true }), ch(","), SPACE(5), ch("."), ENTER },
}
PAGES.symbols2 = {
  { ch("~"), ch("`"), ch("|"), ch("•"), ch("√"), ch("π"), ch("÷"), ch("×"), ch("¶"), ch("∆") },
  { ch("£"), ch("¢"), ch("€"), ch("¥"), ch("^"), ch("°"), ch("="), ch("{"), ch("}"), ch("\\") },
  front(with({ ch("%"), ch("©"), ch("®"), ch("™"), ch("✓"), ch("["), ch("]") }, BACKSPACE),
    a("?123", "page:symbols", 1.5, { dim = true })),
  { a("ABC", "page:letters", 1.5, { dim = true }), ch("<"), SPACE(5), ch(">"), ENTER },
}
-- dev: laid out as a keyboard for code is -- the symbols a shell wants on
-- top, Tab before the a-row, and the modifiers and arrows along the bottom
-- where the thumbs are.
PAGES.dev = {
  front(dev_row("qwertyuiop"), k("esc", "escape", 1, { dim = true })),
  with(front(dev_row("asdfghjkl"), k("tab", "tab", 1, { dim = true, icon = "keyboard_tab" })),
    k("del", "delete", 1, { rep = true, dim = true })),
  front(with(dev_row("zxcvbnm"), k("⌫", "backspace", 2, { rep = true, dim = true, icon = "backspace" })),
    a("⇧", "shift", 2, { dim = true, icon = "shift" })),
  { a("ctrl", "mod:ctrl", 1.2, { dim = true }), a("alt", "mod:alt", 1.2, { dim = true }),
    a("sup", "mod:super", 1.2, { dim = true }), SPACE(3.2),
    k("←", "left", 0.75, { rep = true, dim = true, icon = "arrow_back" }),
    k("↓", "down", 0.75, { rep = true, dim = true, icon = "arrow_downward" }),
    k("↑", "up", 0.75, { rep = true, dim = true, icon = "arrow_upward" }),
    k("→", "right", 0.75, { rep = true, dim = true, icon = "arrow_forward" }),
    k("⏎", "enter", 1.2, { accent = true, icon = "keyboard_return" }) },
}
PAGES.dev_keys = {
  k("esc", "escape", 1, { dim = true }), k("tab", "tab", 1, { dim = true, icon = "keyboard_tab" }),
  a("ctrl", "mod:ctrl", 1, { dim = true }), a("alt", "mod:alt", 1, { dim = true }), a("sup", "mod:super", 1, { dim = true }),
  k("←", "left", 1, { rep = true, dim = true, icon = "arrow_back" }),
  k("↓", "down", 1, { rep = true, dim = true, icon = "arrow_downward" }),
  k("↑", "up", 1, { rep = true, dim = true, icon = "arrow_upward" }),
  k("→", "right", 1, { rep = true, dim = true, icon = "arrow_forward" }),
  k("⌦", "delete", 1, { rep = true, dim = true, icon = "backspace", mirror = true }),
}
PAGES.dev_symbols = row("-/|~`{}[]\\")
PAGES.numbers = {
  { ch("1"), ch("2"), ch("3"), ch("-") },
  { ch("4"), ch("5"), ch("6"), k("", "space", 1, { rep = true, text = " ", dim = true, icon = "space_bar" }) },
  { ch("7"), ch("8"), ch("9"), k("⌫", "backspace", 1, { rep = true, dim = true, icon = "backspace" }) },
  { ch(","), ch("0"), ch("."), k("⏎", "enter", 1, { accent = true, icon = "keyboard_return" }) },
}
PAGES.phone = {
  { ch("1"), ch("2"), ch("3") },
  { ch("4"), ch("5"), ch("6") },
  { ch("7"), ch("8"), ch("9") },
  { ch("*"), c("0", { "+" }), ch("#") },
  { c("+"), k("⌫", "backspace", 1, { rep = true, dim = true, icon = "backspace" }),
    k("⏎", "enter", 1, { accent = true, icon = "keyboard_return" }) },
}

-- ------------------------------------------------------------------ build --

function osk.new(options)
  -- A shell may supply its themed key target; input semantics stay here.
  local action = options.action or ui.MouseArea
  local touch = options.touch
  local NAME = options.prefix or "osk"
  local function named(s) return NAME .. "." .. s end
  local W = options.width
  local look = options.look or {}
  local function col(name, fallback)
    local v = look[name]
    if v == nil then v = fallback end
    return function() if type(v) == "function" then return v() end return v end
  end
  local PANEL = col("panel", morf.color("#101418"))
  local KEY = col("key", "#262b33")
  local KEY_DIM = col("key_dim", "#1c2027")
  local ACCENT = col("accent", "#9ccbfb")
  local ON_ACCENT = col("on_accent", "#0b1d2e")
  local TEXT = col("text", "#e6e9ef")
  local DIM = col("dim", "#9aa3b2")
  local PRESS = col("press", "#3a4150")
  local FONT = look.font or "sans-serif"
  -- Material Symbols (or any icon font with those names) for the keys that
  -- are symbols: backspace, return, shift, the arrows. Without one they
  -- are drawn as their characters.
  local ICONS = look.icons
  -- A theme's key face: the option, or the look's own (a kit's
  -- keyboard_look may carry one).
  local KEY_FACE = options.key_face or look.key_face
  local send = options.send or osk.sender()
  local on_pattern = options.on_pattern or function() end

  local metrics = options.metrics or {}
  local GAP = metrics.gap or math.max(4, math.floor(W / 150))
  local UNIT = (W - 11 * GAP) / 10
  local KH = metrics.key_height or math.floor(math.max(40, math.min(64, UNIT * 1.12)))
  local RADIUS = look.radius or math.floor(KH * 0.28)
  local LABEL = math.floor(KH * 0.42)
  local SMALL = math.floor(KH * 0.26)

  local mode = morf.signal(named("mode"), options.mode or "full")
  -- The number row over the letters: off unless asked for (the digits are
  -- on the top row's long press, and on ?123).
  local numbers = morf.signal(named("numbers"), options.numbers == true)
  local page = morf.signal(named("page"), "letters")
  local shift = morf.signal(named("shift"), "off") -- off, once, lock
  local mods = { ctrl = morf.signal(named("ctrl"), "off"), alt = morf.signal(named("alt"), "off"),
    super = morf.signal(named("super"), "off") }

  local function rows_for(m, p)
    if m == "numbers" then return PAGES.numbers end
    if m == "phone" then return PAGES.phone end
    if m == "letters" then return PAGES.letters_only end
    if m == "dev" and p == "letters" then return PAGES.dev end
    local base = PAGES[p] or PAGES.letters
    local out = {}
    if p == "letters" and numbers:get() and m ~= "letters" then out[#out + 1] = PAGES.numrow end
    for _, r in ipairs(base) do out[#out + 1] = r end
    return out
  end

  local function body_height(m, p)
    if m == "pattern" then return math.floor(math.min(W, KH * 7)) end
    local n = #rows_for(m, p)
    return n * KH + (n - 1) * GAP
  end
  local function height()
    return body_height(mode:get(), page:get()) + 2 * GAP
  end

  -- -------------------------------------------------------- striking --
  local function held_mods()
    local out = {}
    for name, s in pairs(mods) do if s:get() ~= "off" then out[name] = true end end
    return out
  end
  local function after_strike()
    if shift:get() == "once" then shift:set("off") end
    for _, s in pairs(mods) do if s:get() == "once" then s:set("off") end end
  end
  local function shifted(text)
    if shift:get() ~= "off" then return text:upper() end
    return text
  end
  local function strike_text(text)
    local m = held_mods()
    send { text = text, mods = m }
    after_strike()
  end
  local function strike_key(key)
    local m = held_mods()
    if shift:get() ~= "off" then m.shift = true end
    send { key = key, mods = m }
    after_strike()
  end
  local last_shift = 0
  local function cycle(sig, now)
    local state = sig:get()
    if state == "off" then sig:set("once")
    elseif state == "once" then
      -- Twice quickly: locked.
      if now - last_shift < 400 then sig:set("lock") else sig:set("off") end
    else sig:set("off") end
  end
  local clock = morf.elapsed_timer()
  local function act(action)
    if action == "shift" then
      local now = clock:elapsed_ms()
      cycle(shift, now)
      last_shift = now
    elseif action:match("^page:") then
      page:set(action:sub(6))
      shift:set("off")
    elseif action:match("^mod:") then
      local name = action:sub(5)
      local now = clock:elapsed_ms()
      cycle(mods[name], now)
      last_shift = now
    end
  end

  -- -------------------------------------------------- the overlay bits --
  -- One preview bubble and one alternates strip for the whole board,
  -- placed over whichever key holds them.
  local preview = { on = morf.signal(named("preview"), false), x = morf.signal(named("preview.x"), 0),
    y = morf.signal(named("preview.y"), 0), w = morf.signal(named("preview.w"), 0), text = morf.signal(named("preview.text"), "") }
  local alts = { list = morf.signal(named("alts"), {}), x = morf.signal(named("alts.x"), 0), y = morf.signal(named("alts.y"), 0),
    pick = morf.signal(named("alts.pick"), 1) }
  local CELL = metrics.alternate_cell or math.floor(KH * 0.9)

  local body_top = GAP
  local cancellations = {}
  local function enabled() return not options.active or options.active() end

  --- One key at (x, y) of w, as a pointer target with its face and label.
  local function key_node(spec, x, y, w, mode_name, page_name)
    local what = spec.kind == "char" and spec.label or spec.key or spec.action or tostring(x)
    local id = named("key." .. mode_name .. "." .. page_name .. "." .. what)
    local down = morf.signal(id .. ".down", false)
    local long_timer, repeat_timer, long, held = nil, nil, false, false
    local touching, repeated = false, false
    local function label()
      if spec.kind == "char" then return shifted(spec.label) end
      if spec.action == "shift" then return shift:get() == "lock" and "⇪" or "⇧" end
      return spec.label
    end
    local function lit()
      if spec.action == "shift" then return shift:get() ~= "off" end
      if spec.action and spec.action:match("^mod:") then return mods[spec.action:sub(5)]:get() ~= "off" end
      return false
    end
    -- Reserve a separate line for the paired hints on compact dev keys.
    local face_label=spec.dual_hints and function() return "" end or label
    local function cancel_timers()
      if long_timer then long_timer:cancel() long_timer = nil end
      if repeat_timer then repeat_timer:cancel() repeat_timer = nil end
    end
    local function cancel()
      cancel_timers()
      long, held, touching = false, false, false
      down:set(false)
    end
    cancellations[#cancellations + 1] = cancel
    local function show_preview()
      if spec.kind ~= "char" then return end
      preview.x:set(x) preview.y:set(y) preview.w:set(w)
      preview.text:set(label())
      preview.on:set(true)
    end
    local function commit()
      if not enabled() then return end
      if spec.kind == "char" then strike_text(shifted(spec.text))
      elseif spec.kind == "key" then
        if spec.text then strike_text(spec.text) else strike_key(spec.key) end
      end
    end
    local area
    area = action {
      id = id, x = x, y = body_top + y, width = w, height = KH, cursor = "pointer",
      on_pressed = function()
        if not enabled() or (touch and touch.blocked()) then return end
        held = true
        down:set(true)
        long = false
        repeated = false
        if spec.kind == "action" then
          -- Released engines dispatch Pressed before TouchPressed. A
          -- gesture-enabled board must defer irreversible actions until
          -- release even before the raw touch callback arrives.
          if not touching and not touch then act(spec.action) end
          return
        end
        show_preview()
        if spec.rep then
          if not touching and not touch then commit() repeated = true end
          repeat_timer = morf.timer(420, function()
            commit() repeated = true
            repeat_timer = morf.timer(55, function() commit() end, true)
          end, false)
          return
        end
        if spec.alts and #spec.alts > 0 then
          long_timer = morf.timer(380, function()
            long_timer = nil
            long = true
            preview.on:set(false)
            local list = {}
            for i, v in ipairs(spec.alts) do list[i] = shifted(v) end
            local left = math.max(0, math.min(W - #list * CELL, x + w / 2 - CELL / 2))
            alts.x:set(left) alts.y:set(y) alts.list:set(list) alts.pick:set(1)
          end, false)
        end
      end,
      on_dragged = function(_, _, _, _, lx)
        if not long then return end
        local list = alts.list:get()
        local at = math.floor((x + (lx or 0) - alts.x:get()) / CELL) + 1
        alts.pick:set(math.max(1, math.min(#list, at)))
      end,
      on_released = function()
        if not held then return end
        held = false
        down:set(false)
        preview.on:set(false)
        local was_repeat = repeated
        local was_touch = touching
        touching = false
        cancel_timers()
        if spec.kind == "action" then
          if was_touch or touch then act(spec.action) end
          return
        end
        if long then
          local list = alts.list:get()
          local pickd = list[alts.pick:get()]
          alts.list:set({})
          long = false
          if pickd then strike_text(pickd) end
          return
        end
        if not was_repeat then commit() end
      end,
      KEY_FACE and KEY_FACE {
        id = id, width = w, height = KH, kind = spec.kind, label = face_label,
        hint = not spec.dual_hints and spec.alts and spec.alts[1] or nil,
        down = function() return down:get() end,
        lit = lit, accent = spec.accent, dim = spec.dim, mirror = spec.mirror,
        icon = spec.icon and function()
          if spec.action == "shift" then return shift:get() == "lock" and "keyboard_capslock" or "shift" end
          return spec.icon
        end,
      } or ui.Item { anchors = { fill = true },
        ui.Rect {
          anchors = { fill = true }, radius = RADIUS,
          color = function()
            if down:get() then return PRESS() end
            if spec.accent or lit() then return ACCENT() end
            if spec.dim then return KEY_DIM() end
            return KEY()
          end,
          behavior = { color = { duration = 90 } },
        },
        (ICONS and spec.icon) and ui.Text {
          anchors = { center_in = true }, font_family = ICONS, font_size = math.floor(LABEL * 1.15),
          axes = { FILL = 1 },
          scale_x = spec.mirror and -1 or 1,
          text = function()
            if spec.action == "shift" then return shift:get() == "lock" and "keyboard_capslock" or "shift" end
            return spec.icon
          end,
          color = function() return (spec.accent or lit()) and ON_ACCENT() or TEXT() end,
        } or ui.Text {
          anchors = { center_in = true }, text = face_label, font_family = FONT,
          font_size = (spec.kind == "char" or #spec.label <= 2) and LABEL or math.floor(LABEL * 0.72),
          color = function() return (spec.accent or lit()) and ON_ACCENT() or TEXT() end,
        },
      },
    }
    area.on_touch_pressed = function(id,px,py)
      touching = true
      if touch then touch.down(id,px,py) end
    end
    if touch then
      area.on_touch_moved=touch.move
      area.on_touch_released=touch.up
    end
    area.on_touch_canceled = function(id)
      cancel()
      preview.on:set(false)
      alts.list:set({})
      if touch then touch.cancel(id) end
    end
    -- Dev shows both choices; draw these here so every theme agrees on them.
    local hint = spec.alts and spec.alts[1]
    if spec.dual_hints then
      return ui.Item {
        x = 0, y = 0, width = W, height = 0,
        area,
        ui.Item {
          x = x, y = body_top + y + SMALL + 3, width = w, height = KH - SMALL - 3,
          ui.Text { anchors = { center_in = true }, text = label, font_family = FONT,
            font_size = LABEL, color = function() return TEXT() end },
        },
        ui.Text {
          id = id .. ".hint.primary", x = x + 4, y = body_top + y + 3,
          text = hint, font_family = FONT, font_size = SMALL, color = function() return DIM() end,
        },
        ui.Text {
          id = id .. ".hint.secondary", x = x + w - SMALL - 4, y = body_top + y + 3,
          text = spec.alts[2], font_family = FONT, font_size = SMALL, color = function() return DIM() end,
        },
      }
    end
    -- The ordinary keyboard shows the first long-press offer in the corner.
    if hint and not KEY_FACE then
      return ui.Item {
        x = 0, y = 0, width = W, height = 0,
        area,
        ui.Text {
          x = x + w - SMALL - 4, y = body_top + y + 3, text = hint, font_family = FONT,
          font_size = SMALL, color = function() return DIM() end,
        },
      }
    end
    return area
  end

  --- The keys of one mode and page, absolutely placed.
  local function build_page(mode_name, page_name, rows)
    local nodes = {}
    local y = 0
    for _, r in ipairs(rows) do
      -- A key of w units is w key widths and the w - 1 gaps inside it, so
      -- a row of n units is n * u + (n - 1) gaps across, whatever its keys.
      -- One u for every row keeps the keys the same size; a row that would
      -- not fit (more than ten units) shrinks to.
      local units = 0
      for _, spec in ipairs(r) do units = units + spec.w end
      local u = math.min(UNIT, (W - 2 * GAP - (units - 1) * GAP) / units)
      local row_w = units * u + (units - 1) * GAP
      local x = math.floor((W - row_w) / 2)
      for _, spec in ipairs(r) do
        local w = math.floor(spec.w * u + (spec.w - 1) * GAP)
        if spec.kind ~= "gap" then nodes[#nodes + 1] = key_node(spec, x, y, w, mode_name, page_name) end
        x = x + w + GAP
      end
      y = y + KH + GAP
    end
    return nodes
  end

  -- Every mode and page is built once; the one on show is visible.
  local layers = {}
  local function layer(mode_name, page_name, with_numbers)
    local rows
    if mode_name == "numbers" or mode_name == "phone" or mode_name == "letters" then
      rows = rows_for(mode_name, page_name)
    elseif mode_name == "dev" and page_name == "letters" then
      rows = PAGES.dev
    else
      local base = PAGES[page_name]
      rows = {}
      if page_name == "letters" and with_numbers then rows[#rows + 1] = PAGES.numrow end
      for _, r in ipairs(base) do rows[#rows + 1] = r end
    end
    local nodes = build_page(mode_name .. (with_numbers and "n" or ""), page_name, rows)
    nodes.visible = function()
      if mode:get() ~= mode_name then return false end
      if mode_name == "numbers" or mode_name == "phone" or mode_name == "letters" then return true end
      if page:get() ~= page_name then return false end
      if page_name == "letters" and mode_name ~= "dev" then return numbers:get() == with_numbers end
      return true
    end
    nodes.width, nodes.height = W, 1
    layers[#layers + 1] = ui.Item(nodes)
  end
  layer("full", "letters", true)
  layer("full", "letters", false)
  layer("dev", "letters")
  for _, m in ipairs { "full", "dev" } do
    layer(m, "symbols")
    layer(m, "symbols2")
  end
  layer("letters", "letters")
  layer("numbers", "letters")
  layer("phone", "letters")

  -- ------------------------------------------------------------ pattern --
  local dots = morf.signal(named("pattern.dots"), {})
  local finger = morf.signal(named("pattern.finger"), { -1, -1 })
  local pattern_timer, pattern_held
  cancellations[#cancellations + 1] = function()
    if pattern_timer then pattern_timer:cancel() pattern_timer = nil end
    pattern_held = false
  end
  local PS = math.floor(math.min(W, KH * 7))
  local PX = math.floor((W - PS) / 2)
  local function dot_at(i)
    local r, cc = (i - 1) // 3, (i - 1) % 3
    return PX + PS * (cc + 0.5) / 3, body_top + PS * (r + 0.5) / 3
  end
  local DOT_R = math.floor(PS * 0.045)
  local HIT = PS * 0.14
  local function touch(lx, ly)
    local gx, gy = PX + lx, body_top + ly
    finger:set({ gx, gy })
    local list = dots:get()
    for i = 1, 9 do
      local dx, dy = dot_at(i)
      if (gx - dx) ^ 2 + (gy - dy) ^ 2 <= HIT * HIT then
        local seen = false
        for _, v in ipairs(list) do if v == i then seen = true end end
        if not seen then
          local copy = {}
          for n, v in ipairs(list) do copy[n] = v end
          copy[#copy + 1] = i
          dots:set(copy)
        end
        return
      end
    end
  end
  local pattern_nodes = {
    visible = function() return mode:get() == "pattern" end,
    width = W, height = 1,
    ui.Path {
      x = 0, y = 0, width = W, height = body_top + PS, view_box = { 0, 0, W, body_top + PS },
      stroke_width = math.max(3, math.floor(DOT_R * 0.7)), stroke_join = "round", stroke_cap = "round",
      stroke_color = function() return ACCENT() end,
      fill_color = function() return ACCENT():alpha(0) end,
      d = function()
        local list = dots:get()
        if #list == 0 then return "M0 0" end
        local parts = {}
        for n, i in ipairs(list) do
          local px, py = dot_at(i)
          parts[#parts + 1] = ("%s%.1f %.1f"):format(n == 1 and "M" or "L", px, py)
        end
        local f = finger:get()
        if f[1] >= 0 then parts[#parts + 1] = ("L%.1f %.1f"):format(f[1], f[2]) end
        return table.concat(parts, " ")
      end,
    },
  }
  for i = 1, 9 do
    local dx, dy = dot_at(i)
    local function on()
      for _, v in ipairs(dots:get()) do if v == i then return true end end
      return false
    end
    pattern_nodes[#pattern_nodes + 1] = ui.Rect {
      x = dx - DOT_R, y = dy - DOT_R, width = 2 * DOT_R, height = 2 * DOT_R, radius = DOT_R,
      scale = function() return on() and 1.5 or 1 end,
      behavior = { scale = { duration = 180, easing = "out_back" } },
      color = function() return on() and ACCENT() or DIM() end,
    }
  end
  pattern_nodes[#pattern_nodes + 1] = ui.MouseArea {
    id = named("pattern"), x = PX, y = body_top, width = PS, height = PS,
    on_pressed = function(_, _, lx, ly)
      if not enabled() then return end
      if pattern_timer then pattern_timer:cancel() pattern_timer = nil end
      pattern_held = true
      dots:set({}) touch(lx or 0, ly or 0)
    end,
    on_dragged = function(_, _, _, _, lx, ly) if pattern_held then touch(lx or 0, ly or 0) end end,
    on_released = function()
      if not pattern_held or not enabled() then return end
      pattern_held = false
      local list = dots:get()
      finger:set({ -1, -1 })
      if #list > 0 then on_pattern(list) end
      pattern_timer = morf.timer(350, function() pattern_timer = nil dots:set({}) end, false)
    end,
  }
  layers[#layers + 1] = ui.Item(pattern_nodes)

  -- ------------------------------------------------------ the overlays --
  local bubble = ui.Item {
    id = named("preview-bubble"),
    visible = function() return preview.on:get() end,
    x = function() return preview.x:get() + preview.w:get() / 2 - KH * 0.55 end,
    y = function() return body_top + preview.y:get() - KH * 1.25 end,
    width = KH * 1.1, height = KH * 1.15,
    ui.Rect { anchors = { fill = true }, radius = RADIUS * 1.4, color = function() return PRESS() end },
    ui.Text { anchors = { center_in = true }, text = function() return preview.text:get() end,
      font_family = FONT, font_size = math.floor(LABEL * 1.3), color = function() return TEXT() end },
  }
  local strip = { }
  for i = 1, 10 do
    strip[#strip + 1] = ui.Item {
      width = CELL, height = CELL,
      visible = function() return alts.list:get()[i] ~= nil end,
      ui.Rect {
        anchors = { fill = true }, radius = RADIUS,
        color = function() return alts.pick:get() == i and ACCENT() or ACCENT():alpha(0) end,
      },
      ui.Text { anchors = { center_in = true }, font_family = FONT, font_size = LABEL,
        text = function() return alts.list:get()[i] or "" end,
        color = function() return alts.pick:get() == i and ON_ACCENT() or TEXT() end },
    }
  end
  local alt_strip = ui.Item {
    id = named("alternates"),
    visible = function() return #alts.list:get() > 0 end,
    x = function() return alts.x:get() - 4 end,
    y = function() return body_top + alts.y:get() - CELL - 12 end,
    width = function() return #alts.list:get() * CELL + 8 end, height = CELL + 8,
    ui.Rect { anchors = { fill = true }, radius = RADIUS * 1.3, color = function() return PRESS() end },
    ui.Row { x = 4, y = 4, gap = 0, table.unpack(strip) },
  }

  local function cancel()
    for _, stop in ipairs(cancellations) do stop() end
    preview.on:set(false)
    alts.list:set({})
    dots:set({})
    finger:set({ -1, -1 })
  end

  local root = ui.Item {
    id = named("board"),
    on_destroyed = cancel,
    width = W, height = height,
    ui.Rect { anchors = { fill = true }, color = function() return PANEL() end },
    ui.Item(with({ width = W, height = 1 }, table.unpack(layers))),
    bubble,
    alt_strip,
  }

  -- Hiding or changing layouts cancels outstanding long presses and repeats.
  -- Releasing an old pointer grab afterward must not type into a newer page.
  morf.effect(named("lifecycle"), function()
    enabled() mode:get() page:get() numbers:get()
    cancel()
  end, { owner = root })

  return {
    node = root,
    height = height,
    mode = mode,
    numbers = numbers,
    page = page,
    shift = shift,
    cancel = cancel,
    reset = function() cancel() page:set("letters") shift:set("off") for _, s in pairs(mods) do s:set("off") end end,
  }
end

return osk
