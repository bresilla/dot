-- History grouping, expansion and actions. Themes receive no server access.
local morf = require("morf")
local notifs = require("notifs")
local M = {}
local expanded = morf.signal("caelestia.sidebar.opened", {})
local visual, clearing
function M.groups()
  local history, groups, by_app = notifs.history:get(), {}, {}
  for i = #history, 1, -1 do
    local n = history[i]
    local app = n.app ~= "" and n.app or "Unknown"
    local group = by_app[app]
    if not group then
      group = { app = app, items = {}, urgency = 0 }
      by_app[app], groups[#groups + 1] = group, group
    end
    group.items[#group.items + 1] = n
    group.urgency = math.max(group.urgency, n.urgency or 1)
  end
  return groups
end
function M.count() return #notifs.history:get() end
function M.is_open(app) return expanded:get()[app] == true end
function M.toggle(app)
  local next = {}
  for key, on in pairs(expanded:get()) do next[key] = on end
  next[app] = not next[app] or nil
  expanded:set(next)
end
function M.forget(id) notifs.forget(id) end
function M.copy(entry)
  local plain = require("themes.notification_text").plain
  pcall(morf.clipboard.set, plain(entry.body ~= "" and entry.body or entry.summary))
end
function M.clear()
  if clearing then return end
  local ids = {}
  for _, n in ipairs(notifs.history:get()) do ids[#ids + 1] = n.id end
  if #ids == 0 then return end
  local delay = visual and visual.animate_clear() or 0
  local function finish()
    clearing = nil
    -- New arrivals during the exit belong to the next batch, not this click.
    for _, id in ipairs(ids) do notifs.forget(id) end
    if visual then visual.reset_clear() end
  end
  if delay > 0 then clearing = morf.timer(delay, finish, false) else finish() end
end
M.active = require("presentation").active("sidebar.notifications")
function M.build(width, height)
  visual = require("themes").view("notification_history").build(M, width, height)
  return visual.node
end
-- Remember expansion only while that application's history exists.
morf.effect("caelestia.history.expansion", function()
  local live, next, changed = {}, {}, false
  for _, n in ipairs(notifs.history:get()) do live[n.app ~= "" and n.app or "Unknown"] = true end
  for app, on in pairs(expanded:get()) do
    if live[app] then next[app] = on else changed = true end
  end
  if changed then expanded:set(next) end
end)
return M
