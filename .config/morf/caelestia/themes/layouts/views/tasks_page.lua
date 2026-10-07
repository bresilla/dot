-- Taskwarrior tasks, with a full editor inside the left drawer, in the page
-- template (themes/layouts/page.lua).
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local widgets = require("planner_widgets")
local R = require("themes.layouts.rows")
local P = require("themes.layouts.page")
local C = theme.color
local M = {}
local function get(v) if type(v) == "function" then return v() end return v end

function M.build(model, w, h)
  local inner = P.inner(w)
  local editing, deleting, query, filter, rows = model.editing, model.deleting, model.query, model.filter, model.rows
  local inputs = {}

  -- -------------------------------------------------------------- browse --
  local search = widgets.field("tasks-search", "Find a task", "Search tasks, projects or tags", inner,
    function(text) query:set(text) end, nil, model.close)
  local filters = { width = inner }
  for _, name in ipairs { "Open", "Today", "Active" } do
    filters[#filters + 1] = { id = "tasks-filter-" .. name:lower(), label = name,
      on_clicked = function() model.set_filter(name) end, selected = function() return filter:get() == name end }
  end
  -- Refresh at its label's width, a new task the rest of the row.
  local refresh = P.button { id = "tasks-refresh", label = "Refresh", icon = "refresh", on_clicked = model.refresh }
  local add = P.button { id = "tasks-add", label = "New task", icon = "add", tone = "primary",
    width = function() return w - (refresh.layout_width or 0) - 8 end, on_clicked = function() model.edit() end }

  -- A task: the circle that finishes it, and the rest of the row opens it.
  local task_list = ui.Repeater {
    as = "column", gap = P.ROW_GAP, width = inner, model = rows,
    delegate = function(row)
      local done = kit.action { id = "task-done-" .. row.uuid, x = 4, width = 40, height = 40, cursor = "pointer",
        anchors = { vertical_center = true }, accessible_name = "Done",
        on_clicked = function() model.complete(row.uuid) end,
        kit.icon("radio_button_unchecked", 22, function() return row.overdue and C.error or C.primary end,
          { anchors = { center_in = true } }) }
      kit.hover(done, function(hovered) return hovered and C.onSurface:alpha(0.08) or C.onSurface:alpha(0) end, R.round(40))
      local function line(text, color)
        return kit.text { text = text, width = inner - 64, elide = "right", font_size = require("themes.layouts.parts").SIZE.body, color = color or kit.ink("lo") }
      end
      return ui.Item { id = "task-row-" .. row.uuid, width = inner, height = P.ROW_H + 12,
        kit.action { id = "task-edit-" .. row.uuid, x = 50, width = inner - 50, height = P.ROW_H + 12, cursor = "pointer",
          on_clicked = function() model.edit(row.uuid) end,
          ui.Column { anchors = { vertical_center = true }, gap = 2,
            kit.text { text = row.description, width = inner - 64, elide = "right",
              font_size = theme.size.normal, font_weight = 500, color = kit.ink("hi") },
            line(row.detail),
            line(row.date, function() return row.overdue and C.error or C.onSurfaceVariant end),
          } },
        done,
      }
    end,
  }
  local empty = P.empty { id = "tasks-empty", width = w, icon = "task_alt",
    title = function() return model.loaded:get() and "A little breathing room." or "Your tasks, right here." end,
    text = function() return model.busy:get() and "Loading tasks…" or "Add a task, or choose another view." end }
  empty.visible = function() return rows:len() == 0 end
  local list = P.section { id = "tasks-open", width = w,
    title = function() return filter:get() .. " tasks" end,
    note = function() return tostring(model.count:get()) .. " · Taskwarrior" end,
    visible = function() return rows:len() > 0 end,
    task_list }
  local browse = P.page { id = "tasks-list", width = w, height = h,
    ui.Row { gap = 8, align = "center", add, refresh },
    P.section { id = "tasks-find", width = w, search, P.buttons(filters) },
    list, empty,
  }
  browse.visible = function() return not editing:get() end

  -- -------------------------------------------------------------- editor --
  local fields = { id = "tasks-editor", caption_id = "task-editor-title", width = w,
    title = function() return model.selected:get() ~= "" and "Edit task" or "New task" end }
  -- A date is typed (a Taskwarrior expression or a date and time) or chosen
  -- from the kit's date picker beside it, which keeps the time typed.
  local DATES = { scheduled = true, due = true, wait = true, ["until"] = true }
  local pickers = require("lib.kit.composites")
  for _, spec in ipairs(model.FIELDS) do
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
  local actions = P.buttons { width = w,
    { id = "task-complete", label = "Done", icon = "check", on_clicked = model.finish },
    { id = "task-start", label = function() return model.running() and "Stop" or "Start" end, icon = "timer",
      on_clicked = model.start_stop },
    { id = "task-delete", label = function() return deleting:get() and "Confirm" or "Delete" end, icon = "delete",
      on_clicked = model.delete },
  }
  actions.visible = function() return editing:get() and model.selected:get() ~= "" end
  -- Back and Save at the top, where they are whatever the editor's length.
  local save = P.button { id = "task-save", label = function() return model.busy:get() and "Saving…" or "Save task" end,
    icon = "check", tone = "primary", on_clicked = model.save }
  local bar = ui.Item { width = w, height = P.BUTTON_H,
    P.button { id = "task-cancel", label = "Back", icon = "arrow_back", on_clicked = model.cancel },
    ui.Item { anchors = { right = true }, width = function() return save.width end, height = P.BUTTON_H, save } }
  local editor = ui.Item { width = w, height = h,
    bar,
    ui.Item { y = P.BUTTON_H + P.GAP, width = w, height = function() return get(h) - P.BUTTON_H - P.GAP end,
      P.page { id = "task-editor-scroll", width = w, height = function() return get(h) - P.BUTTON_H - P.GAP end,
        P.section(fields),
        actions,
      } },
  }
  editor.visible = function() return editing:get() end

  local failure = kit.subtitle { id = "tasks-error", y = function() return get(h) - 48 end,
    width = w, height = 44, wrap = true, text = function() return model.error:get() end,
    font_size = theme.size.small, color = function() return C.error end }
  failure.visible = function() return (model.error:get() or "") ~= "" end
  local root = ui.Item { id = "tasks-page", width = w, height = h, browse, editor, failure }
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
