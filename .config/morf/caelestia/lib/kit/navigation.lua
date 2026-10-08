-- Navigations (the Navigation archetype): a navigation view's push and
-- pop, a view stack, a carousel, a wizard.
--
--     local node, nav = navigation.make("navigation_view", {
--       width = 400, height = 600, current = "settings",
--       pages = { settings = build_settings, sound = build_sound },   -- builders or nodes
--     })
--     nav.push("sound") ; nav.pop() ; nav.go("settings")
--
-- Alt+Left and a mouse's back button pop, wherever focus is inside it (its
-- shortcuts); Ctrl+Tab cycles a switcher; a carousel's arrows walk it. A
-- page is built when first shown and kept -- its scroll and focus with it
-- -- while it is in the stack. The skin's `transition(from, to, direction)`
-- moves the pages; without one the new page slides in from its side.
local ui = require("morf.ui")
local control = require("lib.kit.control")

local M = {}

function M.make(widget, spec)
  spec = spec or {}
  local W, H = spec.width, spec.height
  local builders = spec.pages or {}
  local names = {}
  for name in pairs(builders) do names[#names + 1] = name end
  table.sort(names)
  local built = {}
  local area = ui.Item { width = W, height = H, clip = true }
  local active=morf.signal("kit.navigation.active."..tostring(area),"")
  local full = {}
  for k, v in pairs(spec) do full[k] = v end
  full.widget = widget
  full.pages = spec.order or names
  local root, t, ctl
  local shown
  local function page(name)
    if not built[name] then
      local b = builders[name]
      local node = type(b) == "function" and b() or b
      if not node then return nil end
      -- Outgoing pages still draw during their transition, but must stop
      -- accepting clicks and focus immediately. Keep this gate on a wrapper
      -- so the page's own enabled binding remains intact when it returns.
      local layer=ui.Item {width=W or function() return node.layout_width end,
        height=H or function() return node.layout_height end,visible=false,
        enabled=function() return active:get()==name end,node}
      ui.reparent(layer, area)
      built[name] = layer
    end
    return built[name]
  end
  local function show(name, direction)
    local next_node = page(name)
    if not next_node or next_node == shown then return end
    local from = shown
    shown = next_node
    active:set(name)
    next_node.visible = true
    local transition = ctl and ctl.builders().transition
    if transition then
      transition(from, next_node, direction)
    elseif from then
      -- The new page in from its side, the old out the other way.
      local width = W or 400
      next_node.translate_x = direction * width
      morf.animation.play { { parallel = {
        { node = next_node, property = "translate_x", to = 0, duration = 260, easing = "out_cubic" },
        { node = from, property = "translate_x", to = -direction * width * 0.3, duration = 260, easing = "out_cubic" },
      } }, on_finished = function() if from ~= shown then from.visible = false from.translate_x = 0 end end }
    end
  end
  local given = spec.on_current_changed
  full.on_current_changed = function(name, direction)
    show(name, direction or 1)
    if given then given(name, direction) end
  end
  local props = { width = W, height = H, focus_policy = spec.focus_policy or "none" }
  for _, k in ipairs { "id", "x", "y", "anchors", "visible", "z" } do props[k] = spec[k] end
  props.shortcuts = {
    -- Nothing to go back to: the key goes on to what is around.
    ["alt+Left"] = function() if not (t and t.can_go_back) then return false end ctl.send("pop") end,
    ["back"] = function() if not (t and t.can_go_back) then return false end ctl.send("pop") end,
    ["ctrl+Tab"] = function() if t and t.mode == "switcher" then ctl.send("next") return true end return false end,
    ["ctrl+shift+Tab"] = function() if t and t.mode == "switcher" then ctl.send("previous") return true end return false end,
  }
  root, t, ctl = control.make("Navigation", widget, full, { children = { area }, props = props,
    builders = { transition = true } })
  show(t.current, 1)
  local handle = { node = root, t = t }
  function handle.push(name) ctl.send("push", name) end
  function handle.pop() ctl.send("pop") end
  function handle.go(name) ctl.send("go", name) end
  function handle.next() ctl.send("next") end
  function handle.previous() ctl.send("previous") end
  return root, handle
end

return M
