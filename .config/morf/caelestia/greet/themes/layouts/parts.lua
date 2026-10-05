-- Composition helpers the shared layouts use: each only places and combines
-- kit calls (THEMING.md, theme rule 1). Nothing here picks a colour, a radius, a
-- shape or a decoration of its own; the theme's kit draws all of it.
--
-- Text boxes are reserved from the shared size tokens (`theme.size`, the
-- same names in every theme), never from a theme's glyph widths: a label is
-- given its font size and the box it may use, and elides inside it.
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")

local L = {}

-- ------------------------------------------------------------------ sizes --

--- Text sizes the layouts use, from the shared tokens.
L.SIZE = {
  micro = theme.size.small - 5,     -- codes and tick captions
  label = theme.size.small - 3,     -- small caps labels, captions
  body = theme.size.small - 1,      -- list text
  value = theme.size.normal,        -- a reading in a row
  title = theme.size.larger + 2,    -- a page or panel title
}

--- The line box a text of `size` takes.
function L.lh(size) return math.ceil(size * 1.4) end
--- The box a heading of `size` takes (the kits' own heading box).
function L.heading_h(size) return math.ceil(size * 1.45) end

L.CAPTION_H = 16       -- a kit.caption row (14 in some kits, 16 in others)
L.CAPTION_GAP = 6      -- between a caption and what it captions
L.HEADER_H = 22        -- a kit.header strip

-- ------------------------------------------------------------------ nodes --

--- `t` with the holes of its array part closed: kit.decor and other
--- optional calls may give nil, which would cut a table constructor short.
function L.compact(t)
  local keys, out = {}, {}
  for k, v in pairs(t) do
    if type(k) == "number" then keys[#keys + 1] = k else out[k] = v end
  end
  table.sort(keys)
  for _, k in ipairs(keys) do out[#out + 1] = t[k] end
  return out
end

--- A `ui.Item` of `t`, nil children skipped.
function L.item(t) return ui.Item(L.compact(t)) end

--- A small label of `size` (L.SIZE.label) in a box of its line height.
function L.label(props)
  props.font_size = props.font_size or props.size or L.SIZE.label
  props.size = nil
  props.height = props.height or L.lh(props.font_size)
  return kit.label(props)
end

--- A status or state word in the theme's own voice: `plain` is the word a
--- person would use ("Playing", "Charging", or nil for none), `key` names
--- the state ("media.paused", "session.power") so a theme may answer with
--- its own term ("STANDBY", "ARMED"). kit.term is a requested addition
--- (the kit contract); until a kit has it the plain word stands. `plain` may be a
--- function; so is the result then.
function L.term(key, plain)
  local term = kit.term
  if type(plain) == "function" or type(key) == "function" then
    return function()
      local k = type(key) == "function" and key() or key
      local p = type(plain) == "function" and plain() or plain
      if term then return term(k, p) end
      return p
    end
  end
  if term then return term(key, plain) end
  return plain
end

--- The theme's decorative code for `key` as a label (empty where the theme
--- prints none; the box stays).
function L.code(key, shape, props)
  props = props or {}
  props.text = kit.code(key, shape) or ""
  props.font_size = props.font_size or L.SIZE.micro
  props.color = props.color or kit.stroke("mark")
  if props.width and not props.elide then props.elide = "right" end
  return L.label(props)
end

--- A caption row across `width` (kit.caption). Without a note (none, or
--- a theme's empty code) the text takes the whole row: the caption is laid
--- out wider, over the room a kit keeps for its note, and cut to `width`.
function L.caption(spec)
  local note = spec.note
  if type(note) == "function" or (note ~= nil and note ~= "") then return kit.caption(spec) end
  local props = {}
  for k, v in pairs(spec) do props[k] = v end
  props.x, props.y, props.id, props.anchors, props.note = nil, nil, nil, nil, nil
  props.width = spec.width + 140
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = spec.width,
    height = L.CAPTION_H, clip = true, kit.caption(props) }
end

--- A one-pixel rule across `width` in the theme's line colour.
function L.rule(props)
  props.height = props.height or 1
  props.color = props.color or kit.stroke(props.strength or "quiet")
  props.strength = nil
  return ui.Rect(props)
end

--- A heading of the shared title size in its reserved box.
function L.heading(props)
  props.font_size = props.font_size or L.SIZE.title
  props.height = props.height or L.heading_h(props.font_size)
  return kit.heading(props)
end

-- ------------------------------------------------------------- composites --

--- A card that wears the theme's header strip: `id`, `x`, `y`, `width`,
--- `height`, `key`, `title`, `status`, `color`, `header` (false for none),
--- `visible`, `clip`; children in the array part. The strip sits 12 in and
--- takes L.HEADER_H; content under it starts at y = 42.
function L.card(spec)
  local props = { id = spec.id, x = spec.x, y = spec.y, width = spec.width, height = spec.height,
    visible = spec.visible, clip = spec.clip }
  if spec.header ~= false then
    props[#props + 1] = kit.header { x = 12, y = 12, width = spec.width - 24, key = spec.key or spec.id,
      title = spec.title, status = spec.status, color = spec.color }
  end
  for _, child in ipairs(L.compact(spec)) do props[#props + 1] = child end
  return kit.card(props)
end

--- A history chart under its caption: the caption (with the chart's scale
--- as its note) on top, the theme's chart under it. `spec` as kit.chart's
--- plus `caption`, `scale` (fn(top) -> string), `x`, `y`. The node is
--- `width` x L.chart_h(height). Returns the node and the chart's `top`.
function L.chart(spec)
  local s = {}
  for k, v in pairs(spec) do
    if k ~= "caption" and k ~= "scale" and k ~= "x" and k ~= "y" then s[k] = v end
  end
  local chart, top = kit.chart(s)
  local scale = spec.scale
  return L.item {
    x = spec.x, y = spec.y, width = spec.width, height = L.chart_h(spec.height),
    spec.caption and L.caption { width = spec.width, text = spec.caption, color = spec.color,
      note = scale and function() return scale(top()) end or nil } or nil,
    ui.Item { y = L.CAPTION_H + L.CAPTION_GAP, width = spec.width, height = spec.height, chart },
  }, top
end
function L.chart_h(height) return L.CAPTION_H + L.CAPTION_GAP + height end

--- A caption with its contents under it: `x`, `y`, `width`, `height`,
--- `id`, `text`, `note`, `color`; children placed from y = 0 of the body.
function L.section(spec)
  local body = { y = L.CAPTION_H + L.CAPTION_GAP, width = spec.width,
    height = spec.height and (spec.height - L.CAPTION_H - L.CAPTION_GAP) or nil }
  for _, child in ipairs(L.compact(spec)) do body[#body + 1] = child end
  return ui.Item {
    id = spec.id, x = spec.x, y = spec.y, width = spec.width, height = spec.height,
    L.caption { id = spec.caption_id, width = spec.width, text = spec.text, note = spec.note, color = spec.color },
    ui.Item(body),
  }
end

--- A page's title row: the heading at the left with its code under it, a
--- chip at the right and the subtitle right-aligned between them, over a
--- rule. `x`, `y`, `width`, `id` (the heading's), `active`, `title`,
--- `subtitle`, `key`, `chip` (text; none when nil). L.title_h tall.
function L.title_row(spec)
  local w = spec.width
  local hh = L.heading_h(L.SIZE.title)
  local chip_w = spec.chip and 64 or 0
  local left_w = math.floor(w * 0.42)
  local right_x = left_w + 12
  local right_w = w - right_x - (chip_w > 0 and chip_w + 10 or 0)
  return L.item {
    x = spec.x, y = spec.y, width = w, height = L.title_h(),
    L.heading { id = spec.id, active = spec.active, level = "title", text = spec.title,
      width = left_w, elide = "right" },
    L.code(spec.key, "UNIT ##-###  ·  CH. ##", { y = hh, width = left_w, elide = "right" }),
    spec.chip and kit.chip { anchors = { right = true }, y = 4, text = spec.chip, filled = true, width = chip_w } or nil,
    L.label { x = right_x, y = 2, width = right_w, horizontal_alignment = "right", elide = "right",
      font_size = L.SIZE.body, text = spec.subtitle, color = kit.ink("hi") },
    L.code((spec.key or "") .. "sub", "SD. ###/##.## - CP-##/CP-##",
      { x = right_x, y = hh, width = right_w, horizontal_alignment = "right", elide = "right" }),
    L.rule { y = L.title_h() - 1, width = w },
  }
end
function L.title_h() return L.heading_h(L.SIZE.title) + L.lh(L.SIZE.micro) + 6 end

--- The live status strip in a box of `height`: kit.status, whose kits size
--- it by `size` or by `height`.
function L.status(spec)
  spec.size = spec.size or spec.height or 40
  spec.height = spec.size
  return kit.status(spec)
end

--- A metered row: the theme's panel plate, a label at the left, the value
--- at the right and a level meter along the foot. `id`, `x`, `y`, `width`,
--- `height` (34), `label`, `value` (fn), `level` (fn -> 0..1), `color`.
function L.row(spec)
  local w, h = spec.width, spec.height or 34
  local vs = L.SIZE.value
  local ls = L.SIZE.label
  local mh = 4
  local text_h = h - mh - 6
  return L.item {
    id = spec.id, x = spec.x, y = spec.y, width = w, height = h,
    kit.panel { width = w, height = h },
    L.label { x = 10, y = math.floor((text_h - L.lh(ls)) / 2) + 2, width = math.floor(w * 0.5) - 10,
      elide = "right", text = spec.label, font_size = ls },
    kit.text { x = math.floor(w * 0.5), y = math.floor((text_h - L.lh(vs)) / 2) + 2, width = math.ceil(w * 0.5) - 10,
      height = L.lh(vs), horizontal_alignment = "right", elide = "right", font_size = vs, text = spec.value,
      color = kit.ink("hi") },
    kit.meter { x = 10, y = h - mh - 5, width = w - 20, height = mh, count = 24, value = spec.level,
      color = spec.color },
  }
end

--- The smallest screen's size: pages that would not fit a small screen
--- shrink their layout to it.
function L.screen()
  local morf = require("morf")
  local w, h
  for _, s in ipairs(morf.screens or {}) do
    if s.width and s.height then
      w, h = math.min(w or s.width, s.width), math.min(h or s.height, s.height)
    end
  end
  return w or 1920, h or 1080
end

-- --------------------------- media, popups, OSD and session (appended) --

-- A role's text size from the theme's typography; a theme without that
-- table answers from its body sizes (the shared names).
function L.role_size(role)
  local t = theme.typography
  if t and t[role] then return t[role] end
  local s = theme.size
  local map = { title = s.normal + 2, section = s.normal, caption = s.small - 1, hero = s.extra,
    subtitle = s.small, label = s.small - 2, menu = s.small }
  return map[role] or s.normal
end

--- The rounding a control `h` high takes from the theme's own token.
function L.control_round(h) return math.max(0, math.min(h / 2, (theme.ROUNDING or 0) * 0.5)) end

--- A theme decoration, or an empty box of its size where the theme draws
--- none, so the arrangement is the same in every theme.
function L.decor_box(name, spec)
  local node = kit.decor(name, spec)
  if node then return node end
  local w = spec.width or spec.length or 0
  local h = spec.height or spec.size or 0
  if name == "ticks" and spec.vertical then w, h = spec.size or 8, spec.length or 0 end
  if name == "scale" then w, h = (spec.size or 8) + 22, spec.height or 0 end
  return ui.Item { id = spec.id, x = spec.x, y = spec.y, anchors = spec.anchors, width = w, height = h }
end

--- An icon button: the theme's hover ground and its icon. `area` (the
--- page's area constructor; kit.action by default), `id`, `x`, `y`,
--- `width`, `height`, `icon` (name or fn), `size`, `on_clicked`, `name`
--- (what a screen reader calls it); `on()` lights it, `ignored()` dims
--- it, `strong` fills it with the accent.
function L.icon_button(spec)
  local make = spec.area or kit.action
  local on, ignored, strong = spec.on, spec.ignored, spec.strong
  local accent = kit.signal("accent")
  local C = theme.color
  local area = make {
    id = spec.id, x = spec.x, y = spec.y, width = spec.width, height = spec.height, cursor = "pointer",
    on_clicked = spec.on_clicked, accessible_name = spec.name or spec.accessible_name,
    kit.icon(spec.icon, spec.size or 22, function()
      if strong then return C.surface end
      if ignored and ignored() then return kit.ink("lo")():alpha(0.35) end
      return (on and on()) and accent() or kit.ink("hi")()
    end, { anchors = { center_in = true }, fill = true }),
  }
  return kit.hover(area, function(hovered)
    if strong then return hovered and accent():mix(C.surface, 0.12) or accent() end
    if on and on() then return accent():alpha(hovered and 0.26 or 0.18) end
    return accent():alpha(hovered and 0.14 or 0.05)
  end, L.control_round(spec.height))
end

return L
