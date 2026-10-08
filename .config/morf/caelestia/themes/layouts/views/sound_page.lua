-- The right panel's two sound pages, Sound (the output) and Microphone
-- (the input), in the page template (themes/layouts/page.lua):
--
--   Output         the default output, its mute, volume, and each of its
--                  channels under a Channels expander that remembers
--                  being shut; then the equalizer, one page in
--   Output device  every output, the default one chosen; a click makes
--                  another the default
--   Apps           what is playing: each app's volume and mute, and a
--                  button for each output to send it to
--   Input          the default input's volume and mute, and every input
--
-- Readings and actions come from the shared audio model.

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local rows = require("themes.layouts.rows")
local P = require("themes.layouts.page")
local disclosure = require("lib.kit.disclosure")

local M = {}

function M.build(model, w, h)
local INNER = P.inner(w)
local MAX_CHANNELS = 16
local available = model.available
local sink, source = model.default, model.default

--- A mute toggle at a row's right: the theme's alert tone when on.
local function mute_button(id, target, icon_on, icon_off, name)
  local function muted() local t = target() return t and t.muted end
  return rows.toggle { id = id, accessible_name = name, width = 40, height = 36,
    on = function() return muted() == true end, icon_on = icon_on, icon_off = icon_off,
    on_clicked = function()
      local t = target()
      if t then model.toggle_device(t) end
    end,
  }
end

--- A line inside a card saying what is missing, centred in it.
local function nothing(icon, text, visible)
  return ui.Column { width = INNER, gap = 6, align = "center", visible = visible,
    ui.Item { width = 1, height = 6 },
    kit.icon(icon, 30, kit.ink("lo")),
    kit.text { text = text, width = INNER, horizontal_alignment = "center", elide = "right",
      font_size = theme.size.normal, color = kit.ink("lo") },
    ui.Item { width = 1, height = 6 },
  }
end

local function name_of(d) return d and (d.description or d.name) or "?" end

--- A row to choose a device by: its name, a mark when it is the default.
local function device_row(id_prefix, row, icon)
  local function live() return model.device(row) end
  local function chosen() local d = live() return d ~= nil and d.default == true end
  return rows.choice {
    id = id_prefix .. "-" .. math.floor(row.id), group = id_prefix,
    width = INNER, height = P.ROW_H, on = chosen,
    on_clicked = function() model.select_device(row) end,
    P.row { width = INNER, on = chosen, icon = icon,
      title = function() return name_of(live()) end,
      subtitle = function() return chosen() and "In use" or "Not in use" end,
      trailing = kit.icon(function() return chosen() and "radio_button_checked" or "radio_button_unchecked" end, 22,
        rows.ink(chosen, false, theme.color.onSurfaceVariant)) },
  }
end

local function volume_icon()
  local s = sink()
  if not s or s.muted or s.volume <= 0 then return "volume_mute" end
  return s.volume < 0.5 and "volume_down" or "volume_up"
end

-- ------------------------------------------------------------------ output --

local channels_open = require("themes.session").keep("caelestia.sound.channels_open", true)
local function output_section()
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
      kit.text { width = 18, text = name, horizontal_alignment = "center",
        font_size = theme.size.small, font_weight = 600, color = kit.ink("lo") },
      kit.slider {
        id = "sound-channel-" .. i, width = INNER - 26, height = 26,
        accessible_name = function() return "Channel " .. name() end,
        value = function() local s = sink() return s and s.volumes and s.volumes[i] or 0 end,
        set = function(v) model.set_channel(i, v) end,
      },
    }
  end
  return P.section { id = "sound-output", caption_id = "sound-title-output", width = w, title = "Output",
    P.row { id = "sound-output-device", width = INNER, icon = volume_icon,
      on = function() local s = sink() return s ~= nil and not s.muted end,
      title = function()
        if not available() then return "No sound server" end
        local s = sink() return s and name_of(s) or "No output selected"
      end,
      subtitle = function() local s = sink() return s and ("%d%%"):format(math.floor(s.volume * 100 + 0.5)) or "" end,
      trailing = mute_button("sound-output-mute", sink, "volume_off", "volume_up", "Mute output") },
    ui.Column { width = INNER, gap = 4, visible = available,
      kit.slider {
        id = "sound-output-volume", width = INNER, accessible_name = "Output volume",
        value = function() local s = sink() return s and s.volume or 0 end,
        set = function(v) local s = sink() if s then model.set_device_volume(s, v) end end,
        icon = volume_icon,
      },
      (disclosure.make("expander", {
        id = "sound-channels", title = "Channels", width = INNER, header_height = 34,
        visible = function() local s = sink() return s ~= nil and (s.channels or 0) > 1 end,
        expanded = function() return channels_open:get() end,
        on_toggled = function(open) if open ~= channels_open:get() then channels_open:set(open) end end,
        content = ui.Column { gap = P.ROW_GAP, table.unpack(channels) },
      })),
    },
    P.row { id = "sound-equalizer", width = INNER, icon = "equalizer", title = "Equalizer",
      subtitle = "Tone, presets and audiogram compensation", trailing = P.chevron(),
      on_clicked = model.open_equalizer },
  }
end

local function devices_section()
  return P.section { id = "sound-devices", caption_id = "sound-title-output-device", width = w, title = "Output device",
    ui.Repeater { as = "column", gap = P.ROW_GAP, width = INNER, model = model.devices,
      visible = available,
      delegate = function(row) return device_row("sound-sink", row, "speaker") end },
    nothing("speaker", function() return available() and "No outputs available" or "No sound server" end,
      function() return not available() or model.devices:len() == 0 end),
  }
