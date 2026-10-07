-- The dashboard: the drawer, its tabs, the pages side by side and the liquid
-- choreography of their cards (kit.collect). The overview tab is a bay of
-- instruments (dashboard_overview_cards). Every theme draws this layout
-- through its kit; data and actions come from the dashboard model.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local V = {}
function V.build(model)
local M = {}
local PAD, GAP = 16, 12
-- The cards of each tab are not rectangles but layers of one distance
-- field under the pages (kit.collect): they bud out as the dashboard opens
-- or a tab comes in, fuse into one another while they move, and pull apart
-- as they settle.
local LAYERS = { {}, {}, {}, {}, {}, {} }
-- On a phone (a desk narrower than the overview) the overview is one
-- column the desk's width: the cards stretched across it, a row each.
local responsive = require("responsive")
local COMPACT = responsive.compact()
-- A phone's dashboard is the whole desk: every tab the same size, its page
-- scrolled in it, the tabs (icons alone) along the bottom by the edge it
-- rose from.
-- On a phone every tab is the one size, scrolled in it; on a desk each
-- tab has its own (responsive.dashboard), and the drawer eases between them.
local CW, VIEW_H = responsive.dashboard()
local PANEL_W = COMPACT and (responsive.portrait() and responsive.sheet_width()
  or responsive.desk_width() - 2 * theme.BORDER) or nil
-- The tabs by the edge it comes from: the bottom one, on a phone.
local TABS_BELOW = COMPACT and responsive.portrait()
local PHONE=responsive.portrait()
-- Four fifths of the desk: the fifth above it is to tap it shut.
local TABS_H = 68            -- icons, labels, indicator and hairline
local function panel_height() return math.floor((responsive.desk_height() - 2 * theme.BORDER) * 0.8) end
local function view_height() local _,h=responsive.dashboard() return math.max(1,h) end
local subpages, PAGE = {}, {{840,439}}
for i=2,6 do
  kit.collect(LAYERS[i])
  local page = model.page(i)
  subpages[i], PAGE[i] = page.page, {page.WIDTH,page.HEIGHT}
end
kit.collect(LAYERS[1])
local ROW1, ROW2 = 132, 295

M.tab = model.tab

--- The panel's size on tab `i`.
function M.size(i)
  if COMPACT then return PANEL_W, panel_height() end
  local p = PAGE[i] or PAGE[1]
  return p[1] + 2 * PAD, TABS_H + PAD + p[2] + PAD - 1
end
local function width() return (M.size(M.tab:get())) end
local function height() local _, h = M.size(M.tab:get()) return h end

-- The drawer's and the pages' pace between tabs, fitted to films of the
-- reference: most of the way in the first hundred milliseconds, settled in
-- about a third of a second.
local SWITCH = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel }
local opened = model.opened



-- ------------------------------------------------------------------- tabs --

local TABS = model.tabs

-- The row follows the drawer as it eases between the tabs' sizes (a
-- growing row), and names its tabs after their labels:
-- `dashboard-tab-<name>`.
local function tabs()
  local row = kit.tabs { id = "dashboard", accessible_name = "Dashboard", tabs = TABS, tab = M.tab,
    width = width, height = TABS_H, pad = PAD, ids = "name", growing = true, reorderable = true,
    icons_only = COMPACT }
  if not TABS_BELOW then return row end
  return ui.Item { y = function() return panel_height()-TABS_H end, width = PANEL_W, height = TABS_H, row }
end

-- ---------------------------------------------------------------- cards --

local cards = require("themes.layouts.views.dashboard_overview_cards")(model, ROW1, ROW2, GAP)

-- -------------------------------------------------------------- the panel --

local function dashboard_tab()
  if cards.page then
    local w = COMPACT and CW or (responsive.dashboard("overview"))
    local node, h = cards.page(w)
    PAGE[1] = { w, h }
    return node
  end
  if COMPACT then
    local side = 130
    local rings_h, media_h = 150, 260
    PAGE[1] = { CW, ROW1 + GAP + ROW1 + GAP + ROW2 + GAP + rings_h + GAP + media_h }
    return ui.Column {
      gap = GAP,
      cards.user(CW),
      cards.weather(CW),
      ui.Row { gap = GAP, cards.clock(side), cards.calendar(CW - side - GAP) },
      cards.resources(CW, rings_h),
      cards.media(CW, media_h),
    }
  end
  return ui.Row {
    gap = GAP,
    ui.Column {
      gap = GAP,
      ui.Row { gap = GAP, cards.weather(), cards.user() },
      ui.Row { gap = GAP, cards.clock(), cards.calendar(), cards.resources() },
    },
    cards.media(),
  }
