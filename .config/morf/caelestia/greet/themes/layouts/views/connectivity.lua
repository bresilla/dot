-- The right panel's Network and Bluetooth pages: what the bar's popouts
-- had, given the panel's height. Network: Wi-Fi on or off, the networks
-- (the one in use first, then by strength; a click joins one) and a
-- rescan. Bluetooth: on or off, discovery, the devices (connected, then
-- paired, then by name; a click connects or disconnects) and the settings
-- program. The injected model owns service reads and actions; this builder
-- preserves the original cards, row positions and footer buttons.

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local P = require("themes.layouts.page")

local M = {}

local MAX_ROWS = 64

--- Up to MAX_ROWS rows, each shown while `count()` reaches it; one saying
--- `none` while there are none.
local function list(w, prefix, count, row, none)
  local inner = P.inner(w)
  local col = { width = inner, gap = P.ROW_GAP }
  for i = 1, MAX_ROWS do
    col[#col + 1] = ui.Item { id = prefix .. i, width = inner, height = P.ROW_H,
      visible = function() return i <= count() end, row(i, inner) }
  end
  col[#col + 1] = P.row { width = inner, icon = "info", on = function() return false end, title = none,
    visible = function() return count() == 0 end }
  return ui.Column(col)
end

--- The one action under a list, the card's width.
local function action(w, spec)
  spec.width = P.inner(w)
  return P.buttons { width = P.inner(w), spec }
end

--- What a page without its service says, in place of its lists.
local function missing(w, icon, title, text, available)
  local node = P.empty { width = w, icon = icon, title = title, text = text }
  node.visible = function() return not available() end
  return node
end

--- What the last action said ("a password is needed"), under the list.
local function status(id, model, w)
  local node = kit.subtitle { id = id, width = P.inner(w), wrap = true, font_size = P.SUB,
    text = function() return model.message:get() or "" end,
    color = function() return model.failed:get() and theme.color.error or theme.color.onSurfaceVariant end }
  node.visible = function() return (model.message:get() or "") ~= "" end
  return node
end

-- ----------------------------------------------------------------- network --

local function network_page(model, w, h)
  local available = model.available
  local inner = P.inner(w)
  local networks = P.section { id = "network-list", width = w, title = "Networks",
    visible = available,
    list(w, "network-row-", function() return #model.list() end, function(i, rw)
      local function ap() return model.list()[i] or {} end
      return P.row { id = "network-ap-" .. i, width = rw, on = function() return ap().in_use == true end,
        icon = function() return model.signal_icon(ap().strength) end,
        title = function() return ap().ssid or "" end,
        subtitle = function()
          local a = ap()
          if a.in_use then return "Connected" end
          return a.secure and "Secured" or "Open"
        end,
        trailing = kit.icon(function() return ap().secure and "lock" or "" end, 16, kit.ink("lo")),
        on_clicked = function() model.choose(ap()) end }
    end, function() return model.enabled() and "No networks found" or "Turn on Wi-Fi to find networks." end),
    status("network-status", model, w),
    action(w, { id = "network-rescan", icon = "wifi_find", label = "Rescan networks",
      on_clicked = function() model.scan() end }),
  }
  return ui.Item { id = "network-page", width = w, height = h, P.page { id = "network-scroll", width = w, height = h,
    P.section { id = "wifi", caption_id = "wifi-title", width = w, title = "Wi-Fi",
      P.row { id = "network-enabled", width = inner, icon = "wifi", on = model.enabled, title = "Enabled",
        subtitle = function()
          if not available() then return "No network manager" end
          local count = #model.list()
          return ("%d network%s available"):format(count, count == 1 and "" or "s")
        end,
        trailing = P.switch { id = "network-wifi", name = "Wi-Fi", on = model.enabled, on_toggled = model.set_enabled } },
    },
    networks,
    missing(w, "wifi_off", "No network manager", "NetworkManager is not running, so there are no networks to list.",
      available),
  } }
end

-- --------------------------------------------------------------- bluetooth --

