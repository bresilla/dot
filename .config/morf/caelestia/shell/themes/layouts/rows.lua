-- Small compositions the settings, planner and side-panel layouts share,
-- built only from the kit and the theme's tokens (THEMING.md, theme rule 1):
-- each theme's look comes through `kit.state_surface`, `kit.icon_button`,
-- `kit.field` and `kit.shape`, never from a shape or colour chosen here.
local ui = require("morf.ui")
local kit = require("kit")
local theme = require("theme")
local C = theme.color
local R = {}

--- The rounding a control `h` high takes, from the theme's own token: a
--- pill in a rounded theme, square where the theme is square.
function R.round(h)
  return kit.round(h / 2)
end

--- A selectable area (a row, a choice button) on the theme's stateful
--- ground (`kit.state_surface`): filled and marked while `on()`.
--- `spec`: `id`, `x`, `y`, `width`, `height`, `anchors`, `visible`,
--- `on_clicked`, `on` (fn), `tone` ("primary" fills with the primary
--- colour, else the secondary container), `tile` (a raised tile when not
--- chosen, else bare until hovered), `group` (choices with one name are a
--- segmented choice: one chosen, the arrows walk them -- a kit Press
--- `segment` in an exclusive group), and children.
function R.choice(spec)
  local on = spec.on or function() return false end
  local props = { id = spec.id, x = spec.x, y = spec.y, width = spec.width, height = spec.height,
    anchors = spec.anchors, visible = spec.visible, cursor = "pointer", on_clicked = spec.on_clicked }
  for _, child in ipairs(spec) do props[#props + 1] = child end
  local area
  if spec.group then
    area = kit.press_area("segment", props,
      { checkable = true, group = spec.group, allow_none = true, checked = on })
  else
    area = kit.action(props)
  end
  local ground = kit.state_surface { area = area, on = on, z = -1,
    height = type(spec.height) == "number" and spec.height or nil,
    tone = spec.tone == "primary" and "primary" or "secondary" }
  ui.reparent(ground, area)
  -- A row in a list is bare until hovered or chosen.
  if not spec.tile then
    ground.opacity = function() return (on() or area.hovered or area.pressed) and 1 or 0 end
  end
  return area
end

--- The ink on a stateful ground (`kit.state_surface`): `on` fn; `strong`
--- for the primary tone; `idle` the ink while off. A kit whose ground is
--- not a full fill of the tone says what ink sits on it (`kit.state_ink`);
--- otherwise the tone's own on-colour.
function R.ink(on, strong, idle)
  if kit.state_ink then
    return kit.state_ink { on = on, tone = strong and "primary" or "secondary", idle = idle }
  end
  return function()
    if on() then return strong and C.onPrimary or C.onSecondaryContainer end
    return (idle or C.onSurface)
  end
end

--- The theme's small icon toggle (`kit.icon_button`), in the alert tone
--- while `on()` (a mute): `id`, `width`, `height`, `anchors`, `on`,
--- `icon_on`, `icon_off`, `on_clicked`, `size` (20).
function R.toggle(spec)
  spec.width, spec.height = spec.width or 36, spec.height or 30
  return kit.icon_button(spec)
end

--- An icon badge in the theme's round shape: `size`, `icon`, `on` (fn,
--- filled with the primary colour while on), `x`, `anchors`.
function R.badge(spec)
  local on = spec.on or function() return true end
  local size = spec.size or 44
  return ui.Item { x = spec.x, y = spec.y, anchors = spec.anchors, width = size, height = size,
    kit.shape { anchors = { fill = true }, shape = "circle",
      color = function() return on() and C.primary or C.surfaceContainerHighest end },
    kit.icon(spec.icon, math.floor(size / 2), function() return on() and C.onPrimary or C.onSurfaceVariant end,
      { anchors = { center_in = true }, fill = true }),
  }
end

--- The well a text input sits in (`kit.field`): lit while the input (its
--- first child) has the keyboard, unless `focused` says otherwise.
--- `width`, `height`, `x`, `y`, `focused` (fn), `error` (fn), children.
function R.well(spec)
  local input = spec[1]
  spec.height = spec.height or 40
  spec.focused = spec.focused or function() return input ~= nil and input.focus == true end
  return kit.field(spec)
end

return R