end

local pages = {
  dashboard_tab(),
  subpages[2],
  subpages[3],
  subpages[4],
  subpages[5],
  subpages[6],
}
local scroll_positions, scroll_viewports = {}, {}
if COMPACT then
  -- On a phone every page scrolls in the one view the dashboard has; while
  -- it runs on below, a dashed line along the view's foot says so.
  for i, page in ipairs(pages) do
    local initial_h = (PAGE[i] or PAGE[1])[2]
    local function content_h() return i==6 and view_height() or initial_h end
    local node, _, t = kit.scroll({ id = "dashboard-scroll-" .. i, width = CW, height = view_height, clip = true,
      ui.Item { width = CW, height = content_h, page } })
    scroll_positions[i] = t
    local more = ui.Path {
      id = "dashboard-more-" .. i, x = 0, y = function() return view_height()-2 end, width = CW, height = 2, view_box = { 0, 0, CW, 2 },
      d = ("M0 1 H%g"):format(CW), fill_color = "transparent", stroke_width = 2, dash = { 10, 8 },
      stroke_color = function() return theme.color.onSurfaceVariant end,
      opacity = function() return (content_h() > view_height() + 4 and (t.position_y or 0) < 0.99) and 0.8 or 0 end,
      behavior = { opacity = { duration = theme.duration.small } },
    }
    -- A phone's tabs are icons alone: the page says its name.
    local P = require("themes.layouts.page")
    local top = P.HEADER_H + P.GAP
    scroll_viewports[i] = ui.Item { id="dashboard-viewport-"..i,
      y=top,width=CW,height=view_height,clip=true,node,more }
    pages[i] = ui.Item { width = CW, height = function() return view_height()+top end,
      P.header { id = "dashboard-head-" .. i, width = CW, title = TABS[i].name },
      scroll_viewports[i] }
    PAGE[i] = { CW, VIEW_H + top }
  end
end
kit.collect(nil)

-- ----------------------------------------------------------------- liquid --

-- While a tab's cards move, its field's seams are wide and soft, so
-- neighbours fuse; once they settle the seams close to nothing and the
-- cards stand crisp and apart, exactly as the reference's. One field per
-- tab (a field draws at most sixteen layers, and a tab's cards are its
-- own), laid under the pages.
local liquid = { }
for i = 1, #LAYERS do liquid[i] = morf.signal("caelestia.dashboard.liquid." .. i, false) end
local calm = {}
local function stir(i, ms)
  liquid[i]:set(true)
  if calm[i] then calm[i]:cancel() end
  calm[i] = morf.timer(ms, function() calm[i] = nil liquid[i]:set(false) end, false)
end

