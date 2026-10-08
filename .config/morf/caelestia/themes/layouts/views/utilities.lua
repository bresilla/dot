-- Material Settings composition, supplied only with model callbacks.
local morf=require("morf")
local ui=require("morf.ui")
local theme=require("theme")
local kit=require("kit")
local rows=require("themes.layouts.rows")
local P=require("themes.layouts.page")
local C=theme.color
local V={WIDTH=430,RADIUS=15}
--- The Theme page: dark or light, and Lule one page in.
function V.theme_page(model,w,h)
  local config=require("config")
  local function dark() return config.get("theme.mode")~="light" end
  local inner=P.inner(w)
  return P.page {id="settings-theme-scroll",width=w,height=h,
    P.section {id="settings-theme",width=w,title="Appearance",
      P.row {id="settings-theme-mode",width=inner,icon=function() return dark() and "dark_mode" or "light_mode" end,
        title="Dark mode",
        subtitle=function() return dark() and "The shell in dark colours" or "The shell in light colours" end,
        trailing=P.switch {id="utilities-toggle-theme-mode",name="Dark mode",on=dark,
          on_toggled=function(on) config.set("theme.mode",on and "dark" or "light") end}},
      P.row {id="settings-theme-lule",width=inner,icon="palette",title="Lule",
        subtitle="Wallpaper, colours, the shell's theme and font",trailing=P.chevron(),
        on_clicked=function() model.request("theme/lule") end},
    },
  }
end

function V.focus_page(model,w,h)
  local inner=P.inner(w)
  local section={id="settings-focus",width=w,title="Interruptions"}
  for _,control in ipairs(model.focus) do
    local function on() return control.on()==true end
    local trailing
    if control.id=="ringer" then
      trailing=P.button {id="utilities-toggle-ringer",label=control.status,on_clicked=function() control.set() end}
    else
      trailing=P.switch {id="utilities-toggle-"..control.id,name=control.name,on=on,on_toggled=control.set}
    end
    section[#section+1]=P.row {id="settings-focus-"..control.id,width=inner,icon=control.icon,on=on,
      title=control.name,trailing=trailing,
      subtitle=function()
        if control.id=="awake" then return on() and control.status() or "Allow the screen to sleep" end
        if control.id=="ringer" then return "Notification sounds and vibration" end
        return on() and "Notifications stay in history" or "Show notification popups"
      end}
  end
  return P.page {id="settings-focus-scroll",width=w,height=h,P.section(section)}