end

-- -------------------------------------------------------------------- apps --

--- One app playing: its name and what it plays with its mute, its volume,
--- and a button for each output to send it to.
local function app_row(row)
  if row.direction ~= "playback" then return ui.Item { width = 0, height = 0, visible = false } end
  local id = row.id
  local function live() return model.stream(row) end
  local function app_name() local s = live() return s and (s.app_name or s.binary) or "App" end
  -- Where it plays: one choice per output, one under the other, so any
  -- number of them fits the card's width.
  local routes = ui.Repeater {
    as = "column", gap = 2, width = INNER,
    model = model.devices,
    delegate = function(device)
      local function on() local s = live() return s ~= nil and s.device == device.id end
      return rows.choice {
        id = "sound-app-" .. math.floor(id) .. "-to-" .. math.floor(device.id),
        group = "sound-app-" .. math.floor(id), width = INNER, height = 36, on = on,
        on_clicked = function() model.route(row, device) end,
        kit.icon(function() return on() and "radio_button_checked" or "radio_button_unchecked" end, 18,
          rows.ink(on, false, theme.color.onSurfaceVariant), { x = 14, anchors = { vertical_center = true } }),
        kit.text { x = 44, width = INNER - 56, elide = "right", anchors = { vertical_center = true },
          text = function() return name_of(model.device(device)) end, font_size = theme.size.small,
          color = rows.ink(on, false, theme.color.onSurface) },
      }
    end,
  }
  local function muted() local s = live() return s and s.muted end
  local mute = rows.toggle {
    id = "sound-app-" .. math.floor(id) .. "-mute",
    accessible_name = function() return "Mute " .. app_name() end,
    width = 40, height = 36,
    on = function() return muted() == true end, icon_on = "volume_off", icon_off = "volume_up",
    on_clicked = function() if live() then model.toggle_stream(row) end end,
  }
  return ui.Column { width = INNER, gap = 4,
    P.row { width = INNER, icon = "music_note", title = app_name,
      on = function() return muted() ~= true end,
      subtitle = function() local s = live() return s and s.media_name or "" end,
      trailing = mute },
    kit.slider {
      id = "sound-app-" .. math.floor(id) .. "-volume", width = INNER, height = 30,
      accessible_name = function() return app_name() .. " volume" end,
      value = function() local s = live() return s and s.volume or 0 end,
      set = function(v) model.set_stream_volume(row, v) end,
    },
    kit.text { x = 0, width = INNER, text = "Play on", font_size = theme.size.small, color = kit.ink("lo") },
    routes,
    ui.Item { width = INNER, height = 6 },
  }
end

local function apps_section()
  local function playing()
    if not available() then return 0 end
    local n, streams = 0, model.streams
    for i = 1, streams:len() do
      if streams:get(i).direction == "playback" then n = n + 1 end
    end
    return n
  end
  return P.section { id = "sound-apps", caption_id = "sound-title-apps", width = w, title = "Apps",
    ui.Repeater { as = "column", gap = P.ROW_GAP, width = INNER, model = model.streams,
      visible = function() return playing() > 0 end, delegate = app_row },
    nothing("music_off", function() return available() and "Nothing playing" or "No sound server" end,
      function() return playing() == 0 end),
  }
end

-- ------------------------------------------------------------------- input --

local function input_section()
  return P.section { id = "sound-input", caption_id = "sound-title-input", width = w, title = "Input",
    P.row { id = "sound-input-device", width = INNER,
      icon = function() local s = source() return (s and s.muted) and "mic_off" or "mic" end,
      on = function() local s = source() return s ~= nil and not s.muted end,
      title = function()
        if not available() then return "No sound server" end
        local s = source() return s and name_of(s) or "No input selected"
      end,
      subtitle = function() local s = source() return s and ("%d%%"):format(math.floor(s.volume * 100 + 0.5)) or "" end,
      trailing = mute_button("sound-input-mute", source, "mic_off", "mic", "Mute input") },
    kit.slider {
      id = "sound-input-volume", width = INNER, height = 36, accessible_name = "Input volume", visible = available,
      value = function() local s = source() return s and s.volume or 0 end,
      set = function(v) local s = source() if s then model.set_device_volume(s, v) end end,
      icon = function() local s = source() return (s and s.muted) and "mic_off" or "mic" end,
    },
  }
end

local function inputs_section()
  return P.section { id = "sound-sources", width = w, title = "Input device",
    ui.Repeater { as = "column", gap = P.ROW_GAP, width = INNER, model = model.devices, visible = available,
      delegate = function(row)
        -- A monitor is an output's echo, not a microphone.
        if tostring(row.name or ""):match("%.monitor$") then
          return ui.Item { width = 0, height = 0, visible = false }
        end
        return device_row("sound-source", row, "mic")
      end },
    nothing("mic_off", function() return available() and "No inputs available" or "No sound server" end,
      function() return not available() or model.devices:len() == 0 end),
  }
end

if model.kind == "output" then
  return ui.Item { id = "sound-page", width = w, height = h, clip = true,
    P.page { id = "sound-scroll", width = w, height = h, output_section(), devices_section(), apps_section() } }
end
return ui.Item { id = "microphone-page", width = w, height = h, clip = true,
  P.page { id = "microphone-scroll", width = w, height = h, input_section(), inputs_section() } }
end

return M
