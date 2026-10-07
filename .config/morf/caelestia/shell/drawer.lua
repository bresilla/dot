-- A drawer: a panel that grows out of the frame.
--
-- The panel is an ordinary node inside the frame's opening, tucked past the
-- edge it hangs from while shut. Its background is not drawn by the panel:
-- it is one layer of the frame's own distance field (`shape`), a box that
-- follows wherever the panel is drawn (`track`) and joins the frame with a
-- circular seam, so the frame itself seems to bulge out into the drawer,
-- with a concave fillet where the drawer's sides meet the frame.
--
-- Opening and closing each run their own curve and duration, measured off
-- films of the reference: a separate play per direction rather than one
-- behavior, which can only have one.

local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")

local M = {}

M.all = {}

local groups = 0

--- `spec`: `name`, `edge` ("top", "bottom", "left" or "right"), `width`,
--- `height` (numbers or bindings), `content` (a node, laid out in the
--- panel), `props` (more properties for the panel: a side drawer is
--- centred on its edge unless they place it, `y` for one),
--- `close_policy` (what shuts it while open, as a kit Popup's: "outside"
--- -- a press anywhere else on the surface --, "escape", both joined by
--- "+", or "none": a popup still, in the stack, that only its own controls
--- shut), `modal` (Tab stays inside it while open), `on_dismiss` (what
--- shutting it that way does; `set(false)` by default). A drawer with no
--- policy is not a popup at all.
-- Each drawer as a screen reader's landmark: role and name.
local LANDMARKS = {
  launcher = { "dialog", "Launcher" }, session = { "dialog", "Session" }, capture = { "dialog", "Capture" },
  dashboard = { "region", "Dashboard" }, sidebar = { "complementary", "Sidebar" },
  leftbar = { "complementary", "Planner" }, bottom = { "complementary", "Tools" },
  polkit = { "alert_dialog", "Authentication" }, keyring = { "alert_dialog", "Keyring" },
  authsteps = { "alert_dialog", "Authentication" }, notifications = { "log", "Notifications" },
  keyboard = { "region", "On-screen keyboard" },
}

function M.new(spec)
  groups = groups + 1
  local d = { name = spec.name, edge = spec.edge }
  local authentication = spec.transient or spec.name == "polkit" or spec.name == "keyring" or spec.name == "authsteps"
  local keep = authentication and morf.signal or require("themes.session").keep
  d.open = keep("caelestia.drawer." .. spec.name, false)
  local sign = (spec.edge == "top" or spec.edge == "left") and -1 or 1
  local across = spec.edge == "left" or spec.edge == "right"
  local axis = across and "translate_x" or "translate_y"

  local props = spec.props or {}
  props.id = "drawer-" .. spec.name
  -- A landmark a screen reader walks: what the drawer is, by name.
  local landmark = LANDMARKS[spec.name] or { "region", spec.name:sub(1, 1):upper() .. spec.name:sub(2) }
  props.accessible_role = props.accessible_role or spec.role or landmark[1]
  props.accessible_name = props.accessible_name or spec.title or landmark[2]
  if landmark[1] == "dialog" or landmark[1] == "alert_dialog" then props.accessible = { modal = true } end
  props.width = spec.width
  props.height = spec.height
  local ANCHORS = {
    top = { top = true, horizontal_center = true },
    bottom = { bottom = true, horizontal_center = true },
    left = { left = true, vertical_center = true },
    right = { right = true, vertical_center = true },
    center = { center_in = true },
  }
  props.anchors = props.anchors or ANCHORS[spec.edge]
  props.visible = d.open:get()
  props.behavior = props.behavior or {}
  -- The results of a search change the launcher's height: it follows at
  -- the reference's pace.
  props.behavior.height = props.behavior.height
    or { duration = theme.duration.normal, easing = theme.ease.emphasized_decel }
  props[#props + 1] = spec.content
  local panel = ui.Item(props)
  d.panel = panel

  --- How far the panel moves to be out of sight: its size and the seam, so
  --- not even the fillet of its far edge dents the frame.
  local function tucked()
    local size
    if across then size = panel.width_target or panel.width or 0
    else size = panel.height_target or panel.height or 0 end
    return sign * (size + theme.SEAM + theme.BORDER + 2)
  end
  local floating = spec.edge == "center"
  if not floating then panel[axis] = d.open:get() and 0 or tucked() end

  local move, stop_motion = theme.motion.drawer {
    panel = panel, spec = spec, drawer = d,
    axis = axis, floating = floating, tucked = tucked,
  }

  local was = d.open:get()
  morf.effect("caelestia.drawer." .. spec.name, function()
    local now = d.open:get()
    require("presentation").set(spec.name, now)
    if now == was then return end
    was = now
    if not d.manual then move(now) end
  end, { owner = panel })

  -- Its background in the frame's field: square on the frame's side (the
  -- seam rounds that join), the reference's rounding on the far side.
  local near, far = 0, theme.ROUNDING
  local e = spec.edge
  local function r(a, b) return (e == a or e == b) and near or far end
  -- A floating one is rounded all round, and apart from the frame's seams.
  d.shape = ui.SdfShape {
    id = "drawer-" .. spec.name .. "-background",
    shape = "box",
    operation = "smooth_union",
    blend_group = groups,
    track = panel,
    top_left_radius = r("top", "left"),
    top_right_radius = r("top", "right"),
    bottom_left_radius = r("bottom", "left"),
    bottom_right_radius = r("bottom", "right"),
  }
  local transition = require("themes.session").transition
  if transition and transition.rounding then
    local switcher = require("themes.switcher")
    for _, corner in ipairs {
      {"top_left_radius","top","left"}, {"top_right_radius","top","right"},
      {"bottom_left_radius","bottom","left"}, {"bottom_right_radius","bottom","right"},
    } do
      local previous = (e==corner[2] or e==corner[3]) and 0 or transition.rounding
      switcher.morph(d.shape,corner[1],r(corner[2],corner[3]),previous)
    end
  end

  -- Shut, a floating panel's background is not drawn at all.
  if floating then d.shape.opacity = d.open:get() and 1 or 0 end

  function d.set(on)
    local switcher = package.loaded["themes.switcher"]
    if not authentication and switcher and switcher.busy:get() then return end
    local manual = d.manual
    if manual and d.interrupt_drag then d.interrupt_drag() end
    local same = d.open:get() == (on and true or false)
    d.open:set(on and true or false)
    if manual and same then move(on) end
  end
  function d.toggle() d.set(not d.open:get()) end
  function d.is_open() return d.open:get() end

  require("drawer_drag").attach(d, {
    content=spec.content, axis=axis, tucked=tucked, floating=floating,
  }, stop_motion)

  -- While open it is a kit Popup where it stands: the overlay layer shuts
  -- it on a press outside or Escape, by its policy -- no catcher of its own.
  if spec.close_policy then
    require("lib.kit.popup").track(panel, {
      open = function() return d.open:get() end,
      close_policy = spec.close_policy, modal = spec.modal,
      on_close = function(reason) if spec.on_dismiss then spec.on_dismiss(reason) else d.set(false) end end,
    })
  end

  M.all[#M.all + 1] = d
  M[spec.name] = d
  return d
end

--- Shuts every drawer.
function M.close_all()
  for _, d in ipairs(M.all) do d.set(false) end
end

return M