local cards_fields = {}
for i, list in ipairs(LAYERS) do
  if #list > 0 then
    local field = {
      id = "dashboard-cards-" .. i,
      anchors = { fill = true },
      blend = function() return theme.motion.liquid_cards ~= false and liquid[i]:get() and 6 or 0 end,
      behavior = { blend = { duration = 360, easing = theme.ease.standard } },
    }
    for _, entry in ipairs(list) do field[#field + 1] = entry.shape end
    local node=ui.Sdf(field)
    if scroll_viewports[i] then
      -- Tracked card backgrounds follow the scrolled content too. Clip
      -- them to its viewport so they cannot paint behind the fixed title.
      node.z=-1
      ui.reparent(node,scroll_viewports[i])
    else cards_fields[#cards_fields + 1]=node end
  end
end

local running = {}
--- The cards of tab `i` come in (`coming`) -- each grows evenly about its
--- own centre from a little smaller as it fades in, one just after the
--- other -- or shrink a touch and fade as they go. While they move the
--- field's seams soften a little, so neighbours touch like liquid; at rest
--- they are crisp and apart.
local function bud(i, coming)
  for _, r in ipairs(running[i] or {}) do r:stop() end
  running[i] = {}
  local duration
  running[i], duration = theme.motion.entries(LAYERS[i] or {}, coming, { stagger = 22 })
  stir(i, duration)

end
M.bud = bud

-- Where page `i` starts along the track: the pages side by side, a
-- padding's width apart on either side.
local function offset(i)
  local x = 0
  for k = 1, i - 1 do x = x + PAGE[k][1] + PAD * 2 end
  return x
end

-- The tabs slide sideways as the reference's do, while the drawer eases to
-- the new tab's size: the strip is the panel less its padding, so it
-- follows the drawer as it moves.
local strip = ui.Item {
  id = "dashboard-pages",
  anchors = TABS_BELOW and { fill = true, left_margin = PAD, right_margin = PAD, top_margin = PAD, bottom_margin = TABS_H + PAD }
    or { fill = true, left_margin = PAD, right_margin = PAD, top_margin = TABS_H + PAD, bottom_margin = PAD - 1 },
  clip = true,
}
local displayed = model.displayed
local track = ui.Row {
  id="dashboard-page-track",
  gap = PAD * 2,

  translate_x = PHONE and -offset(M.tab:get()) or function() return -offset(displayed:get()) end,
  behavior = (theme.motion.page_wipe or PHONE) and {} or { translate_x = SWITCH },
  table.unpack(pages),
}
for _, f in ipairs(cards_fields) do ui.reparent(f, strip) end
ui.reparent(track, strip)
local page_wipe = not PHONE and theme.motion.page_wipe and theme.motion.page_wipe(strip, function() return width()-PAD*2 end, "dashboard")
local pager=PHONE and require("pager_drag").new {
  id="dashboard",track=track,tab=M.tab,count=#TABS,offset=offset,
  prepare=function()
    for _,handles in pairs(running) do for _,h in ipairs(handles) do h:stop() end end
    running={}
    for _,entries in ipairs(LAYERS) do for _,entry in ipairs(entries) do
      entry.node.opacity,entry.node.scale=1,1
      if entry.shape then entry.shape.opacity=1 end
    end end
  end,
}

-- Behind everything on the panel, so the panel is in the surface's input
-- region: the pointer is seen anywhere on it, and `contains_pointer` with it.
local background = ui.MouseArea { anchors = { fill = true }, z = -1 }

local content = ui.Item {
  anchors = { fill = true },
  on_panned = require("phone_gestures").pan { drawer="dashboard", dismiss="down", pager=pager,
    can_dismiss=function()
      local position=scroll_positions[M.tab:get()]
      return not position or (position.position_y or 0)<=0
    end,
  },
  on_swiped = require("phone_gestures").panel {
    tab = M.tab, count = #TABS, dismiss = "down", close = function() require("dashboard").drawer.set(false) end,
    can_dismiss = function()
      local position = scroll_positions[M.tab:get()]
      return not position or (position.position_y or 0) <= 0
    end,
  },
  background,
  tabs(),
  strip,
}

-- Opening, the chosen tab's cards bud out of the drawer as it grows;
-- closing, they melt back as it withdraws. Switching tabs, the outgoing
-- cards melt while the incoming ones bud, all in the one field.
local was_open, was_tab = false, M.tab:get()
morf.effect("caelestia.dashboard.liquid", function()
  local open, tab = opened:get(), M.tab:get()
  if not page_wipe then model.present(tab) end
  if open ~= was_open then
    was_open = open
    if page_wipe then page_wipe(function() model.present(tab) end, true) end
    bud(tab, open)
  elseif open and tab ~= was_tab then
    if page_wipe then page_wipe(function() model.present(tab) bud(tab, true) end,false,{
      index=tab,name=TABS[tab].name,key=TABS[tab].key,
    })
    else bud(was_tab, false) bud(tab, true) end
  end
  was_tab = tab
end)

return { content=content, width=width, height=height, size=M.size, bud=bud,
  edge="top", props={behavior={width=SWITCH,height=SWITCH}} }
end
return V
