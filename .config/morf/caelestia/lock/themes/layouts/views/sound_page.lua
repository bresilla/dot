-- The right panel's two sound pages: Sound (the output) and Microphone
-- (the input), each opened from its own tile.
--
--   Output   the default output's volume, mute, and each of its channels
--            on its own slider (left and right, or channel 1, 2, ...)
--            under a Channels expander that remembers being shut
--   Devices  every output, the default one chosen; a click makes another
--            the default
--   Apps     what is playing: each app's volume and mute, and chips for
--            the outputs to send it to
--   Input    the default input's volume and mute, and every input to
--            choose from
--
-- Readings and actions come from the shared audio model.

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local rows = require("themes.layouts.rows")
local disclosure = require("lib.kit.disclosure")

local C = theme.color
local M = {}

function M.build(model, w, h)
local GAP, PAD = 12, 16
local COL_W, INNER = w, w - 2 * PAD
local MAX_CHANNELS = 8
local available = model.available
local sink, source = model.default, model.default

--- A card's title, with an icon button at its right when `button` is given.
local function title(text, button)
  local row = ui.Item {
    x = PAD, y = PAD, width = INNER, height = 30,
    kit.heading { id = "sound-title-" .. text:lower():gsub("%s+", "-"), scope = text == "Input" and "settings.microphone" or "settings.sound", level = "section",
      anchors = { vertical_center = true },
      text = text, font_size = theme.size.larger, font_weight = 600,
    },
  }
  if button then ui.reparent(button, row) end
  return row
end

--- An icon button for mute: the theme's alert tone when on.
local function mute_button(id, target, icon_on, icon_off, name)
  local function muted() local t = target() return t and t.muted end
  return rows.toggle { id = id, accessible_name = name, width = 36, height = 30,
    anchors = { right = true, vertical_center = true },
    on = function() return muted() == true end, icon_on = icon_on, icon_off = icon_off,
    on_clicked = function()
      local t = target()
      if t then model.toggle_device(t) end
    end,
  }
end

local function nothing(text)
  return kit.subtitle {
    anchors = { center_in = true },
    text = text, font_size = theme.size.normal,
    color = function() return C.onSurfaceVariant end,
    visible = function() return not available() end,
  }
end

--- A row to choose a device by: its name, a check when it is the default.
local function device_row(id_prefix, row)
  local function live() return model.device(row) end
  local function chosen() local d = live() return d ~= nil and d.default == true end
  return rows.choice {
    id = id_prefix .. "-" .. math.floor(row.id), group = id_prefix,
    width = INNER, height = 40, on = chosen,
    on_clicked = function() model.select_device(row) end,
    kit.icon(function() return chosen() and "radio_button_checked" or "radio_button_unchecked" end, 20,
      rows.ink(chosen, false, C.onSurfaceVariant),
      { x = 12, anchors = { vertical_center = true } }),
    kit.menu_label {
      x = 44, width = INNER - 56, elide = "right",
      anchors = { vertical_center = true },
      text = function() local d = live() return d and (d.description or d.name) or "?" end,
      font_size = theme.size.normal,
      color = rows.ink(chosen),
    },
  }
end

-- ------------------------------------------------------------------ output --

