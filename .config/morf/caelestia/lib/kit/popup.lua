-- Popups (the Popup archetype) on the engine's overlay layer: menus,
-- tooltips, dialogs, toasts, popovers -- and a shell's drawers, tracked
-- where they already are.
--
--     local menu = popup.make("menu", { items = {
--       { label = "Copy", icon = "content_copy", on_clicked = copy },
--       { label = "Wrap", checked = function() return wrap:get() end, on_toggled = set_wrap },
--     } })
--     menu.open(button)            -- beside its anchor; menu.close(), menu.toggle(button)
--
--     popup.make("dialog", { title = "Discard?", body = "...", width = 360,
--       buttons = { { label = "Cancel" }, { label = "Discard", on_clicked = discard } } }).open()
--
--     popup.toast { text = "Copied", timeout = 2500, root = node }
--     popup.tooltip(target, "Mute")
--
-- A popup's own content is `spec.content` (a node), or what its widget
-- builds from `items`, `title`, `body` and `buttons`; the theme's skin
-- draws its `background`. `on_opened`, `on_closed(reason)` and
-- `on_about_to_close(reason)` -- returning false keeps it open -- follow
-- it. `popup.track(node, spec)` gives a node that stays where it is (a
-- drawer) the same behaviour: Escape, a press outside, the stack.
local ui = require("morf.ui")
local control = require("lib.kit.control")

local M = {}
local function get(v) if type(v)=="function" then return v() end return v end

-- What each widget is unless its spec says otherwise.
local DEFAULTS = {
  menu = { placement = "bottom-start", close_policy = "escape+outside" },
  context_menu = { placement = "bottom-start", close_policy = "escape+outside" },
  submenu = { placement = "right-start", close_policy = "escape+outside" },
  popover = { placement = "bottom", close_policy = "escape+outside" },
  dropdown = { placement = "bottom-start", close_policy = "escape+outside" },
  tooltip = { placement = "top", close_policy = "none", focus_on_open = false },
  rich_tooltip = { placement = "top", close_policy = "escape", focus_on_open = false },
  dialog = { placement = "center", close_policy = "escape", modal = true, dim = true },
  alert_dialog = { placement = "center", close_policy = "none", modal = true, dim = true },
  bottom_sheet = { placement = "center", close_policy = "escape+outside", modal = true, dim = true },
  toast = { placement = "center", close_policy = "none", focus_on_open = false, padding = 12 },
  snackbar = { placement = "center", close_policy = "none", focus_on_open = false },
}

local function merged(widget, spec)
  local out = {}
  for k, v in pairs(DEFAULTS[widget] or {}) do out[k] = v end
  for k, v in pairs(spec or {}) do out[k] = v end
  out.widget = widget
  return out
end