end
function V.build(model,w,h)
local M={TOGGLES=model.TOGGLES,DETAILS=model.DETAILS,detail=model.detail,RADIUS=V.RADIUS}
-- A side panel's cards are 408 wide; a sheet's (a phone's quick settings)
-- take its width.
local CARD_W,GAP=w,P.GAP
local overview_viewport, overview_viewport_node, overview_viewport_t, overview_viewport_ctl
local TILE_H,TILE_GAP=60,8
local TILE_COLUMNS=CARD_W-2*P.PAD>=2*176+TILE_GAP and 2 or 1
local TILE_W=(CARD_W-2*P.PAD-(TILE_COLUMNS-1)*TILE_GAP)/TILE_COLUMNS
local TILE_ROWS=math.ceil(#M.TOGGLES/TILE_COLUMNS)
local TILES_H=2*P.PAD+TILE_ROWS*TILE_H+(TILE_ROWS-1)*TILE_GAP
local function tile(t)
  local area, more
  local function on() return t.on() == true end
  local fg = rows.ink(on, true, C.onSurface)
  local function sub() return on() and fg():alpha(0.8) or C.onSurfaceVariant end
  area = kit.action {
    id = "utilities-toggle-" .. t.id,
    accessible_name = t.name or t.id,
    width = TILE_W, height = TILE_H, cursor = "pointer",
    on_clicked = function() t.set(not on()) end,
    kit.icon(t.icon, 22, fg, { x = 16, anchors = { vertical_center = true }, fill = t.fill or on }),
    ui.Column {
      x = 48, anchors = { vertical_center = true }, gap = 0,
      kit.heading { id = "settings-tile-title-" .. t.id, scope = "settings.overview", level = "caption",
        viewport=function() return overview_viewport end,
        width = TILE_W - 48 - (t.detail and 46 or 12), elide = "right",
        text = t.name or t.id, font_size = theme.size.normal, font_weight = 500, color = fg, ink = fg,
      },
      kit.subtitle {
        width = TILE_W - 48 - (t.detail and 46 or 12), elide = "right",
        text = function()
          local s = t.status and t.status()
          if s and s ~= "" then return s end
          return on() and "On" or "Off"
        end,
        font_size = theme.size.small, color = sub,
      },
    },
  }
  -- The theme's stateful ground: its hover, its press (the chevron's too)
  -- and its mark of a tile that is on.
  ui.reparent(kit.state_surface { id = "utilities-toggle-" .. t.id .. "-shape", area = area, on = on,
    height = TILE_H, tone = "primary", z = -1,
    pressed = function() return more ~= nil and more.pressed end }, area)
  if t.detail then
    more = kit.action {
      id = "utilities-more-" .. t.id,
      accessible_name = "Open " .. (t.name or t.id),
      anchors = { right = true, top = true, bottom = true, top_margin = 8, bottom_margin = 8, right_margin = 6 },
      width = 40, cursor = "pointer",
      on_clicked = function() M.detail:set(t.detail) end,
      kit.icon("chevron_right", 22, fg, { anchors = { center_in = true } }),
    }
    kit.hover(more, function(hovered) return hovered and fg():alpha(0.12) or fg():alpha(0) end, 10)
    ui.reparent(more, area)
  end
  return area
end

local function toggles()
  local rows = {}
  for i = 1, #M.TOGGLES, TILE_COLUMNS do
    local row = { gap = TILE_GAP }
    row[#row + 1] = tile(M.TOGGLES[i])
    if TILE_COLUMNS==2 and M.TOGGLES[i + 1] then row[#row + 1] = tile(M.TOGGLES[i + 1]) end
    rows[#rows + 1] = ui.Row(row)
  end
  return kit.card {
    id = "utilities-toggles",
    width = CARD_W, height = TILES_H, radius = kit.round(P.RADIUS),
    ui.Column { x = P.PAD, y = P.PAD, gap = TILE_GAP, table.unpack(rows) },
  }
end

-- ----------------------------------------------------------------- sliders --

-- The output's volume and the screen's brightness, as Material 3
-- expressive sliders: a tall rounded track, the active part in the primary
-- colour up to a slim handle with a gap either side, the icon inside the
-- track's start and the value at its end. The handle follows the hand
-- directly while held. They read and set what the OSD does.
-- The shell's scale: -1 (half) to 1 (twice) along the slider, 0 -- the
-- compositor's own -- in its middle, in steps of 0.05.
local function scale_now()
  local v = tonumber(require("config").get("appearance.zoom")) or 0
  return (math.max(-1, math.min(1, v)) + 1) / 2
end
local function scale_set(position)
  local v = math.max(0, math.min(1, position)) * 2 - 1
  if not require("themes.ui_scale").compositor then v = math.floor(v / 0.05 + 0.5) * 0.05 end
  if math.abs(v) < 1e-6 then v = 0 end
  require("config").set("appearance.zoom", v)
end
local function scale_reading(position)
  local scale = require("themes.ui_scale")
  if scale.compositor then return ("%.2f×"):format(scale.display_scale(position * 2 - 1)) end
  local v = math.floor((position * 2 - 1) * 100 + 0.5)
  return v == 0 and "0" or ("%+d%%"):format(v)
end

local function slider(id, value, set, icon, name, reading)
  return kit.slider { id = id, accessible_name = name, width = CARD_W - 2 * P.PAD, value = value, set = set, icon = icon,
    reading = reading, live = id ~= "utilities-scale" or not require("themes.ui_scale").compositor }
end

local function sliders()
  local osd = model.levels
  local column=ui.Column {
    x = P.PAD, y = P.PAD, gap = 4,
    slider("utilities-volume", function() return (osd.volume()) end, osd.set_volume, osd.volume_icon, "Volume"),
    slider("utilities-brightness", function() return (osd.brightness()) end, osd.set_brightness, osd.brightness_icon, "Brightness"),
    slider("utilities-scale", scale_now, scale_set, "zoom_in",
      require("themes.ui_scale").compositor and "Display scale" or "Scale", scale_reading),
  }
  return kit.card {
    id = "utilities-sliders",
    width = CARD_W, height = function() return (column.layout_height or 0)+2*P.PAD end,
    radius = kit.round(P.RADIUS), column,
  }
end

-- ------------------------------------------------------------------- power --

-- -------------------------------------------------------------------- page --

local capture_button = kit.pill {
  id = "utilities-capture", width = CARD_W, height = 40,
  icon = "screenshot_monitor", label = "Screenshot / Record",
  on_clicked = function()
    model.capture()
  end,
}
local cards = { sliders(), capture_button, toggles() }

--- The page's height: the cards and their gaps.
function M.height()
  return 2 * GAP + (cards[1].layout_height or 0) + (cards[2].layout_height or 0) + TILES_H
end


--- The Settings page of the right panel: the cards, top down, and the
--- detail pages (Network, Bluetooth, Sound) beside them, which slide in
--- over them as a tile's ">" opens one. The panel's frame draws the head:
--- "Settings", or a detail's name with the way back (`M.head`).
local SWITCH = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel }
function M.page(w, h)
  overview_viewport_node, overview_viewport, overview_viewport_t, overview_viewport_ctl = kit.scroll({id="settings-overview-scroll",width=w,height=h,clip=true,
    ui.Column {gap=GAP,table.unpack(cards)}})
  local main = ui.Item {
    id = "utilities", width = w, height = h, clip = true,
    overview_viewport_node,
  }
  local stack = {}
  local names = {}
  for _, d in ipairs(M.DETAILS) do
    names[d.key] = d.name
    stack[#stack + 1] = ui.Item {
      id = "settings-detail-" .. d.key,
      width = w, height = h,
      visible = function() return M.detail:get() == d.key end,
      opacity=function() return M.detail:get()==d.key and 1 or 0 end,
      translate_x=function() return M.detail:get()==d.key and 0 or 20 end,
      behavior={opacity={duration=theme.duration.small},translate_x=SWITCH},
      model.page_content(d.key, w, h),
    }
  end
  M.head = {
    title = function() return names[M.detail:get()] or "Settings" end,
    subtitle = function() return M.detail:get() ~= "" and model.breadcrumb() or "" end,
    back = model.back, back_id = "settings-back",
    can_back = function() return M.detail:get() ~= "" end,
    -- Read in afresh as the overview or a detail comes on show.
    active = function()
      local key = M.detail:get()
      return require("presentation").active(key == "" and "settings.overview" or "settings." .. key)()
    end,
  }
  local detail = ui.Item {
    id = "settings-detail", width = w, height = h,
    table.unpack(stack),
  }
  -- The last detail shown stays drawn while it slides away. The pages are
  -- a Navigation stack: with focus inside, Alt+Left and the back button pop.
  return ui.Item {
    width = w, height = h, clip = true,
    shortcuts = model.navigation.shortcuts(),
    ui.Row {
      gap = 22,
      translate_x = function() return M.detail:get() ~= "" and -(w + 22) or 0 end,
      behavior = { translate_x = SWITCH },
      main, detail,
    },
  }
end


local node=M.page(w,h)
morf.effect("material.settings.present",function() model.present(model.detail:get()) end)
local running={}
morf.effect("material.settings.shown",function()
  for _, handle in ipairs(running) do handle:stop() end
  running=kit.bud(cards,model.opened:get())
end,{owner=node})
return {node=node,height=M.height,head=M.head}
end
return V