local channels_open = require("themes.session").keep("caelestia.sound.channels_open", true)
local function output_card(height)
  local function vol() local s = sink() return s and s.volume or 0 end
  local channels = {}
  for i = 1, MAX_CHANNELS do
    local function count() local s = sink() return s and s.channels or 0 end
    local function name()
      if count() == 2 then return i == 1 and "L" or "R" end
      return tostring(i)
    end
    channels[i] = ui.Row {
      gap = 8, align = "center",
      visible = function() return count() > 1 and i <= count() end,
      kit.text {
        width = 18, text = name, horizontal_alignment = "center",
        font_size = theme.size.small, font_weight = 600,
        color = function() return C.onSurfaceVariant end,
      },
      kit.slider {
        id = "sound-channel-" .. i, width = INNER - 26, height = 26,
        accessible_name = function() return "Channel " .. name() end,
        value = function()
          local s = sink()
          return s and s.volumes and s.volumes[i] or 0
        end,
        set = function(v)
          model.set_channel(i, v)
        end,
      },
    }
  end
  return kit.card {
    id = "sound-output",
    width = COL_W, height = height,
    title("Output", mute_button("sound-output-mute", sink, "volume_off", "volume_up", "Mute output")),
    ui.Column {
      x = PAD, y = PAD + 38, gap = 4,
      visible = available,
      kit.subtitle {
        width = INNER, elide = "right",
        text = function() local s = sink() return s and s.description or "" end,
        font_size = theme.size.small,
        color = function() return C.onSurfaceVariant end,
      },
      kit.slider {
        id = "sound-output-volume", width = INNER, accessible_name = "Output volume",
        value = vol,
        set = function(v) local s = sink() if s then model.set_device_volume(s, v) end end,
        icon = function()
          local s = sink()
          if not s or s.muted or s.volume <= 0 then return "volume_mute" end
          return s.volume < 0.5 and "volume_down" or "volume_up"
        end,
      },
      (disclosure.make("expander", {
        id = "sound-channels", title = "Channels", width = INNER, header_height = 34,
        visible = function() local s = sink() return s ~= nil and (s.channels or 0) > 1 end,
        expanded = function() return channels_open:get() end,
        on_toggled = function(open) if open ~= channels_open:get() then channels_open:set(open) end end,
        content = ui.Column { gap = 0, table.unpack(channels) },
      })),
    },
    nothing("No sound server"),
  }
end

local function devices_card(height)
  return kit.card {
    id = "sound-devices",
    width = COL_W, height = height,
    clip = true,
    title("Output device"),
    ui.Column {
      x = PAD, y = PAD + 38, gap = 4, width = INNER, height = function() return height() - PAD - 38 - PAD end,
      visible = available,
      ui.Repeater {
        as = "column", gap = 4,
        model = model.devices,
        delegate = function(row) return device_row("sound-sink", row) end,
      },
    },
    nothing("No outputs"),
  }
end

-- -------------------------------------------------------------------- apps --

--- One app playing: its name and what it plays, its volume and mute, and a
--- chip for each output to send it to.
local function app_row(row)
  if row.direction ~= "playback" then return ui.Item { width = 0, height = 0, visible = false } end
  local id = row.id
  local function live() return model.stream(row) end
  local chips = ui.Repeater {
      as = "row", gap = 6,
      model = model.devices,
      delegate = function(device)
        local function on() local s = live() return s ~= nil and s.device == device.id end
        return rows.choice {
          id = "sound-app-" .. math.floor(id) .. "-to-" .. math.floor(device.id),
          group = "sound-app-" .. math.floor(id),
          width = 104, height = 26, on = on, tone = "primary", tile = true,
          on_clicked = function() model.route(row, device) end,
          kit.menu_label {
            x = 10, width = 84, elide = "right", anchors = { vertical_center = true },
            text = function() local d = model.device(device) return d and (d.description or d.name) or "?" end,
            font_size = theme.size.small,
            color = rows.ink(on, true, C.onSurfaceVariant),
          },
        }
      end,
  }
  local function muted() local s = live() return s and s.muted end
  local mute = rows.toggle {
    id = "sound-app-" .. math.floor(id) .. "-mute",
    accessible_name = function() local s = live() return "Mute " .. (s and (s.app_name or s.binary) or "app") end,
    width = 30, height = 30, anchors = { right = true },
    on = function() return muted() == true end, icon_on = "volume_off", icon_off = "volume_up",
    on_clicked = function() local s = live() if s then model.toggle_stream(row) end end,
  }
  return ui.Column {
    gap = 4,
    ui.Item {
      width = INNER, height = 30,
      ui.Column {
        gap = 0, anchors = { vertical_center = true },
        kit.menu_label {
          width = INNER - 40, elide = "right",
          text = function() local s = live() return s and (s.app_name or s.binary) or "App" end, font_size = theme.size.normal, font_weight = 600,
        },
        kit.subtitle {
          width = INNER - 40, elide = "right",
          text = function() local s = live() return s and s.media_name or "" end,
          font_size = theme.size.small,
          color = function() return C.onSurfaceVariant end,
        },
      },
      mute,
    },
    kit.slider {
      id = "sound-app-" .. math.floor(id) .. "-volume", width = INNER, height = 30,
      accessible_name = function() local s = live() return (s and (s.app_name or s.binary) or "App") .. " volume" end,
      value = function() local s = live() return s and s.volume or 0 end,
      set = function(v) model.set_stream_volume(row, v) end,
    },
    ui.Item { width = INNER, height = 30, clip = true, chips },
    ui.Item { width = INNER, height = 6 },
  }
