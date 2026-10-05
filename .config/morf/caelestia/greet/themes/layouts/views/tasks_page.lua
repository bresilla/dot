-- Taskwarrior tasks, with a full editor inside the left drawer.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local widgets = require("planner_widgets")
local R = require("themes.layouts.rows")
local C = theme.color
local M = {}
function M.build(model, w, h)
  local PAD, inner = 16, w - 32
  local editing, deleting, query, filter, rows = model.editing, model.deleting, model.query, model.filter, model.rows
  local inputs = {}
  local search = widgets.field("tasks-search", "Find a task", "Search tasks, projects or tags", inner,
    function(text) query:set(text) end, nil, model.close)
  local filters = { gap = 6 }
  for _, name in ipairs { "Open", "Today", "Active" } do
    filters[#filters + 1] = widgets.button("tasks-filter-" .. name:lower(), name, nil, (inner - 12) / 3,
      function() model.set_filter(name) end, function() return filter:get() == name end)
  end
  local task_list = ui.Repeater {
    as = "column", gap = 8, width = inner, model = rows,
    delegate = function(row)
      local done = kit.action { id = "task-done-" .. row.uuid, x = 8, y = 12, width = 38, height = 38, cursor = "pointer",
          on_clicked = function() model.complete(row.uuid) end,
          kit.icon("radio_button_unchecked", 23, function() return row.overdue and C.error or C.primary end,
            { anchors = { center_in = true } }) }
      kit.hover(done, function(hovered) return hovered and C.onSurface:alpha(0.08) or C.onSurface:alpha(0) end, R.round(38))
      return kit.card { id = "task-row-" .. row.uuid, width = inner, height = 100,
        color = function() return C.surfaceContainerHigh end,
        done,
        kit.action { id = "task-edit-" .. row.uuid, x = 52, y = 12, width = inner - 64, height = 78, cursor = "pointer",
          on_clicked = function() model.edit(row.uuid) end,
          kit.menu_label { text = row.description, width = inner - 64, height = 25, elide = "right", font_weight = 600 },
          widgets.subtitle(row.detail, { y = 30, width = inner - 64, elide = "right" }),
          widgets.subtitle(row.date, { y = 54, width = inner - 64, elide = "right",
            color = function() return row.overdue and C.error or C.onSurfaceVariant end }),
        },
      }
    end,
  }
  local browse = ui.Item { width = w, height = h, visible = function() return not editing:get() end,
    ui.Column { x = PAD, y = PAD, width = inner, gap = 12,
      ui.Item { width = inner, height = 52,
        kit.heading { id = "tasks-title", scope = "leftbar.tasks", visible = function() return not editing:get() end, text = "Make room for today.", font_size = 23, font_weight = 700 },
        widgets.subtitle(function() return tostring(model.count:get()) .. " open tasks · Taskwarrior" end, { id = "tasks-subtitle", y = 31 }),
      },
      ui.Row { gap = 8,
        widgets.button("tasks-add", "New task", "add", inner - 104, function() model.edit() end, function() return true end),
        widgets.button("tasks-refresh", "Refresh", "refresh", 96, model.refresh),
      },
      search, ui.Row(filters),
      (kit.scroll({ id = "tasks-list", width = inner, height = function() return math.max(100, h() - 310) end, clip = true,
        task_list,
        ui.Column { width = inner, gap = 8, visible = function() return rows:len() == 0 end,
          kit.icon("task_alt", 40, function() return C.primary end),
          kit.heading { id = "tasks-empty-title", scope = "leftbar.tasks", level = "section",
            visible = function() return not editing:get() and rows:len() == 0 end,
            text = function() return model.loaded:get() and "A little breathing room." or "Your tasks, right here." end,
            font_size = theme.size.large },
          widgets.message(function() return model.busy:get() and "Loading tasks…" or "Add a task, or choose another view." end, inner),
        },
      })),
    },
  }

  local fields = { gap = 12, width = inner }
  local specs = model.FIELDS
  -- A date is typed (a Taskwarrior expression or a date and time) or chosen
  -- from the kit's date picker beside it, which keeps the time typed.
  local DATES = { scheduled = true, due = true, wait = true, ["until"] = true }
  local pickers = require("lib.kit.composites")
  for _, spec in ipairs(specs) do
    local name = spec[1]
    local dated = DATES[name]
    local node, input = widgets.field("task-" .. name, spec[2], spec[3], dated and inner - 46 or inner,
      function(value) model.set_field(name, value) end, nil, model.close)
    if dated then
      local picker = pickers.date_picker { id = "task-" .. name .. "-date", compact = true, width = 40, height = 40,
        placement = "bottom-end", accessible_name = "Choose the " .. spec[2]:lower(),
        value = function() return (input.text or ""):sub(1, 10) end,
        on_changed = function(date)
          local time = (input.text or ""):match("^%d%d%d%d%-%d%d%-%d%d(T[%d:]+)") or ""
          input.text = date .. time
          model.set_field(name, input.text)
        end }
      node = ui.Row { gap = 6, align = "end", node, picker }
    end
    fields[#fields + 1], inputs[name] = node, input
  end
  fields[#fields + 1] = widgets.message(model.help, inner, 60)
  local actions = ui.Row { gap = 6, visible = function() return editing:get() and model.selected:get() ~= "" end,
    widgets.button("task-complete", "Done", "check", 88, model.finish),
    widgets.button("task-start", function() return model.running() and "Stop" or "Start" end, "timer", 88, model.start_stop),
    widgets.button("task-delete", function() return deleting:get() and "Confirm delete" or "Delete" end, "delete", inner - 188, model.delete),
  }
  fields[#fields + 1] = actions
  local editor = ui.Item { width = w, height = h, visible = function() return editing:get() end,
    ui.Item { x = PAD, y = PAD, width = inner, height = 40,
      kit.heading { id = "task-editor-title", scope = "leftbar.tasks", visible = function() return editing:get() end, text = function() return model.selected:get() ~= "" and "Edit task" or "New task" end, font_size = 24, font_weight = 700 },
      ui.Item { anchors = { right = true }, width = 76, height = 36,
        widgets.button("task-cancel", "Back", "arrow_back", 76, model.cancel) },
    },
    (kit.scroll({ id = "task-editor-scroll", x = PAD, y = 70, width = inner,
      height = function() return math.max(100, h() - 182) end, clip = true, ui.Column(fields) })),
    ui.Item { x = PAD, y = function() return h() - 100 end, width = inner, height = 40,
      widgets.button("task-save", function() return model.busy:get() and "Saving…" or "Save task" end,
        "check", inner, model.save, function() return true end) },
  }
  local root = kit.card { id = "tasks-page", width = w, height = h, browse, editor,
    kit.subtitle { id = "tasks-error", x = PAD, y = function() return h() - 50 end,
      width = inner, height = 44, wrap = true, text = function() return model.error:get() end,
      font_size = theme.size.small, color = function() return C.error end },
  }
  local previous
  morf.effect("material.tasks.editor", function()
    local revision = model.editor_revision:get()
    if revision ~= previous then
      previous = revision
      for name, input in pairs(inputs) do input.text = model.draft[name] end
    end
  end, { owner = root })
  morf.effect("material.tasks.focus", function()
    model.editor_revision:get()
    inputs.description.focus = model.active() and editing:get()
  end, { owner = root })
  return root
end
return M
