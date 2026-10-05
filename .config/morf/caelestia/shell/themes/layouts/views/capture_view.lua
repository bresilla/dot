-- SDF controls: an elastic target selector and softly joined action buttons.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local M = {}
-- Material's radii, in the theme's measure (square themes: square).
local R = kit.round

function M.build(capture, w, h)
  local inner = w - 32
  local choices = {
    { "region", "Region", "crop_free" },
    { "window", "Window", "select_window" },
    { "screen", "Screen", "desktop_windows" },
  }
  local function index()
    for i, t in ipairs(choices) do if capture.target:get() == t[1] then return i end end
    return 1
  end
  local slot = inner / 3
  local function span(i) return (i - 1) * slot + 4, i * slot - 4 end
  local l, r = span(index())
  local selection = ui.Item { id = "capture-selection", x = l, y = 4, width = r - l, height = 64 }
  local chosen_mark = kit.decor("corners", { length = 7, color = kit.stroke("hot") })
  if chosen_mark then ui.reparent(chosen_mark, selection) end
  local selected = index()
  morf.effect("caelestia.capture.selection", function()
    local next = index()
    if next == selected then return end
    local x, right = span(next)
    -- Start from the currently drawn edges, so rapid selections stay fluid.
    kit.elastic(selection, "x", selection.x, selection.x + selection.width, x, right, { duration = 430 })
    selected = next
  end)

  local targets = {}
  local pressed = morf.signal("caelestia.capture.target_pressed", false)
  for i, t in ipairs(choices) do
    local area
    local function on() return capture.target:get() == t[1] end
    -- A segmented choice: one target, the arrows walk them (a kit Press
    -- in an exclusive group).
    area = kit.press_area("segment", { id = "capture-target-" .. t[1], x = (i - 1) * slot,
      width = slot, height = 72, cursor = "pointer",
      on_pressed = function() pressed:set(true) end,
      on_released = function() pressed:set(false) end,
      on_clicked = function() capture.target:set(t[1]) end,
      ui.Item { anchors = { fill = true },
        translate_y = function() return area and area.pressed and 2 or area and area.hovered and -2 or 0 end,
        behavior = { translate_y = kit.spring(400, 22) },
        kit.icon(t[3], 25, function() return on() and C.onSecondaryContainer or C.onSurfaceVariant end,
          { anchors = { horizontal_center = true }, y = 12, fill = on }),
        kit.label { anchors = { horizontal_center = true }, y = 43, text = t[2], font_size = 13, font_weight = 600,
          color = function() return on() and C.onSecondaryContainer or C.onSurfaceVariant end },
      },
    }, { checkable = true, group = "capture-target", checked = on })
    targets[#targets + 1] = area
  end
  local selector = ui.Item { x = 16, y = 14, width = inner, height = 72,
    ui.Sdf { anchors = { fill = true }, fill_color = function() return C.surfaceContainer end,
      ui.SdfShape { shape = "box", anchors = { fill = true }, radius = R(28) },
    },
    kit.decor("corners", { length = 8, color = kit.stroke("mark") }) or ui.Item {},
    selection,
    ui.Sdf { id = "capture-selection-field", anchors = { fill = true },
      fill_color = function() return C.secondaryContainer end,
      ui.SdfShape { shape = "box", track = selection,
        radius = function() return pressed:get() and R(14) or R(25) end,
        behavior = { radius = kit.spring(430, 22) },
      },
    },
    table.unpack(targets),
  }

  local function active() return capture.recording:get() end
  local function status()
    local phase = capture.phase:get()
    if phase == "stopping" then return "Finishing…" end
    if phase == "saving" then return "Saving…" end
    if active() then
      local n = capture.elapsed:get()
      return ("Recording %02d:%02d"):format(n // 60, n % 60)
    end
    return capture.message:get()
  end

  -- Each action is one distance field: a rounded body and a circular end
  -- merge at a soft neck. Hover fills the neck; pressing compresses it.
  -- The end is as round as the theme rounds it: where the theme's radius
  -- falls short of a circle the end takes the body's height, so a square
  -- theme gets one clean rectangle rather than a stepped notch.
  local function action(id, x, width, label, run, recording)
    local area
    local function hover() return area and area.hovered end
    local function held() return area and area.pressed end
    local function bg()
      if recording then return active() and C.errorContainer or C.surfaceContainerHigh end
      return C.primary
    end
    local function fg()
      if recording then return active() and C.onErrorContainer or C.onSurface end
      return C.onPrimary
    end
    local end_w = recording and 40 or 48
    local body = ui.Item {
      x = function() return held() and 3 or 0 end,
      y = function() return held() and 7 or 2 end,
      width = function() return width - end_w + (hover() and 24 or 10) - (held() and 6 or 0) end,
      height = function() return held() and 60 or 70 end,
      behavior = { x = kit.spring(), y = kit.spring(), width = kit.spring(360, 20), height = kit.spring() },
    }
    local square = R(end_w / 2) < end_w / 2 - 0.5 and 1 or 0
    local function body_y() return held() and 7 or 2 end
    local function body_h() return held() and 60 or 70 end
    local endcap = ui.Item {
      x = function() return width - end_w - (held() and 5 or 0) end,
      y = function() return (74 - end_w) / 2 + ((body_y()) - (74 - end_w) / 2) * square end,
      height = function() return end_w + (body_h() - end_w) * square end,
      width = end_w,
      behavior = { x = kit.spring(), y = kit.spring(), height = kit.spring() },
    }
    area = kit.action { id = id, x = x, y = 104, width = width, height = 74, cursor = "pointer",
      on_clicked = run,
      body, endcap,
      ui.Sdf { id = id .. "-field", anchors = { fill = true },
        fill_color = bg, blend = function() return math.max(0.5, hover() and R(22) or R(12)) end,
        blend_profile = "circular", behavior = { blend = kit.spring(330, 23), fill_color = { duration = 200 } },
        ui.SdfShape { shape = "box", track = body,
          radius = function() return held() and R(17) or R(25) end, behavior = { radius = kit.spring() } },
        ui.SdfShape { shape = "box", radius = R(end_w / 2), track = endcap,
          operation = square == 1 and "union" or "smooth_union" },
      },
      kit.decor("corners", { length = 7, color = function() return fg():alpha(0.7) end }) or ui.Item {},
      kit.text { x = recording and 18 or 60, anchors = { vertical_center = true },
        text = label, font_size = 16, font_weight = 650, color = fg,
        translate_x = function() return held() and 2 or 0 end, behavior = { translate_x = kit.spring() } },
    }
    if recording then
      -- A recording dot becomes a stop square by morphing the field itself.
      ui.reparent(ui.Sdf { x = width - end_w + (end_w - 16) / 2, y = 29, width = 16, height = 16,
        fill_color = function() return active() and C.error or C.tertiary end,
        ui.SdfShape { id = "capture-record-symbol", anchors = { fill = true }, shape = "circle", morph_to = "box",
          radius = 3, morph_progress = function() return active() and 1 or 0 end,
          behavior = { morph_progress = { duration = 350, easing = theme.ease.spatial } },
        },
      }, area)
    else
      -- A camera built from distance fields; the lens contracts on press.
      ui.reparent(ui.Sdf { x = 20, y = 22, width = 29, height = 29, fill_color = fg, blend = 2,
        ui.SdfShape { shape = "box", x = 0, y = 6, width = 29, height = 21, radius = R(5) },
        ui.SdfShape { shape = "box", x = 8, y = 2, width = 13, height = 7, radius = R(2), operation = "smooth_union" },
        ui.SdfShape { shape = "circle", x = 7, y = 9, width = 15, height = 15, operation = "subtract" },
        ui.SdfShape { shape = "circle", anchors = { horizontal_center = true },
          y = function() return held() and 14 or 12 end,
          width = function() return held() and 5 or 9 end, height = function() return held() and 5 or 9 end,
          behavior = { width = kit.spring(), height = kit.spring(), y = kit.spring() } },
      }, area)
      ui.reparent(kit.icon("arrow_forward", 21, fg, {
        x = width - end_w + (end_w - 21) / 2, anchors = { vertical_center = true },
        translate_x = function() return hover() and 3 or 0 end, behavior = { translate_x = kit.spring(300, 18) },
      }), area)
    end
    return area
  end
  local shot_w = math.floor((inner - 14) * 0.62)
  local shot = action("capture-screenshot", 16, shot_w, "Screenshot", function() capture.shoot() end)
  local record = action("capture-record", 16 + shot_w + 14, inner - shot_w - 14,
    function() return active() and "Stop" or "Record" end, function() capture.record() end, true)

  local delays = {}
  local times = { 0, 3, 5, 10 }
  local function delay_x()
    for i, n in ipairs(times) do if capture.delay:get() == n then return (i - 1) * 39 + 2 end end
    return 2
  end
  for i, n in ipairs(times) do
    delays[#delays + 1] = kit.action { id = "capture-delay-" .. n, x = (i - 1) * 39,
      width = 39, height = 30, cursor = "pointer", on_clicked = function() capture.delay:set(n) end,
      kit.label { anchors = { center_in = true }, text = n == 0 and "Now" or n .. "s", font_size = 12,
        color = function() return capture.delay:get() == n and C.onSecondaryContainer or C.onSurfaceVariant end },
    }
  end
  local controls = ui.Item { id = "capture-controls", y=32, width = w, height = function() return h()-32 end,
    ui.MouseArea { anchors = { fill = true } },
    selector, shot, record,
    kit.icon("timer", 17, kit.ink("lo"), { x = 20, y = 202 }),
    ui.Item { x = 44, y = 196, width = 156, height = 30,
      ui.Sdf { anchors = { fill = true }, fill_color = function() return C.secondaryContainer end,
        ui.SdfShape { shape = "box", x = delay_x, y = 2, width = 35, height = 26, radius = R(12),
          behavior = { x = kit.spring(340, 22) } },
      },
      table.unpack(delays),
    },
    kit.text { id = "capture-status", x = 212, y = 204, width = inner - 204, elide = "right",
      text = status, font_size = 12, visible = function() return capture.phase:get() ~= "countdown" end,
      color = function() return capture.phase:get() == "error" and C.error or C.onSurfaceVariant end },
    ui.Item { x = w - 164, y = 196, width = 148, height = 28,
      visible = function() return capture.phase:get() == "countdown" end,
      kit.pill { id = "capture-cancel", label = function() return "Cancel · " .. capture.countdown:get() .. "s" end,
        width = 148, height = 28, on_clicked = capture.cancel },
    },
  }
  return ui.Item {id="capture-page",width=w,height=h,controls,
    kit.heading {id="capture-title",text="Capture",scope="capture",level="section",x=16,y=8,width=w-32}}

end
return M
