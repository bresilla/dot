-- Material's original bar layout, supplied with shared readings and actions.
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local V = { horizontal = 40, vertical = 48 }
local function button(id, size, on_clicked, child, hint)
  local area
  area = kit.action {
    id = id, width = size, height = size, cursor = "pointer",
    on_clicked = on_clicked,
    child,
  }
  return kit.hover(area, function(hovered)
    return hovered and C.onSurface:alpha(0.08) or C.onSurface:alpha(0)
  end, size / 2)
end

function V.build(model)
  local ITEM = 34

  -- The logo: the author's mark, in the theme's colour. A click opens the
  -- launcher.
  local mark = require("logo")
  local function logo(suffix)
    return button("bar-logo" .. suffix, ITEM, model.toggle_launcher, ui.Item {
      anchors = { center_in = true }, width = 24, height = 24,
      ui.Path {
        x = 24 * mark.offset_x / 100, y = 0, width = 24 * mark.scale_x, height = 24,
        view_box = mark.view_box, d = mark.d,
        fill_color = kit.ink("accent"),
      },
    })
  end

  -- --------------------------------------------------------- windows --
  -- A button per window of the workspace on show, after Dash to Panel: the
  -- app's icon (and its title, when `bar.titles` is on and the bar lies
  -- along), a pill behind the focused one, a light behind the one under
  -- the pointer, and a mark on the bar's inner edge -- wide for the focused
  -- window, a dot for the rest. A click focuses it.
  local titles = model.titles
  local function icon_of(client)
    local hit = client.icon
    if hit and hit.name then
      return ui.Icon { width = 22, height = 22, name = hit.name, source_width = 44, source_height = 44 }
    end
    if hit and hit.path then
      return ui.Image { width = 22, height = 22, source = hit.path, fill_mode = "preserve_aspect_fit" }
    end
    return kit.icon("select_window", 22, function() return C.onSurfaceVariant end)
  end
  local TITLE_W = 140
  local function window_delegate(client)
    local function here() return true end
    local function focused() return client.focused end
    local function wide() return titles() and ITEM + 8 + TITLE_W or ITEM + 6 end
    local area
    area = kit.action {
      id = "bar-window-" .. tostring(client.address),
      cursor = "pointer",
      width = function() return here() and wide() or 0 end,
      height = function() return here() and ITEM or 0 end,
      visible = here,
      on_clicked = function() model.focus(client.address) end,
      ui.Row {
        x = 7, anchors = { vertical_center = true }, gap = 8, align = "center",
        icon_of(client),
        kit.text {
          visible = titles, width = TITLE_W - 4, elide = "right",
          font_size = theme.size.small, font_weight = 500,
          text = function() return client.title ~= "" and client.title or client.class end,
          color = function() return focused() and C.onSurface or C.onSurfaceVariant end,
        },
      },
      -- The mark on the bar's inner edge.
      kit.surface {
        height = 3, radius = 2,
        width = function() return focused() and 18 or 5 end,
        x = function() return (wide() - (focused() and 18 or 5)) / 2 end,
        y = function() return model.side() == "bottom" and 0 or ITEM - 3 end,
        color = function() return focused() and C.primary or C.onSurfaceVariant:alpha(0.7) end,
        behavior = { width = { duration = theme.duration.small }, x = { duration = theme.duration.small } },
      },
    }
    return kit.hover(area, function(hovered)
      if focused() then return C.primary:alpha(0.16) end
      return hovered and C.onSurface:alpha(0.07) or C.onSurface:alpha(0)
    end, 10)
  end
  local function windows(as)
    return ui.Repeater { as = as, gap = 6, model = model.rows, delegate = window_delegate }
  end

  -- ----------------------------------------------------------- status --
  -- The status icons say, and do nothing on their own: any of them opens
  -- the quick settings, at their top.
  local function status(id, icon_fn)
    return ui.Item {
      id = id, width = ITEM - 6, height = ITEM - 6,
      kit.icon(icon_fn, 20, function() return C.onSurface end, { anchors = { center_in = true }, fill = true }),
    }
  end
  local function tail(vertical)
    local v = vertical and "-v" or ""
    local nodes = { gap = 2, align = "center" }
    -- Tor, while it runs.
    local onion = status("bar-tor" .. v, function() return "travel_explore" end)
    onion.visible = function() return model.reading:get().tor end
    nodes[#nodes + 1] = onion
    -- The ring mode, while it is not sound.
    local ring = status("bar-ringer" .. v, function()
      return model.reading:get().ring_icon
    end)
    ring.visible = function() return model.reading:get().ring end
    nodes[#nodes + 1] = ring
    -- A phone's mobile network, with its generation; crossed out without one.
    nodes[#nodes + 1] = status("bar-mobile" .. v, function() return model.reading:get().mobile_icon end)
    if model.has_modem then
      if not vertical then
        nodes[#nodes + 1] = kit.text {
          font_size = theme.size.small - 2, font_weight = 700,
          text = function() return model.reading:get().technology end,
        }
      end
    end
    for _, n in ipairs {
      status("bar-network" .. v, function() return model.reading:get().network_icon end),
      status("bar-battery" .. v, function() return model.reading:get().battery_icon end),
    } do nodes[#nodes + 1] = n end
    if not vertical then
      nodes[#nodes + 1] = kit.text {
        font_size = theme.size.small, font_weight = 600,
        visible = function() return model.reading:get().battery end,
        text = function() return model.reading:get().percentage end,
      }
    end
    -- One segment, one click: all of it opens the quick settings.
    local row = (vertical and ui.Column or ui.Row)(nodes)
    local area
    area = kit.action {
      id = "bar-status" .. v, cursor = "pointer",
      width = function() return vertical and ITEM or (row.layout_width or 160) + 16 end,
      height = function() return vertical and (row.layout_height or 160) + 16 or ITEM end,
      on_clicked = model.open_settings,
      ui.Item { anchors = { center_in = true },
        width = function() return row.layout_width or 0 end,
        height = function() return row.layout_height or 0 end,
        row },
    }
    kit.hover(area, function(hovered)
      if model.settings_open() then return C.primary:alpha(0.16) end
      return hovered and C.onSurface:alpha(0.07) or C.onSurface:alpha(0)
    end, 10)
    return area, row
  end

  -- ------------------------------------------------------------ time --
  -- The date and the time, in the middle; a click opens the dashboard, and
  -- another shuts it.
  local stamp = model.stamp
  local function clock(vertical)
    local area
    area = kit.action {
      id = "bar-clock" .. (vertical and "-v" or ""), cursor = "pointer",
      width = vertical and ITEM + 4 or 190, height = vertical and 64 or ITEM,
      on_clicked = model.toggle_dashboard,
      vertical and ui.Column {
        anchors = { center_in = true }, gap = 0, align = "center",
        kit.text { text = function() return (stamp:get()[1]:sub(1, 2)) end, font_weight = 700 },
        kit.text { text = function() return (stamp:get()[1]:sub(4, 5)) end, font_weight = 700 },
        kit.text { text = function() return stamp:get()[3] end,
          font_size = theme.size.small - 3, color = kit.ink("lo") },
      } or ui.Row {
        anchors = { center_in = true }, gap = 10, align = "center",
        kit.text { text = function() return stamp:get()[2] end, font_size = theme.size.small,
          color = kit.ink("lo") },
        kit.text { text = function() return stamp:get()[1] end, font_weight = 700 },
      },
    }
    return kit.hover(area, function(hovered)
      if model.dashboard_open() then return C.primary:alpha(0.16) end
      return hovered and C.onSurface:alpha(0.07) or C.onSurface:alpha(0)
    end, 10)
  end

  -- ---------------------------------------------------------- layout --
  local function strip()
    local w, h = model.screen()
    local i = model.insets()
    local side = model.side()
    if side == "top" then return 0, 0, w, i.top + theme.BORDER end
    if side == "bottom" then return 0, h - i.bottom - theme.BORDER, w, i.bottom + theme.BORDER end
    if side == "left" then return 0, 0, i.left + theme.LEFT, h end
    return w - i.right - theme.BORDER, 0, i.right + theme.BORDER, h
  end
  -- Well in from the frame's corners.
  local PAD = 34
  local head_h = ui.Row { gap = 10, align = "center", logo(""), windows("row") }
  local tail_h, row_h = tail(false)
  local head_v = ui.Column { gap = 8, align = "center", logo("-v"), windows("column") }
  local tail_v, row_v = tail(true)
  return ui.Item {
    id = "bar",
    visible = function() return model.on() end,
    x = function() local x = strip() return x end,
    y = function() local _, y = strip() return y end,
    width = function() local _, _, w = strip() return w end,
    height = function() local _, _, _, h = strip() return h end,
    ui.Item {
      visible = function() return not model.vertical() end,
      anchors = { fill = true },
      ui.Item { x = PAD, width = 1, anchors = { vertical_center = true }, height = ITEM, head_h },
      ui.Item { anchors = { center_in = true }, width = 190, height = ITEM, clock(false) },
      ui.Item {
        anchors = { right = true, right_margin = PAD, vertical_center = true }, height = ITEM,
        width = function() return (row_h.layout_width or 160) + 16 end,
        tail_h,
      },
    },
    ui.Item {
      visible = function() return model.vertical() end,
      anchors = { fill = true },
      ui.Item { y = PAD, height = 1, anchors = { horizontal_center = true }, width = ITEM, head_v },
      ui.Item { anchors = { center_in = true }, width = ITEM + 4, height = 64, clock(true) },
      ui.Item {
        anchors = { bottom = true, bottom_margin = PAD, horizontal_center = true }, width = ITEM,
        height = function() return (row_v.layout_height or 160) + 16 end,
        tail_v,
      },
    },
  }
end

return V
