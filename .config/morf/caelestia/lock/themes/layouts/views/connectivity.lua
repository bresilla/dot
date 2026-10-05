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
local rows_kit = require("themes.layouts.rows")

local C = theme.color
local M = {}

local PAD = 16
local ROW = 44
local MAX_ROWS = 20

local function setting(id, label, y, w, on, toggled)
  return ui.Item {
    x = PAD, y = y, width = w - 2 * PAD, height = 36,
    kit.section_label { anchors = { vertical_center = true }, text = label, font_size = theme.size.normal },
    kit.switch { id = id, accessible_name = label, anchors = { right = true, vertical_center = true }, on = on,
      on_toggled = toggled },
  }
end

--- Up to as many rows as fit between `top` and `bottom` of the page, each
--- shown while `count()` reaches it.
local function rows(prefix, w, h, top, bottom, count, row)
  local list = {}
  local function fits() return math.max(0, math.floor((h() - top - bottom) / ROW)) end
  for i = 1, MAX_ROWS do
    list[i] = ui.Item {
      id = prefix .. i, width = w - 2 * PAD, height = ROW,
      visible = function() return i <= math.min(count(), fits()) end,
      row(i),
    }
  end
  return ui.Column { x = PAD, y = top, gap = 0, table.unpack(list) }
end

--- A row's look: the theme's hover surface, filled when it is the one in
--- use.
local function row_area(props, on)
  props.anchors = { fill = true, top_margin = 2, bottom_margin = 2 }
  props.on = on
  return rows_kit.choice(props)
end

-- ----------------------------------------------------------------- network --

local function network_page(model, w, h)
  local available = model.available
  return kit.card {
    id = "network-page",
    width = w, height = h, clip = true,
    kit.heading { id = "wifi-title", scope = "settings.network", x = PAD, y = PAD, text = "Wi-Fi", font_size = theme.size.large, font_weight = 500 },
    setting("network-wifi", "Enabled", PAD + 34, w, model.enabled, model.set_enabled),
    kit.subtitle {
      id = "network-count",
      x = PAD, y = PAD + 84,
      text = function()
        if not available() then return "No network manager" end
        local count = #model.list()
        return ("%d network%s available"):format(count, count == 1 and "" or "s")
      end,
      font_size = theme.size.normal,
      color = function() return C.onSurfaceVariant end,
    },
    rows("network-row-", w, h, PAD + 116, 76, function() return #model.list() end, function(i)
      local function ap() return model.list()[i] or {} end
      local function on() return ap().in_use == true end
      local area = row_area({
        on_clicked = function()
          model.choose(ap())
        end,
      }, on)
      ui.reparent(ui.Row {
        x = 12, anchors = { vertical_center = true }, gap = 12, align = "center",
        kit.icon(function() return model.signal_icon(ap().strength) end, 22, function()
          return on() and C.onSecondaryContainer or C.onSurfaceVariant
        end),
        kit.menu_label {
          width = w - 2 * PAD - 90, elide = "right",
          text = function() return ap().ssid or "" end,
          color = function() return on() and C.onSecondaryContainer or C.onSurface end,
        },
        kit.icon(function() return ap().secure and "lock" or "" end, 16, function() return C.onSurfaceVariant end),
      }, area)
      return area
    end),
    kit.pill {
      id = "network-rescan",
      x = PAD, width = w - 2 * PAD,
      y = function() return h() - PAD - 44 end,
      icon = "wifi_find", label = "Rescan networks",
      on_clicked = function()
        model.scan()
      end,
    },
  }
end

-- --------------------------------------------------------------- bluetooth --

local function bluetooth_page(model, w, h)
  local available = model.available
  return kit.card {
    id = "bluetooth-page",
    width = w, height = h, clip = true,
    kit.heading { id = "bluetooth-title", scope = "settings.bluetooth", x = PAD, y = PAD, text = "Bluetooth", font_size = theme.size.large, font_weight = 500 },
    setting("bluetooth-power", "Enabled", PAD + 34, w, model.enabled, model.set_enabled),
    setting("bluetooth-discover", "Discovering", PAD + 74, w, model.discovering, model.scan),
    kit.subtitle {
      id = "bluetooth-count",
      x = PAD, y = PAD + 124,
      text = function()
        if not available() then return "No Bluetooth adapter" end
        local count = #model.list()
        return ("%d device%s"):format(count, count == 1 and "" or "s")
      end,
      font_size = theme.size.normal,
      color = function() return C.onSurfaceVariant end,
    },
    rows("bluetooth-row-", w, h, PAD + 156, 76, function() return #model.list() end, function(i)
      local function dev() return model.list()[i] or {} end
      local function on() return dev().connected == true end
      local area = row_area({
        on_clicked = function()
          model.choose(dev())
        end,
      }, on)
      ui.reparent(ui.Row {
        x = 12, anchors = { vertical_center = true }, gap = 12, align = "center",
        kit.icon(function() return on() and "bluetooth_connected" or "bluetooth" end, 22,
          function() return on() and C.onSecondaryContainer or C.onSurfaceVariant end),
        kit.menu_label {
          width = w - 2 * PAD - 110, elide = "right",
          text = function() local d = dev() return d.alias or d.name or d.address or "" end,
          color = function() return on() and C.onSecondaryContainer or C.onSurface end,
        },
        kit.subtitle {
          text = function()
            local d = dev()
            if d.connected then return "Connected" end
            return d.paired and "Paired" or ""
          end,
          font_size = theme.size.small,
          color = function() return on() and C.onSecondaryContainer or C.onSurfaceVariant end,
        },
      }, area)
      return area
    end),
    kit.pill {
      id = "bluetooth-settings",
      x = PAD, width = w - 2 * PAD,
      y = function() return h() - PAD - 44 end,
      icon = "settings", label = "Open settings",
      on_clicked = function()
        model.open_settings()
      end,
    },
  }
end

function M.build(model, w, h)
  return model.wireless and network_page(model, w, h) or bluetooth_page(model, w, h)
end
return M
