-- Material Settings composition, supplied only with model callbacks.
local morf=require("morf")
local ui=require("morf.ui")
local theme=require("theme")
local kit=require("kit")
local rows=require("themes.layouts.rows")
local C=theme.color
local V={WIDTH=430,RADIUS=15}
function V.focus_page(model,w,h)
  local rows={width=w,gap=12}
  for _,control in ipairs(model.focus) do
    local function on() return control.on()==true end
    local card={id="settings-focus-"..control.id,width=w,height=88,
      kit.card {anchors={fill=true},radius=20,color=function() return C.surfaceContainer end},
      kit.icon(control.icon,24,function() return on() and kit.ink("accent")() or kit.ink("lo")() end,
        {x=16,anchors={vertical_center=true}}),
      ui.Column {x=56,anchors={vertical_center=true},gap=4,
        kit.heading {id="settings-focus-title-"..control.id,scope="settings.focus",level="section",
          text=control.name,width=w-166,font_size=14,elide="right"},
        kit.subtitle {width=w-166,font_size=12,wrap=true,
          text=function()
            if control.id=="awake" then return on() and control.status() or "Allow the screen to sleep" end
            if control.id=="ringer" then return "Notification sounds and vibration" end
            return on() and "Notifications stay in history" or "Show notification popups"
          end},
      },
    }
    if control.id=="ringer" then
      card[#card+1]=kit.pill {id="utilities-toggle-ringer",anchors={right=true,right_margin=12,vertical_center=true},
        width=96,height=36,label=control.status,on_clicked=function() control.set() end}
    else
      card[#card+1]=kit.switch {id="utilities-toggle-"..control.id,accessible_name=control.name,
        anchors={right=true,right_margin=16,vertical_center=true},on=on,on_toggled=control.set}
    end
    rows[#rows+1]=ui.Item(card)
  end
  return (kit.scroll({id="settings-focus-scroll",width=w,height=h,clip=true,ui.Column(rows)}))
end
function V.build(model,w,h)
local M={TOGGLES=model.TOGGLES,DETAILS=model.DETAILS,detail=model.detail,RADIUS=V.RADIUS}
local CARD_W,GAP=math.min(408,w),12
local overview_viewport, overview_viewport_node, overview_viewport_t, overview_viewport_ctl
local TILE_H,TILE_GAP=60,8
local TILE_W=(CARD_W-24-TILE_GAP)/2
local TILE_ROWS=math.ceil(#M.TOGGLES/2)
local TILES_H=24+TILE_ROWS*TILE_H+(TILE_ROWS-1)*TILE_GAP
local function tile(t)
  local area, more
  local function on() return t.on() == true end
  local fg = rows.ink(on, true, C.onSurface)
  local function sub() return on() and fg():alpha(0.8) or C.onSurfaceVariant end
  area = kit.action {
    id = "utilities-toggle-" .. t.id,
    width = TILE_W, height = TILE_H, cursor = "pointer",
    on_clicked = function() t.set(not on()) end,
    kit.icon(t.icon, 22, fg, { x = 16, anchors = { vertical_center = true }, fill = t.fill or on }),
    ui.Column {
      x = 48, anchors = { vertical_center = true }, gap = 0,
      kit.heading { id = "settings-tile-title-" .. t.id, scope = "settings.overview", level = "caption",
        viewport=function() return overview_viewport end,
        width = TILE_W - 48 - (t.detail and 36 or 12), elide = "right",
        text = t.name or t.id, font_size = theme.size.normal, font_weight = 500, color = fg, ink = fg,
      },
      kit.subtitle {
        width = TILE_W - 48 - (t.detail and 36 or 12), elide = "right",
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
      anchors = { right = true, top = true, bottom = true, top_margin = 10, bottom_margin = 10, right_margin = 6 },
      width = 30, cursor = "pointer",
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
  for i = 1, #M.TOGGLES, 2 do
    local row = { gap = TILE_GAP }
    row[#row + 1] = tile(M.TOGGLES[i])
    if M.TOGGLES[i + 1] then row[#row + 1] = tile(M.TOGGLES[i + 1]) end
    rows[#rows + 1] = ui.Row(row)
  end
  return kit.card {
    id = "utilities-toggles",
    width = CARD_W, height = TILES_H, radius = M.RADIUS,
    ui.Column { x = 12, y = 12, gap = TILE_GAP, table.unpack(rows) },
  }
end

-- ----------------------------------------------------------------- sliders --

-- The output's volume and the screen's brightness, as Material 3
-- expressive sliders: a tall rounded track, the active part in the primary
-- colour up to a slim handle with a gap either side, the icon inside the
-- track's start and the value at its end. The level rides a spring; the
-- handle narrows while held. They read and set what the OSD does.
local SLIDER_H = 44
local SLIDERS_H = 16 + SLIDER_H + 12 + SLIDER_H + 16

local function slider(id, value, set, icon, name)
  return kit.slider { id = id, accessible_name = name, width = CARD_W - 32, value = value, set = set, icon = icon }
end

local function sliders()
  local osd = model.levels
  return kit.card {
    id = "utilities-sliders",
    width = CARD_W, height = SLIDERS_H, radius = M.RADIUS,
    ui.Column {
      x = 16, y = 12, gap = 4,
      slider("utilities-volume", function() return (osd.volume()) end, osd.set_volume, osd.volume_icon, "Volume"),
      slider("utilities-brightness", function() return (osd.brightness()) end, osd.set_brightness, osd.brightness_icon, "Brightness"),
    },
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
local heading = kit.heading {id="settings-title",text="Controls",scope="settings.overview",width=CARD_W,height=30}
local cards = { heading, sliders(), capture_button, toggles() }

--- The page's height: the cards and their gaps.
function M.height()
  return 3 * GAP + 30 + SLIDERS_H + 40 + TILES_H
end


--- The Settings page of the right panel: the cards, top down, and the
--- detail pages (Network, Bluetooth, Sound) beside them, which slide in
--- over them as a tile's ">" opens one.
local DETAIL_HEAD = 52
local SWITCH = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel }
function M.page(w, h)
  overview_viewport_node, overview_viewport, overview_viewport_t, overview_viewport_ctl = kit.scroll({id="settings-overview-scroll",width=w,height=h,clip=true,
    ui.Column {gap=GAP,table.unpack(cards)}})
  local main = ui.Item {
    id = "utilities", width = w, height = h, clip = true,
    overview_viewport_node,
  }
  local dh = function() return h() - DETAIL_HEAD end
  local stack = {}
  local names = {}
  for _, d in ipairs(M.DETAILS) do
    names[d.key] = d.name
    stack[#stack + 1] = ui.Item {
      id = "settings-detail-" .. d.key,
      y = DETAIL_HEAD, width = w, height = dh,
      visible = function() return M.detail:get() == d.key end,
      opacity=function() return M.detail:get()==d.key and 1 or 0 end,
      translate_x=function() return M.detail:get()==d.key and 0 or 20 end,
      behavior={opacity={duration=theme.duration.small},translate_x=SWITCH},
      model.page_content(d.key, w, dh),
    }
  end
  local back = kit.action {
    id = "settings-back", accessible_name = "Back",
    width = 40, height = 40, y = 2, cursor = "pointer",
    on_clicked = model.back,
    kit.icon("arrow_back", 22, kit.ink("hi"), { anchors = { center_in = true } }),
  }
  kit.hover(back, function(hovered) return hovered and C.onSurface:alpha(0.08) or C.onSurface:alpha(0) end, 20)
  local detail = ui.Item {
    id = "settings-detail", width = w, height = h,
    back,
    kit.heading { id = "settings-detail-heading", scope = "settings.detail",
      x = 50, y = 20, width=w-54,elide="right",
      text = function() return names[M.detail:get()] or "" end,
      font_size = theme.size.large, font_weight = 500,
    },
    kit.subtitle {id="settings-breadcrumb",x=50,y=2,width=w-54,font_size=10,elide="right",text=model.breadcrumb},
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
return {node=node,height=M.height}
end
return V
