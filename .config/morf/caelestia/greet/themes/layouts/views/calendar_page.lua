-- A month and the selected day's Taskwarrior agenda. Work-calendar events
-- can be added here later; no account or meeting data is invented.
local morf = require("morf")
local ui = require("morf.ui")
local kit = require("kit")
local theme = require("theme")
local widgets = require("planner_widgets")
local C = theme.color
local M = {}

function M.build(model, w, h)
  local viewport, viewport_node, viewport_t, viewport_ctl
  local function heading(props)
    props.viewport = function() return viewport end
    return kit.heading(props)
  end
  local inner = w - 32
  local days, agenda = model.days, model.agenda
  -- The month: the kit's calendar (a day grid the arrows walk, months that
  -- slide), on the model's month and day, a dot on each day with tasks.
  local counts = morf.signal("caelestia.planner.counts", {})
  local function shown_month()
    for i = 1, days:len() do local day = days:get(i) if day.current then return day.key:sub(1, 7) end end
    return nil
  end
  local month = require("lib.kit.composites").calendar { id = "planner", width = inner, cell_height = 43,
    value = function() return model.selected_day:get() end,
    on_changed = function(day) model.select(day) end,
    month = shown_month,
    on_month = function(_, delta) model.step(delta) end,
    marked = function(day) return (counts:get()[day] or 0) > 0 end }
  morf.effect("caelestia.planner.counts", function()
    local out = {}
    for i = 1, days:len() do local day = days:get(i) out[day.key] = day.count end
    counts:set(out)
  end, { owner = month })
  viewport_node, viewport, viewport_t, viewport_ctl = kit.scroll({ id = "planner-scroll", anchors = { fill = true, margins = 16 }, clip = true,
      ui.Column { width = inner, gap = 16,
        ui.Item { width = inner, height = 48,
          heading { id = "planner-title", scope = "leftbar.calendar", text = "A day at a time.", font_size = 24, font_weight = 700 },
          widgets.subtitle("Your plans, with space for what comes next.", { id = "planner-subtitle", y = 31 }),
        },
        month,
        ui.Row { gap = 8,
          widgets.button("planner-today", "Today", "today", 100, model.today),
          widgets.button("planner-add", "Plan a task", "add", inner - 108, model.plan, function() return true end),
        },
        kit.surface { width = inner, height = 1, color = kit.stroke("quiet") },
        ui.Column { gap = 5,
          heading { id = "planner-day-title", scope = "leftbar.calendar", level = "section", text = model.day_title, font_size = theme.size.large, font_weight = 600 },
          widgets.subtitle(function() return tostring(agenda:len()) .. " tasks planned" end),
        },
        ui.Repeater { as = "column", gap = 8, width = inner, model = agenda,
          delegate = function(item)
            return kit.action { id = "planner-task-" .. item.uuid, width = inner, height = 78, cursor = "pointer",
              on_clicked = function() model.edit(item.uuid) end,
              kit.card { anchors = { fill = true }, radius = 16, color = function() return C.surfaceContainerHigh end },
              kit.surface { x = 0, y = 16, width = 3, height = 46, radius = 1.5, color = kit.signal("accent") },
              widgets.label(item.time, { x = 14, y = 17, width = 54, elide = "right", color = kit.ink("accent") }),
              kit.menu_label { x = 72, y = 14, width = inner - 88, elide = "right", text = item.description, font_weight = 600 },
              widgets.subtitle(item.kind .. (item.project ~= "" and (" · " .. item.project) or ""),
                { x = 72, y = 43, width = inner - 88, elide = "right" }),
            }
          end,
        },
        ui.Column { width = inner, gap = 10, visible = function() return agenda:len() == 0 end,
          kit.icon("event_available", 42, kit.ink("accent")),
          heading { id = "planner-empty-title", scope = "leftbar.calendar", level = "section", visible = function() return agenda:len() == 0 end, text = "Nothing planned yet", font_size = theme.size.large },
          widgets.message("Tasks scheduled or due on this day will appear here.", inner),
        },
        kit.card { width = inner, height = 88, radius = 18, color = function() return C.surfaceContainerHigh end,
          kit.icon("calendar_month", 24, kit.ink("lo"), { x = 16, y = 18 }),
          heading { id = "planner-work-title", scope = "leftbar.calendar", level = "section", x = 54, y = 16, text = "Work calendar", font_weight = 600 },
          kit.subtitle { x = 54, y = 39, width = inner - 70, height = 48, wrap = true,
            text = "Not connected yet. Meetings will appear here once an account is connected.",
            font_size = theme.size.small, color = kit.ink("lo") },
        },
        widgets.message(function() return model.error:get() end, inner, 64),
      },
    })
  return kit.card { id = "planner-calendar", width = w, height = h, viewport_node }
end
return M
