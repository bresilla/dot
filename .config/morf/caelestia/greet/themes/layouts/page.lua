-- The one template every page of a panel is drawn with -- a settings page,
-- a panel's tab, a page one level in -- so all of them read alike: the same
-- title, the same cards, the same gaps, the same rows and buttons, in the
-- theme's colours (THEMING.md: the kit draws, this only places).
--
--     local P = require("themes.layouts.page")
--     return P.page { id = "sound", width = w, height = h, title = "Sound",
--       subtitle = "Output and volume", actions = { P.button { ... } },
--       P.section { title = "Output",
--         P.row { id = "sound-mute", icon = "volume_off", title = "Mute",
--           trailing = P.switch { ... } },
--       },
--       P.empty { icon = "headphones", title = "No device", text = "..." },
--     }
--
-- A page: a header (title, a subtitle under it, actions at its right), then
-- its blocks one under the other, `GAP` apart, each the page's width; the
-- whole of it scrolls in `height`. A section: a caption over one card that
-- holds its rows (or anything else), `PAD` inside. A row: an icon, a title
-- and a line under it, and a control at the right; the whole row presses
-- when it opens something. A button fits its label.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")
local C = theme.color

local P = {}

P.GAP = 12            -- between blocks, and between a caption and its card
P.PAD = 14            -- inside a card
P.ROW_H = 64          -- a row
P.ROW_GAP = 6         -- between rows in a card
P.BUTTON_H = 36       -- a button
P.RADIUS = 18         -- a card's rounding, where the theme rounds

local function get(v) if type(v) == "function" then return v() end return v end

--- The width a card `w` wide leaves its rows.
function P.inner(w) return get(w) - 2 * P.PAD end

