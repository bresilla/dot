-- Notification service, history and actions; theme builders own popups.
local morf = require("morf")
local drawer = require("drawer")

local M = {}

M.list = morf.signal("caelestia.notifications", {})
-- Every notification that came in, oldest first, until it is dismissed from
-- the sidebar or cleared there: the popups go when they expire, the
-- history stays. Each entry is a copy with `time` (seconds, when it came).
M.history = require("themes.session").keep("caelestia.notifications.history", {})
-- Do not disturb: notifications still reach the history, but no popup.
M.dnd = require("themes.session").keep("caelestia.notifications.dnd", false)
-- True while the sidebar is open (sidebar.lua sets it).
M.covered = morf.signal("caelestia.notifications.covered", false)

local seen = {}
local function remember(n)
  local list = M.history:get()
  local out, replaced = {}, false
  for i, e in ipairs(list) do
    if e.id == n.id then
      out[i] = n
      replaced = true
    else
      out[i] = e
    end
  end
  if not replaced then out[#out + 1] = n end
  M.history:set(out)
end
local function record_of(n)
  return {
    id = n.id, app = n.app or "", summary = n.summary or "", body = n.body or "",
    urgency = n.urgency or 1, icon = n.icon or "", time = morf.time.now(),
  }
end
-- Which popups are opened out to their whole body.
local open_ids = morf.signal("caelestia.notifications.open", {})

local server
do
  local ok, lib = pcall(require, "lib.services.notifications")
  if ok then
    local ok2, s = pcall(lib.serve, {
      on_change = function(list)
        local copy = {}
        for i, n in ipairs(list) do
          copy[i] = n
          if not seen[n.id] and not n.transient then
            seen[n.id] = true
            remember(record_of(n))
          end
        end
        M.list:set(copy)
      end,
    })
    if ok2 and s then server = s
    else morf.log("info", "caelestia: not the notification server: " .. tostring(s)) end
  end
end

-- Notifications the shell raises itself (and the tests): `{ app, summary,
-- body, urgency }`; they expire as the server's do.
local own = 100000
function M.push(entry)
  own = own + 1
  local n = {
    id = own, app = entry.app or "caelestia", summary = entry.summary or "", body = entry.body or "",
    urgency = entry.urgency or 1, icon = entry.icon or "", own = true,
  }
  local list = {}
  for _, e in ipairs(M.list:get()) do list[#list + 1] = e end
  list[#list + 1] = n
  M.list:set(list)
  remember(record_of(n))
  if n.urgency < 2 then morf.timer(entry.timeout_ms or 5000, function() M.dismiss(n.id) end, false) end
  return n.id
end

function M.dismiss(id)
  if server and server.open(id) then server.dismiss(id) return end
  local list = {}
  for _, e in ipairs(M.list:get()) do
    if e.id ~= id then list[#list + 1] = e end
  end
  M.list:set(list)
end

--- Takes notification `id` out of the history (and its popup with it).
function M.forget(id)
  local out = {}
  for _, e in ipairs(M.history:get()) do
    if e.id ~= id then out[#out + 1] = e end
  end
  M.history:set(out)
  for _, e in ipairs(M.list:get()) do
    if e.id == id then M.dismiss(id) break end
  end
end

--- Empties the history (and shuts every popup).
function M.clear()
  local ids = {}
  for _, e in ipairs(M.list:get()) do ids[#ids + 1] = e.id end
  for _, id in ipairs(ids) do M.dismiss(id) end
  M.history:set({})
end

function M.shown(limit)
  local list = M.list:get()
  local out = {}
  -- The newest on top.
  for i = #list, math.max(1, #list - (limit or #list) + 1), -1 do out[#out + 1] = list[i] end
  return out
end

function M.expanded(id) return open_ids:get()[tostring(id)] == true end


M.opened=morf.signal("caelestia.notifications.presented",false)
function M.toggle(id)
  id=tostring(id)
  local ids={}
  for k,v in pairs(open_ids:get()) do ids[k]=v end
  ids[id]=not ids[id] or nil
  open_ids:set(ids)
end
-- Expanded state belongs only to live popups, never to expired history.
morf.effect("caelestia.notifications.expansion",function()
  local live,ids,changed={},{},false
  for _,n in ipairs(M.list:get()) do live[tostring(n.id)]=true end
  for id,on in pairs(open_ids:get()) do
    if live[id] then ids[id]=on else changed=true end
  end
  if changed then open_ids:set(ids) end
end)
local visual
function M.dismiss_at(index)
  local entry=M.shown()[index]
  if not entry then return end
  local id=entry.id
  local delay=visual.dismiss(index) or 0
  -- Capture identity before the exit animation. A new arrival can replace
  -- this slot while it is moving; it must not be dismissed in its place.
  if delay>0 then morf.timer(delay,function() M.dismiss(id) end,false)
  else M.dismiss(id) end
end
visual=require("themes").view("notifications").build(M)
M.drawer=drawer.new {name="notifications",edge=visual.edge,width=visual.width,height=visual.height,
  -- Toasts: they stay until their time is up, a click or a swipe.
  close_policy="none",
  content=visual.content,props=visual.props}
morf.effect("caelestia.notifications.shown",function()
  M.drawer.set(#M.list:get()>0 and not M.covered:get() and not M.dnd:get() and require("services").here())
end)
morf.effect("caelestia.notifications.presented",function() M.opened:set(M.drawer.open:get()) end)
return M