local function bluetooth_page(model, w, h)
  local available = model.available
  local inner = P.inner(w)
  local devices = P.section { id = "bluetooth-list", width = w, title = "Devices",
    visible = available,
    list(w, "bluetooth-row-", function() return #model.list() end, function(i, rw)
      local function dev() return model.list()[i] or {} end
      local function on() return dev().connected == true end
      return P.row { id = "bluetooth-device-" .. i, width = rw, on = on,
        icon = function() return on() and "bluetooth_connected" or "bluetooth" end,
        title = function() local d = dev() return d.alias or d.name or d.address or "" end,
        subtitle = function()
          local d = dev()
          if d.connected then return "Connected" end
          return d.paired and "Paired" or "Not paired"
        end,
        on_clicked = function() model.choose(dev()) end }
    end, function() return model.enabled() and "No devices" or "Turn on Bluetooth to find devices." end),
    status("bluetooth-status", model, w),
    action(w, { id = "bluetooth-settings", icon = "settings", label = "Open settings",
      on_clicked = function() model.open_settings() end }),
  }
  return ui.Item { id = "bluetooth-page", width = w, height = h, P.page { id = "bluetooth-scroll", width = w, height = h,
    P.section { id = "bluetooth", caption_id = "bluetooth-title", width = w, title = "Bluetooth",
      P.row { id = "bluetooth-enabled", width = inner, icon = "bluetooth", on = model.enabled, title = "Enabled",
        subtitle = function()
          if not available() then return "No Bluetooth adapter" end
          local count = #model.list()
          return ("%d device%s"):format(count, count == 1 and "" or "s")
        end,
        trailing = P.switch { id = "bluetooth-power", name = "Bluetooth", on = model.enabled,
          on_toggled = model.set_enabled } },
      P.row { id = "bluetooth-discovering", width = inner, icon = "bluetooth_searching", on = model.discovering,
        title = "Discovering", subtitle = "Look for devices nearby",
        trailing = P.switch { id = "bluetooth-discover", name = "Discovering", on = model.discovering,
          on_toggled = model.scan } },
    },
    devices,
    missing(w, "bluetooth_disabled", "No Bluetooth adapter", "There is no Bluetooth adapter to use.", available),
  } }
end

local function mobile_page(model,w,h)
  local inner=P.inner(w)
  return ui.Item {id="mobile-page",width=w,height=h,
    P.page {id="mobile-scroll",width=w,height=h,active=model.active,
      P.section {id="mobile-radio",width=w,title="Mobile data",visible=model.available,
        P.row {id="mobile-enabled",width=inner,icon="signal_cellular_alt",title="Enabled",on=model.enabled,
          subtitle=model.status,
          trailing=P.switch {id="mobile-data",name="Mobile data",on=model.enabled,
            on_toggled=function(on) if model.can_toggle() then model.set_enabled(on) end end}},
        P.row {id="mobile-carrier",width=inner,icon="cell_tower",title=model.carrier,
          subtitle=model.signal,on=function() return false end},
      },
      P.section {id="mobile-connections",width=w,title="Connections",visible=model.available,
        list(w,"mobile-row-",function() return #model.list() end,function(i,rw)
          local function row() return model.list()[i] or {} end
          local function connected() return (row().active or "")~="" end
          return P.row {id="mobile-profile-"..i,width=rw,icon="sim_card",title=function() return row().name or "" end,
            on=connected,subtitle=function()
              local r=row()
              local state=({activated="Connected",activating="Connecting…",deactivating="Disconnecting…"})[r.state] or "Disconnected"
              return state.." · "..((r.apn or "")~="" and ("APN: "..r.apn) or r.auto_apn and "Automatic APN" or "Provider APN")
            end,
            trailing=P.button {id="mobile-connect-"..i,
              label=function() return connected() and "Disconnect" or "Connect" end,
              visible=function() return not model.pending:get() and (connected() or model.can_connect()) end,
              on_clicked=function() model.choose(row()) end}}
        end,"No saved mobile connections"),
        action(w,{id="mobile-setup",icon="add",label="Set up automatically",
          visible=function() return #model.list()==0 and model.can_connect() end,
          on_clicked=model.setup}),
        status("mobile-status",model,w),
        kit.subtitle {width=inner,wrap=true,font_size=P.SUB,text=model.note,color=kit.ink("lo")},
      },
      missing(w,"signal_cellular_nodata","No modem","No mobile modem is available. This page updates when one is detected.",model.available),
    },
  }
end

--- The id of the row that shows `row` of `model`'s list.
function M.row_id(model, row)
  for i, r in ipairs(model.list()) do
    if r == row or (r.path ~= nil and r.path == row.path) then
      return (model.wireless and "network" or "bluetooth") .. "-row-" .. i
    end
  end
end

function M.build(model, w, h)
  if model.key=="mobile" then return mobile_page(model,w,h) end
  return model.wireless and network_page(model, w, h) or bluetooth_page(model, w, h)
end
return M