--- The content a widget builds from its spec, when it is given none.
local function build_content(widget, spec, close)
  if spec.content then return spec.content end
  local kit = require("lib.kit.widgets")
  -- `width` describes the background, so its padding belongs outside the
  -- generated rows and dialog body. Keep bindings live when it resizes.
  local pad=spec.padding or 0
  local function content_width(fallback)
    return function()
      local outer=get(spec.width)
      return math.max(1,outer and outer-2*pad or get(fallback))
    end
  end
  if spec.items then
    local width=content_width(spec.item_width or 200)
    local rows = { gap = 0, width=width }
    for i, item in ipairs(spec.items) do
      local entry = {}
      for k, v in pairs(item) do entry[k] = v end
      entry.id = item.id or (spec.id and (spec.id .. "-item-" .. i)) or nil
      entry.width=function() return math.min(width(),get(spec.item_width) or width()) end
      entry.height=item.height or spec.item_height or 36
      local kind = "menu_item"
      if item.checked ~= nil then kind = item.group and "radio_menu_item" or "check_menu_item" end
      local clicked = item.on_clicked
      entry.on_clicked = function(...)
        if clicked then clicked(...) end
        -- A plain item closes its menu; a checkable one stays to be toggled again.
        if kind == "menu_item" then close("activated") end
      end
      rows[#rows + 1] = kit[kind](entry)
    end
    return ui.Column(rows)
  end
  -- A dialog: a title, a body and a row of buttons.
  local width=content_width(360)
  local function inner() return math.max(1,width()-40) end
  local column = { gap = 12, x = 20, y = 18, width = inner }
  -- The ink the theme writes in, not a colour of this file's choosing: a
  -- light dialog ground wants dark text.
  local has_kit, theme_kit = pcall(require, "kit")
  -- (A theme whose ground for this widget is not its usual one -- a dark
  -- tooltip or toast -- says which ink reads on it: `popup_ink`.)
  local themed = has_kit and type(theme_kit) == "table"
  -- In the theme's face, when there is a theme.
  local text = (themed and theme_kit.text) or require("morf.ui").Text
  local function ink_of(level)
    local own = themed and theme_kit.popup_ink and theme_kit.popup_ink(widget, level)
    return own or (themed and theme_kit.ink and theme_kit.ink(level)) or nil
  end
  local ink = spec.ink or ink_of("hi") or "#ffffff"
  local ink_lo = spec.ink or ink_of("lo") or ink
  -- Words alone (a tooltip, a toast): as wide as they are.
  if spec.text and not spec.title and not spec.body and not spec.buttons then
    return text { text = spec.text, font_size = 13, color = ink,
      width=spec.width and width or nil,wrap=spec.width~=nil }
  end
  if spec.title then
    column[#column + 1] = text { text = spec.title, font_size = 18, font_weight = 600, width = inner,
      wrap=true,color = ink }
  end
  if spec.body then
    column[#column + 1] = text { text = spec.body, font_size = 13, width = inner, wrap = true,
      color = ink_lo }
  end
  if spec.text then
    column[#column + 1] = text { text = spec.text, font_size = 13, color = ink_lo,width=inner,wrap=true }
  end
  local measures={width=1,height=1,clip=true}
  if spec.buttons then
    local actions={}
    local ready=morf.signal("kit.popup.actions."..tostring(actions),false)
    local caption=require("lib.kit.caption")
    local has_theme,theme=pcall(require,"theme")
    theme=(themed and theme_kit.theme) or (has_theme and type(theme)=="table" and theme) or {}
    local font_size=theme.size and theme.size.normal or 14
    for i,b in ipairs(spec.buttons) do actions[i]={spec=b} end
    local function visible(action) return get(action.spec.visible)~=false end
    local function desired(action)
      ready:get()
      local content=action.control and action.control.slots().content
      local fallback=action.measure and (action.measure.layout_width or 0)+32+(action.spec.icon and 26 or 0) or 0
      return math.max(1,get(action.spec.width) or math.max(96,caption.preferred_width(content) or fallback))
    end
    local function height(action) return math.max(1,get(action.spec.height) or 34) end
    local function total()
      local n,w,h=0,0,0
      for _,action in ipairs(actions) do
        if visible(action) then n,w,h=n+1,w+desired(action),math.max(h,height(action)) end
      end
      return w+math.max(0,n-1)*8,h,n
    end
    local function stacked() return total()>inner() end
    local function row_height()
      local _,h,n=total()
      if not stacked() then return h end
      h=math.max(0,n-1)*8
      for _,action in ipairs(actions) do if visible(action) then h=h+height(action) end end
      return h
    end
    local row={width=inner,height=row_height,visible=function() local _,_,n=total() return n>0 end}
    for i, b in ipairs(spec.buttons) do
      local action=actions[i]
      local function offset()
        local n=0
        for j=1,i-1 do
          if visible(actions[j]) then n=n+(stacked() and height(actions[j]) or desired(actions[j]))+8 end
        end
        return n
      end
      local clicked = b.on_clicked
      -- A destructive choice (Discard, Reset) or the suggested one is
      -- drawn as such by the theme.
      local kind=b.destructive and "destructive" or b.suggested and "suggested" or "push"
      local node,_,ctl=control.make("Press",kind,{widget=kind,
        id = b.id or (spec.id and (spec.id .. "-button-" .. i)) or nil,
        label=b.label,icon=b.icon,enabled=b.enabled,visible=b.visible,accessible_name=b.accessible_name,
        width=function() return stacked() and inner() or desired(action) end,height=b.height or 34,
        x=function() return stacked() and 0 or inner()-total()+offset() end,
        y=function() return stacked() and offset() or (row_height()-height(action))/2 end,
        on_clicked = function() if clicked then clicked() end close("activated") end })
      action.control=ctl
      -- Third-party skins may draw captions without the shared helper.
      -- Keep a text measurement for those; built-in skins need no duplicate.
      if not caption.preferred_width(ctl.slots().content) then
        action.measure=text {text=b.label or "",font_size=font_size,font_weight=500,opacity=0}
        measures[#measures+1]=action.measure
      end
      row[#row+1]=node
    end
    ready:set(true)
    -- End-aligned when there is room; full-width rows on narrow dialogs.
    column[#column + 1] = ui.Item(row)
  end
  -- The column's own margins count in the dialog's size.
  local body = ui.Column(column)
  return ui.Item { width = width, height = function() return (body.layout_height or 0) + 36 end,
    body,ui.Item(measures) }
end

--- A popup of `widget`. Returns `{ node, open(anchor), close(reason),
--- toggle(anchor), is_open(), t }`.
function M.make(widget, spec)
  spec = merged(widget, spec)
  local handle = {}
  local root, t, ctl
  -- Whether it is showing, for the theme's motion (`popup_motion`).
  local shown = morf.signal("kit.popup.shown." .. tostring(handle), false)
  -- "shut", "open", or "leaving": closed, but still in the layer while
  -- the theme's exit plays (`motion.linger` ms), taking no input.
  local phase = "shut"
  local motion, leave_timer
  -- Each opening's own on_close: a later one makes the earlier stale.
  local generation = 0
  local anchor_now
  local function linger() return motion and tonumber(motion.linger) or 0 end
  local function leave()
    phase = "leaving"
    shown:set(false)
    if leave_timer then leave_timer:cancel() end
    leave_timer = morf.timer(linger(), function()
      leave_timer = nil
      if phase == "leaving" then morf.overlay.close(root) end
    end, false)
  end
  -- (Out of the layer at once -- focus goes back, what is under it takes
  -- input -- and, with an exit to play, in again as a ghost: `closed`.)
  local function close(reason)
    if phase ~= "open" then return end
    if spec.on_about_to_close and spec.on_about_to_close(reason or "closed") == false then return end
    morf.overlay.close(root)
  end
  -- Built when first opened: until then it would hang from nothing.
  local function build()
    if root then return end
    local content = build_content(widget, spec, close)
    local pad = spec.padding or 0
    local props = {
      width = spec.width or function() return (content.layout_width or 0) + 2 * pad end,
      height = spec.height or function() return (content.layout_height or 0) + 2 * pad end,
      focus_policy = "none",
    }
    -- How the theme brings it in (`popup_motion`): its node's pose while
    -- shut and open, and the behaviours that carry it between them.
    local has_kit, theme_kit = pcall(require, "kit")
    motion = has_kit and type(theme_kit) == "table" and theme_kit.popup_motion
      and theme_kit.popup_motion(widget, spec, {
        open = function() return shown:get() end,
        size = function(axis) return root and root["layout_" .. axis] or 0 end,
      }) or nil
    if motion and spec.behavior ~= nil then motion = nil end
    if motion then for k, v in pairs(motion) do if k ~= "linger" then props[k] = v end end end
    root, t, ctl = control.make("Popup", widget, spec, { children = { content }, props = props })
    if pad > 0 then content.x, content.y = pad, pad end
    handle.node, handle.t = root, t
  end
  -- Into the layer: as itself, or as the ghost it leaves as.
  local function place(ghost, on_close)
    generation = generation + 1
    local mine = generation
    local options = { anchor = anchor_now, root = spec.root, placement = t.placement, gap = spec.gap,
      except = spec.except,
      on_close = function(reason) if mine == generation then on_close(reason) end end }
    -- (A ghost takes no input at all: a press goes through it to what is
    -- under it, as though it had gone.)
    root.enabled = not ghost
    if ghost then
      options.dim, options.modal, options.escape, options.outside, options.focus = false, false, false, false, false
      options.restore = false
    else
      options.dim, options.modal, options.escape, options.outside, options.focus =
        t.dim, t.modal, t.escape, t.outside, t.focus_on_open
    end
    morf.overlay.open(root, options)
  end
  local function closed(reason)
    if phase == "leaving" then
      -- The exit has played (or the content went): out of the layer.
      if reason == "closed" or reason == "gone" then phase = "shut" end
      return
    end
    if phase ~= "open" then return end
    -- Escape or a press outside, which the layer has done already: a
    -- popup that refuses opens again; one that goes leaves as a ghost
    -- while its exit plays. (A close asked for was asked already.)
    if reason ~= "closed" and spec.on_about_to_close and spec.on_about_to_close(reason) == false then
      ctl.send("close", reason)
      phase = "shut"
      handle.open(anchor_now)
      return
    end
    ctl.send("close", reason)
    if linger() > 0 and reason ~= "gone" then
      place(true, closed)
      leave()
    else
      phase = "shut"
      shown:set(false)
    end
  end
  function handle.open(anchor)
    build()
    if phase == "open" then return end
    if leave_timer then leave_timer:cancel() leave_timer = nil end
    local was = phase
    anchor_now = anchor or spec.anchor
    phase = "open"
    -- (Live before it says it opened: what opens it may focus inside.)
    root.enabled = true
    ctl.send("open")
    shown:set(true)
    -- (Taken back while leaving: out of the layer as a ghost and in again
    -- as itself, in the same turn.)
    if was == "leaving" then morf.overlay.close(root) end
    place(false, closed)
  end
  handle.close = close
  function handle.toggle(anchor) if phase == "open" then close("closed") else handle.open(anchor) end end
  function handle.is_open() return phase == "open" end
  return handle
end

--- A node that stays where it is, given a popup's behaviour while
--- `spec.open()` says it is open: Escape and a press outside (by
--- `close_policy`) call `spec.on_close(reason)`, which shuts it.
function M.track(node, spec)
  spec = spec or {}
  local behaviour = control.headless("Popup", {
    close_policy = spec.close_policy or "escape+outside", modal = spec.modal or false,
    focus_on_open = spec.focus_on_open or false, owner = node,
  })
  local t = behaviour.t
  local tracked = false
  morf.effect("kit.popup.track." .. tostring(node), function()
    local open = spec.open()
    if open == tracked then return end
    tracked = open
    if open then
      behaviour.send("open")
      morf.overlay.track(node, { escape = t.escape, outside = t.outside, modal = t.modal, focus = t.focus_on_open,
        anchor = spec.anchor, except = spec.except,
        on_close = function(reason)
          behaviour.send("close", reason)
          tracked = false
          if reason ~= "closed" and spec.on_close then spec.on_close(reason) end
        end })
    else
      morf.overlay.close(node)
    end
  end, { owner = node })
  return behaviour
end

--- A toast: `text` (or `content`), `timeout` (ms, 3000), `root` (the
--- surface's root, or `anchor` a node on it). Opens at once; returns the
--- popup.
function M.toast(spec)
  local toast = M.make("toast", spec)
  toast.open(spec.anchor)
  morf.timer(spec.timeout or 3000, function() toast.close("timeout") end, false)
  return toast
end

--- A tooltip on `target`: `text` (or a spec with `text`/`content`) after the
--- pointer rests on it for `delay` ms (600), gone when it leaves.
function M.tooltip(target, text, delay)
  local spec = type(text) == "table" and text or { text = text }
  spec.padding = spec.padding or 8
  local tip = M.make("tooltip", spec)
  local waiting
  morf.effect("kit.popup.tooltip." .. tostring(target), function()
    local over = target.hovered or target.contains_pointer
    if waiting then waiting:cancel() waiting = nil end
    if over then
      waiting = morf.timer(delay or 600, function() waiting = nil tip.open(target) end, false)
    else
      tip.close("left")
    end
  end, { owner = target })
  return tip
end

return M
