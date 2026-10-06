-- The pages a panel can hold, by key. Which panel holds which is a setting
-- (`panels.<edge>`: a list of keys), so a page can move from panel to panel
-- -- a settings app moves it -- while each page is built the one way.
--
-- A page: `name`, `icon`, and `build(panel, w, h)` -- `panel` is the side
-- panel model it is built in (its `opened` and `showing`, for a page that
-- works only while it is on show).
local config = require("config")
local M = {}

-- A page of the bottom workspace's kind (assistant, drop) takes a context:
-- its title, and whether it is on show.
local function workspace(key, title)
  return function(panel, w, h)
    local ctx = { key = key, title = title, status = "Not connected",
      active = function() return panel.opened:get() and panel.showing(key) end }
    return require(key).build(ctx, w, h)
  end
end

M.all = {
  settings = { name = "Settings", icon = "tune", title_id = "settings-title", build = function(_, w, h) return require("utilities").page(w, h) end },
  notifications = { name = "Notifications", icon = "notifications", title_id = "sidebar-title",
    build = function(_, w, h) return require("notification_history").build(w, h) end },
  tasks = { name = "Tasks", icon = "checklist", title_id = "tasks-title", build = function(_, w, h) return require("tasks_page").build(w, h) end },
  calendar = { name = "Calendar", icon = "calendar_month", title_id = "planner-title",
    build = function(_, w, h) return require("calendar_page").build(w, h) end },
  assistant = { name = "Assistant", icon = "auto_awesome", title_id = "assistant-title", build = workspace("assistant", "Assistant") },
  drop = { name = "Drop", icon = "forum", title_id = "drop-title", build = workspace("drop", "Drop") },
}

--- The pages the panel on `edge` holds, as side panel tabs (`key`, `name`,
--- `icon`, `build(w, h)` once `bind(model)` has given them their panel).
function M.tabs(edge)
  local keys = config.get("panels." .. edge) or {}
  local tabs, panel = {}, nil
  for _, key in ipairs(keys) do
    local page = M.all[key]
    if page then
      -- Every page in the one frame: its name over its body
      -- (themes/layouts/page.lua), whatever draws the body.
      tabs[#tabs + 1] = { key = key, name = page.name, icon = page.icon,
        build = function(w, h)
          return require("themes.layouts.page").frame { id = "page-" .. key, width = w, height = h,
            title = page.name, title_id = page.title_id, titled = require("responsive").compact(),
            -- Its title reads in (where the theme reads titles in) as its
            -- panel shows it.
            active = function() return panel ~= nil and require("presentation").active(panel.id .. "." .. key)() end,
            build = function(bw, bh) return page.build(panel, bw, bh) end }
        end }
    end
  end
  return tabs, function(model) panel = model end
end

return M