--- Children of `spec`'s array part, nil holes closed.
local function children(spec)
  local out = {}
  for _, c in ipairs(L.compact(spec)) do out[#out + 1] = c end
  return out
end

-- ------------------------------------------------------------------ text --

local TITLE = L.SIZE.title
local SUB = L.SIZE.body
P.SUB = SUB           -- a row's second line, a note

--- A button that fits its label (and icon): `id`, `label`, `icon`,
--- `on_clicked`, `width` (leave it out: the label's), `selected` (fn),
--- `group`, `tone` ("primary", or a fn giving it, is filled), `color` and
--- `ink` (fns: a colour of its own, an alert's), `visible`.
function P.button(spec)
  local label = spec.label or ""
  -- Measured the way the theme's pill sets its caption: a menu face in
  -- capitals where the theme has one, its body text where not.
  local menu = theme.typography and theme.typography.menu
  local caption = menu and function() return tostring(get(label) or ""):upper() end or label
  local size = menu or theme.size.normal
  local measure = menu and kit.menu_label { text = caption, font_size = size, height = 18, opacity = 0 }
    or kit.text { text = caption, font_size = size, opacity = 0 }
  local function natural()
    local text = measure.layout_width or (utf8.len(tostring(get(caption))) * size * 0.62)
    return math.ceil(text + 40 + (spec.icon and 26 or 0))
  end
  local width = spec.width
  if width == nil then width = natural end
  local function primary()
    local tone = get(spec.tone)
    return tone == "primary"
  end
  local pill = kit.pill { id = spec.id, label = label, icon = spec.icon, width = width, height = spec.height or P.BUTTON_H,
    checkable = spec.group ~= nil or nil, group = spec.group, checked = spec.group and spec.selected or nil,
    on_clicked = spec.on_clicked,
    color = spec.color or function()
      if (spec.selected and spec.selected()) or primary() then return C.primary end
      return C.surfaceContainerHighest
    end,
    ink = spec.ink or function()
      if (spec.selected and spec.selected()) or primary() then return C.onPrimary end
      return C.onSurface
    end }
  if spec.visible then pill.visible = spec.visible end
  return ui.Item { id = spec.id and spec.id .. "-box", width = width, height = spec.height or P.BUTTON_H,
    visible = spec.visible, ui.Item { width = 1, height = 1, clip = true, measure }, pill }
end

--- A row of buttons sharing `width` evenly: `width`, then the buttons'
--- specs in the array part (each P.button's, `width` left out).
function P.buttons(spec)
  local items = children(spec)
  local n = math.max(1, #items)
  local gap = 8
  local each = function() return math.floor((get(spec.width) - gap * (n - 1)) / n) end
  local row = { gap = gap, align = "center" }
  for i, item in ipairs(items) do
    item.width = each
    row[i] = P.button(item)
  end
  return ui.Row(row)
end

--- The theme's switch, at a row's right.
function P.switch(spec)
  return kit.switch { id = spec.id, accessible_name = spec.name, on = spec.on, on_toggled = spec.on_toggled }
end

--- An arrow at a row's right: the row opens something.
function P.chevron()
  return kit.icon("chevron_right", 22, kit.ink("lo"))
end

--- A caption across `w`, held to it: a long note is cut at the card's edge,
--- never run on over a neighbour's.
local function caption(id, w, text, note)
  return ui.Item { width = w, height = L.CAPTION_H, clip = true,
    L.caption { id = id, width = get(w), text = text, note = note } }
end

-- ------------------------------------------------------------------ rows --

--- A row: `id`, `width`, `icon` (a name or fn), `title`, `subtitle` (a
--- string or fn), `trailing` (a node at the right), `on_clicked` (the
--- whole row presses), `on` (fn: the icon lights while true), `height`,
--- `visible`.
function P.row(spec)
  local w, h = spec.width, spec.height or P.ROW_H
  local trailing = spec.trailing
  local function trailing_w() return trailing and ((trailing.layout_width or 0) > 0 and trailing.layout_width or get(trailing.width) or 0) or 0 end
  local text_x = spec.icon and 50 or 14
  local text_w = function() return math.max(0, get(w) - text_x - (trailing and trailing_w() + 28 or 14)) end
  local lit = spec.on or function() return true end
  local body = {
    id = spec.id, width = w, height = h,
    spec.icon and kit.icon(spec.icon, 22, function() return lit() and kit.ink("accent")() or kit.ink("lo")() end,
      { x = 14, anchors = { vertical_center = true } }) or nil,
    ui.Column { x = text_x, anchors = { vertical_center = true }, gap = 2,
      kit.text { id = spec.id and spec.id .. "-title", text = spec.title, width = text_w, elide = "right",
        font_size = theme.size.normal, font_weight = 500, color = kit.ink("hi") },
      spec.subtitle and kit.text { id = spec.id and spec.id .. "-subtitle", text = spec.subtitle, width = text_w,
        elide = "right", font_size = SUB, color = kit.ink("lo") } or nil,
    },
  }
  if trailing then
    body[#body + 1] = ui.Item { anchors = { right = true, right_margin = 14, vertical_center = true },
      -- (Never 0x0, though its control be hidden: it holds a place.)
      width = function() return math.max(1, trailing_w()) end,
      height = function() return math.max(1, trailing.layout_height or get(trailing.height) or 0) end,
      trailing }
  end
  body.visible = spec.visible
  local node = L.item(body)
  if spec.on_clicked then
    local press = kit.action { id = spec.id and spec.id .. "-press", width = w, height = h, cursor = "pointer",
      on_clicked = spec.on_clicked, node }
    if spec.visible then press.visible = spec.visible end
    return press
  end
  return node
end

-- -------------------------------------------------------------- sections --

--- A caption over one card: `id`, `title` (the caption; none, no caption),
--- `caption_id`, `note`, `width`, `visible`, then what the card holds in the array part (rows, or
--- any nodes the card's width less its padding), one under the other.
function P.section(spec)
  local w = spec.width
  local items = children(spec)
  local col = { x = P.PAD, y = P.PAD, gap = P.ROW_GAP }
  for i, item in ipairs(items) do col[i] = item end
  local column = ui.Column(col)
  local card = kit.card { id = spec.id and spec.id .. "-card", width = w, radius = kit.round(P.RADIUS),
    height = function() return (column.layout_height or 0) + 2 * P.PAD end,
    column }
  local parts = { id = spec.id, width = w, gap = P.GAP / 2 }
  if spec.title then
    parts[#parts + 1] = caption(spec.caption_id or (spec.id and spec.id .. "-caption"), w, spec.title, spec.note)
  end
  parts[#parts + 1] = card
  parts.visible = spec.visible
  return ui.Column(parts)
end

--- A tile of a grid (the dashboard's): a section a fixed `height` tall,
--- caption included -- `id`, `title`, `note`, `width`, `height`, `visible`,
--- `clip`; what it holds in the array part, placed in its card's inner box
--- (P.tile_inner(w, h) big, at the card's padding). Without a title it is
--- the card alone.
P.CAPTION_H = L.CAPTION_H + P.GAP / 2
function P.tile_inner(w, h, titled)
  return get(w) - 2 * P.PAD, get(h) - 2 * P.PAD - (titled == false and 0 or P.CAPTION_H)
end
function P.tile(spec)
  local w, h = spec.width, spec.height
  local titled = spec.title ~= nil
  local card_h = function() return get(h) - (titled and P.CAPTION_H or 0) end
  local inner = { x = P.PAD, y = P.PAD, width = function() return get(w) - 2 * P.PAD end,
    height = function() return card_h() - 2 * P.PAD end, clip = spec.clip }
  for i, c in ipairs(children(spec)) do inner[i] = c end
  local card = kit.card { id = spec.id and spec.id .. "-card", width = w, height = card_h,
    radius = kit.round(P.RADIUS), ui.Item(inner) }
  local parts = { id = spec.id, width = w, height = h, gap = P.GAP / 2 }
  if titled then
    parts[#parts + 1] = caption(spec.caption_id or (spec.id and spec.id .. "-caption"), w, spec.title, spec.note)
  end
  parts[#parts + 1] = card
  parts.visible = spec.visible
  return ui.Column(parts)
end

--- `n` widths sharing `w` with `P.GAP` between them, the last taking what
--- rounding leaves: P.cols(w, 3) -> a, b, c; or with `weights` ({2, 1}).
function P.cols(w, n, weights)
  local total, out = get(w) - P.GAP * (n - 1), {}
  local sum = 0
  for i = 1, n do sum = sum + (weights and weights[i] or 1) end
  local used = 0
  for i = 1, n do
    if i == n then out[i] = total - used
    else out[i] = math.floor(total * (weights and weights[i] or 1) / sum) used = used + out[i] end
  end
  return table.unpack(out)
end

--- What a page says when it has nothing to list: `id`, `width`, `icon`,
--- `title`, `text`, `action` (a P.button spec: what to do about it),
--- `visible`.
function P.empty(spec)
  local w = spec.width
  return P.section { id = spec.id, width = w, visible = spec.visible,
    ui.Column { width = function() return get(w) - 2 * P.PAD end, gap = 8, align = "center",
      ui.Item { width = 1, height = 8 },
      kit.icon(spec.icon or "info", 34, kit.ink("lo")),
      kit.text { text = spec.title, font_size = theme.size.normal, font_weight = 600, color = kit.ink("hi"),
        horizontal_alignment = "center", width = function() return get(w) - 4 * P.PAD end, elide = "right" },
      spec.text and kit.text { text = spec.text, font_size = SUB, color = kit.ink("lo"), wrap = true,
        horizontal_alignment = "center", width = function() return get(w) - 4 * P.PAD end } or nil,
      spec.action and P.button(spec.action) or nil,
      ui.Item { width = 1, height = 8 },
    } }
end

-- ---------------------------------------------------------------- header --

P.HEADER_H = L.heading_h(TITLE) + L.lh(SUB) + 2

--- A page's head: `id`, `width`, `title` (string or fn), `subtitle`,
--- `back` (fn: an arrow at its left that calls it -- a page one level in),
--- `can_back` (fn: whether the arrow is there; always, without it),
--- `actions` (nodes at its right), `scope` (the heading's), `title_id`.
function P.header(spec)
  local w = spec.width
  local actions = spec.actions and children(spec.actions) or {}
  local row
  if #actions > 0 then
    local r = { anchors = { right = true, vertical_center = true }, gap = 8, align = "center" }
    for i, a in ipairs(actions) do r[i] = a end
    row = ui.Row(r)
  end
  local can_back = spec.can_back or function() return spec.back ~= nil end
  local function lead() return can_back() and 44 or 0 end
  local function text_w() return math.max(0, get(w) - lead() - (row and (row.layout_width or 0) + 12 or 0)) end
  local back
  if spec.back then
    back = kit.action { id = spec.back_id or (spec.id and spec.id .. "-back"), accessible_name = "Back", width = 40, height = 40,
      cursor = "pointer", anchors = { vertical_center = true }, on_clicked = spec.back, visible = can_back,
      kit.icon("arrow_back", 22, kit.ink("hi"), { anchors = { center_in = true } }) }
    kit.hover(back, function(hovered) return hovered and C.onSurface:alpha(0.08) or C.onSurface:alpha(0) end, 20)
  end
  local text = ui.Column { x = lead, behavior = { x = { duration = theme.duration.small } }, anchors = { vertical_center = true }, gap = 0,
    L.heading { id = spec.title_id or (spec.id and spec.id .. "-title"), scope = spec.scope, level = "title", text = spec.title,
      width = text_w, elide = "right", active = spec.active },
    spec.subtitle and kit.text { id = spec.id and spec.id .. "-subtitle", text = spec.subtitle, font_size = SUB,
      color = kit.ink("lo"), width = text_w, height = L.lh(SUB), elide = "right" } or nil,
  }
  return L.item { id = spec.id, width = w, height = P.HEADER_H, back, text, row }
end

-- ----------------------------------------------------------------- frame --

--- A panel's page as the panel shows it: the header, then the page's body
--- under it. `id`, `width`, `height` (fn), `title` (the tab's name),
--- `title_id`, `scope`, `active` (fn: the title is on show), `titled`
--- (the head shows: the tabs are icons alone), `build(w, h)` -- the body, `h` a fn -- which may
--- give back a second value with what the header says instead: `title`,
--- `subtitle`, `back`, `can_back`, `actions` (as P.header's).
function P.frame(spec)
  local w = spec.width
  local head
  -- The head is there where the tabs do not name the page (a phone's, icons
  -- alone: `titled`), and on a page one level in, for its way back.
  local function shown()
    if get(spec.titled) then return true end
    return head ~= nil and head.can_back ~= nil and head.can_back() == true
  end
  local function top() return shown() and P.HEADER_H + P.GAP or 0 end
  local function body_h() return math.max(0, get(spec.height) - top()) end
  local body
  body, head = spec.build(w, body_h)
  head = head or {}
  local header = P.header { id = spec.id and spec.id .. "-head", width = w, title = head.title or spec.title,
    title_id = head.title_id or spec.title_id, scope = spec.scope, subtitle = head.subtitle, back = head.back,
    can_back = head.can_back, back_id = head.back_id, actions = head.actions, active = head.active or spec.active }
  header.visible = shown
  return ui.Item { id = spec.id, width = w, height = spec.height,
    header,
    ui.Item { y = top, width = w, height = body_h, body },
  }
end

-- ------------------------------------------------------------------ page --

--- A page: `id`, `width`, `height` (a number or fn), `title`, `subtitle`,
--- `actions` (nodes at the header's right), `scroll` (false: it does not
--- scroll, its blocks share the height), `active` (fn: on show -- it is
--- back at its top each time it comes on show); the blocks in the array
--- part.
function P.page(spec)
  local w = spec.width
  local blocks = children(spec)
  local col = { width = w, gap = P.GAP }
  if spec.title then
    col[#col + 1] = P.header { id = spec.id and spec.id .. "-head", width = w, title = spec.title,
      subtitle = spec.subtitle, actions = spec.actions, back = spec.back, scope = spec.scope, active = spec.active }
  end
  for _, b in ipairs(blocks) do col[#col + 1] = b end
  -- A little room under the last block, so its card's foot is not the
  -- scroll's edge.
  col[#col + 1] = ui.Item { width = 1, height = P.GAP }
  local column = ui.Column(col)
  if spec.scroll == false then
    return ui.Item { id = spec.id, width = w, height = spec.height, column }
  end
  local node, flick = kit.scroll({ id = spec.id, width = w, height = spec.height, clip = true, column })
  -- Back at its top each time it comes on show.
  if spec.active and flick then
    local was = false
    morf.effect("page.top." .. (spec.id or tostring(node)), function()
      local now = spec.active() == true
      if now and not was then flick.content_y = 0 end
      was = now
    end, { owner = node })
  end
  return node
end

return P
