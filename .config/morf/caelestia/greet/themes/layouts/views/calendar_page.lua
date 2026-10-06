-- A month and the selected day's Taskwarrior agenda, in the page template
-- (themes/layouts/page.lua): the month in one card with its buttons, the
-- day's tasks in the next, the work calendar in the last. Work-calendar
-- events can be added here later; no account or meeting data is invented.
local morf = require("morf")
local ui = require("morf.ui")
local kit = require("kit")
local theme = require("theme")
local P = require("themes.layouts.page")
local widgets = require("planner_widgets")
local C = theme.color
local M = {}

function M.build(model, w, h)
  local inner = P.inner(w)
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

  -- Today at its label's width, planning the rest of the row.
  local today = P.button { id = "planner-today", label = "Today", icon = "today", on_clicked = model.today }
  local plan = P.button { id = "planner-add", label = "Plan a task", icon = "add", tone = "primary",
    width = function() return inner - (today.layout_width or 0) - 8 end, on_clicked = model.plan }

  local day = { id = "planner-day", caption_id = "planner-day-title", width = w, title = model.day_title,
    note = function() return tostring(agenda:len()) .. " planned" end,
    ui.Repeater { as = "column", gap = P.ROW_GAP, width = inner, model = agenda,
      delegate = function(item)
        return P.row { id = "planner-task-" .. item.uuid, width = inner, icon = "event",
          title = item.description,
          subtitle = (function()
            local parts = {}
            for _, part in ipairs { item.time or "", item.kind or "", item.project or "" } do
              if part ~= "" then parts[#parts + 1] = part end
            end
            return table.concat(parts, " · ")
          end)(),
          trailing = P.chevron(), on_clicked = function() model.edit(item.uuid) end }
      end },
    P.row { id = "planner-empty", width = inner, icon = "event_available", on = function() return false end,
      title = "Nothing planned yet", subtitle = "Tasks due or scheduled that day show here.",
      visible = function() return agenda:len() == 0 end },
  }

  local failure = widgets.message(function() return model.error:get() end, w, 64)
  failure.visible = function() return (model.error:get() or "") ~= "" end

  local page = P.page { id = "planner-scroll", width = w, height = h,
    P.section { id = "planner-month", width = w,
      month,
      ui.Row { gap = 8, align = "center", today, plan },
    },
    P.section(day),
    P.section { id = "planner-work", caption_id = "planner-work-title", width = w, title = "Work calendar",
      P.row { id = "planner-work-row", width = inner, icon = "calendar_month", on = function() return false end,
        title = "Not connected", subtitle = "Connect an account to see meetings." },
    },
    failure,
  }
  return ui.Item { id = "planner-calendar", width = w, height = h, page }
end
return M
