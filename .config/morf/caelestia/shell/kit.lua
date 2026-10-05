-- Visual components supplied by the selected theme. Services and state live
-- outside theme packages; both themes receive the same wallpaper palette.
local theme = require("theme")
local kit = require(theme.appearance.components)(theme)
local widgets = require("lib.kit.widgets")

-- The theme's skins draw the kit's archetypes (lib.kit.skin).
if kit.skins then
  local skin = require("lib.kit.skin")
  skin.define(theme.appearance.id, { skins = kit.skins, defaults = kit.skin_defaults })
  skin.use(theme.appearance.id)
end

local function copy(spec)
  local out = {}
  for k, v in pairs(spec or {}) do out[k] = v end
  return out
end

-- Every press and range in the shell is a kit widget: the behaviour is the
-- archetype's (crates/morf-kit), the look the theme's skin. These keep the
-- shapes the layouts already call them with.
kit.widgets = widgets

--- A pressable area as a kit Press `widget`: the MouseArea a layout builds
--- a row, a tile or a choice from. Tab reaches it, Return and Space click
--- it, and the theme's skin marks hover, press and focus; its properties
--- and children are the layout's, kept across a theme switch. `settings`
--- are the Press's own (`checked`, `group`, `on_toggled`, ...).
function kit.press_area(widget, props, settings, archetype)
  local spec, node, children = { widget = widget }, {}, {}
  for key, value in pairs(props or {}) do
    if type(key) == "number" then children[key] = value
    elseif type(key) == "string" and key:match("^on_") then spec[key] = value
    else node[key] = value end
  end
  for key, value in pairs(settings or {}) do spec[key] = value end
  -- A disabled area takes no press, as a MouseArea's `enabled` says, and
  -- its archetype knows.
  if node.enabled ~= nil then spec.enabled = node.enabled end
  return (require("lib.kit.control").make(archetype or "Press", widget, spec, { props = node, children = children }))
end

--- A header that opens and shuts a region the layout draws, as a kit
--- Disclosure `area`: Space and Return toggle, Left shuts, Right opens.
--- `open` (fn) is the truth it follows; `on_toggled(open)` runs only when
--- a press or a key asks for the other state.
function kit.disclose_area(props, open, on_toggled)
  return kit.press_area("area", props, {
    expanded = open,
    on_toggled = function(now) if now ~= (open() == true) then on_toggled(now) end end,
  }, "Disclosure")
end

--- Gives `node` the name a screen reader reads for it (one with only an
--- icon, which says nothing), and returns it.
function kit.named(node, name)
  node.accessible_name = name
  return node
end

--- A pressable area (`kit.press_area`'s `area`).
function kit.action(props) return kit.press_area("area", props) end

--- A filled button: `label`, `icon`, `on_clicked`, `width`, `height` (32),
--- `color`/`ink`.
function kit.pill(spec)
  local s = copy(spec)
  s.height = s.height or 32
  return widgets.pill(s)
end

--- A switch: `on` (fn), `on_toggled(on)`.
function kit.switch(spec)
  local s = copy(spec)
  s.checked, s.on = spec.on, nil
  return widgets.switch(s)
end

--- A small icon toggle: `icon_on`, `icon_off`, `on` (fn: the alert tone
--- while on), `on_clicked`, `width`, `height`, `size`.
function kit.icon_button(spec)
  return widgets.icon(copy(spec))
end

--- A slider: `id`, `width`, `height` (the bar's, 44), `value` (fn, 0..1),
--- `set(v)`, `icon`, `label` (false hides the reading).
function kit.slider(spec)
  local s = copy(spec)
  s.bar_height = spec.height or 44
  s.height = s.bar_height + 8
  s.value, s.set = spec.value, nil
  s.on_moved = spec.set
  return widgets.slider(s)
end

--- The media position, and seeking it: `width`, `value` (fn, 0..1),
--- `seek(v)`, `active` and `playing` (fns).
function kit.media_progress(spec)
  local s = copy(spec)
  s.height = 34
  s.id = s.id or "media-seek"
  s.on_moved, s.seek = spec.seek, nil
  return widgets.seek_bar(s)
end

--- A text field (a kit TextField): `widget` ("entry", "password",
--- "search", ...) and the props of a `ui.TextInput`, plus the field's own
--- (`validator`, `clear`, `well`, `inset`, ...). Returns the control to
--- place and the input inside it, which keeps the props' `id`.
function kit.text_field(widget, props)
  return require("lib.kit.text_field").make(widget, props)
end

--- A scrolled view (a kit Scroll): the props of a `ui.Flickable` and its
--- content. Returns the control to place and the flickable inside it,
--- which keeps the props' `id`; the keys scroll it and the theme draws its
--- scroll bar.
function kit.scroll(props)
  return require("lib.kit.scroll").make("scroll_view", props)
end

--- The tab row: `id`, `tabs` (`{ key, name, icon | icon_build }`), `tab`
--- (a signal, from 1), `width`, `height`, `pad`, `ids` (`"name"`: each tab
--- is `<id>-tab-<name:lower()>`; `"key"` by default), `growing` (the row
--- follows an easing drawer). A kit Selection: click, arrows, Home and End.
function kit.tabs(spec)
  local s = copy(spec)
  -- The tabs in the order shown: `reorderable` lets a drag or Alt with the
  -- arrows move one, while each keeps its index for what it opens.
  local order = morf.signal("caelestia." .. spec.id .. ".tab-order", {})
  local function shown()
    local o = order:get()
    if #o ~= #spec.tabs then o = {} for i = 1, #spec.tabs do o[i] = i end end
    return o
  end
  local function position(index)
    for p, i in ipairs(shown()) do if i == index then return p end end
    return index
  end
  s.items = function()
    local out = {}
    for p, i in ipairs(shown()) do out[p] = spec.tabs[i] end
    return out
  end
  s.tabs, s.tab = nil, nil
  s.current = function() return position(spec.tab:get()) end
  s.on_current_changed = function(p) spec.tab:set(shown()[p] or p) end
  s.on_reorder = function(p, step)
    local o = shown()
    local q = p + step
    if not o[q] then return end
    o[p], o[q] = o[q], o[p]
    order:set(o)
  end
  local by_name = spec.ids == "name"
  s.item_id = function(_, entry)
    return spec.id .. "-tab-" .. (by_name and entry.name:lower() or (entry.key or entry.name:lower()))
  end
  s.ids = nil
  s.id, s.tab_id = spec.id .. "-tabs", spec.id
  if spec.growing then
    s.width = nil
    s.anchors = { left = true, right = true, left_margin = spec.pad or 11, right_margin = spec.pad or 11 }
  end
  s.height = spec.height or 64
  -- The skins read the row's own width; a growing row's is the drawer's.
  s.width_of = spec.width
  return widgets.tabs(s)
end

return kit