end

local function apps_card(height)
  local function playing()
    if not available() then return 0 end
    local n, streams = 0, model.streams
    for i = 1, streams:len() do
      if streams:get(i).direction == "playback" then n = n + 1 end
    end
    return n
  end
  return kit.card {
    id = "sound-apps",
    width = COL_W, height = height,
    clip = true,
    title("Apps"),
    ui.Column {
      x = PAD, y = PAD + 38, gap = 6, width = INNER, height = function() return height() - PAD - 38 - PAD end,
      visible = available,
      ui.Repeater {
        as = "column", gap = 6,
        model = model.streams,
        delegate = app_row,
      },
    },
    kit.subtitle {
      anchors = { center_in = true },
      text = function() return available() and "Nothing playing" or "No sound server" end,
      font_size = theme.size.normal,
      color = function() return C.onSurfaceVariant end,
      visible = function() return playing() == 0 end,
    },
  }
end

-- ------------------------------------------------------------------- input --

local function input_card(height)
  return kit.card {
    id = "sound-input",
    width = COL_W, height = height,
    clip = true,
    title("Input", mute_button("sound-input-mute", source, "mic_off", "mic", "Mute input")),
    ui.Column {
      x = PAD, y = PAD + 38, gap = 4,
      visible = available,
      kit.slider {
        id = "sound-input-volume", width = INNER, height = 36, accessible_name = "Input volume",
        value = function() local s = source() return s and s.volume or 0 end,
        set = function(v) local s = source() if s then model.set_device_volume(s, v) end end,
        icon = function() local s = source() return (s and s.muted) and "mic_off" or "mic" end,
      },
      ui.Repeater {
        as = "column", gap = 4,
        model = model.devices,
        delegate = function(row)
          -- A monitor is an output's echo, not a microphone.
          if tostring(row.name or ""):match("%.monitor$") then
            return ui.Item { width = 0, height = 0, visible = false }
          end
          return device_row("sound-source", row)
        end,
      },
    },
    nothing("No inputs"),
  }
end

--- The page, `w` wide and `h()` tall: the output with its channels, the
--- outputs, the input and its inputs at their own sizes, and the apps in
--- what is left.
--- The output page, `w` wide and `h()` tall: the output with its
--- channels, the outputs to choose from, and the apps in what is left.
local function output_page()
  local OUT_H, DEV_H = 250, 150
  local apps_h = function() return math.max(160, h() - OUT_H - DEV_H - 60 - 3 * GAP) end
  return ui.Item {
    id = "sound-page",
    width = w, height = h, clip = true,
    (kit.scroll({id="sound-scroll",width=w,height=h,clip=true,ui.Column {
      gap = GAP,
      output_card(OUT_H),
      kit.pill {id="sound-equalizer",width=w,height=60,label="Equalizer  ›",
        on_clicked=model.open_equalizer},
      devices_card(function() return DEV_H end),
      apps_card(apps_h),
    }})),
  }
end

--- The input page: the microphone's level and mute, and every input.
local function input_page()
  return ui.Item {
    id = "microphone-page",
    width = w, height = h, clip = true,
    input_card(h),
  }
end

return model.kind == "output" and output_page() or input_page()
end

return M
