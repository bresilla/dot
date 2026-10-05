-- Dashboard data and actions, independent of visual geometry.
local morf = require("morf")
local state = require("dashboard_state")
local services = require("services")
local sysinfo = require("lib.services.sysinfo")
local M = { tab = state.tab, opened = state.opened, displayed = state.displayed }
M.tabs = {
  { key = "overview", name = "Dashboard", icon = "dashboard" },
  { key = "media", name = "Media", icon = "queue_music" },
  { key = "performance", name = "Performance", icon = "speed" },
  { key = "battery", name = "Battery", icon = "battery_charging_full" },
  { key = "weather", name = "Weather", icon = "cloud" },
  { key = "lule", name = "Lule", icon_build = require("lule_icon").build },
}
M.month_offset = require("themes.session").keep("caelestia.dashboard.month", 0)
function M.month(offset, today)
  today = today or morf.time.date()
  local year, month = today.year, today.month + (offset or 0)
  while month > 12 do month = month - 12 year = year + 1 end
  while month < 1 do month = month + 12 year = year - 1 end
  local weeks = morf.time.month(year, month, 7)
  local days = {}
  for _, week in ipairs(weeks) do
    for column, d in ipairs(week) do
      days[#days + 1] = {
        day = d.day,
        current = d.current,
        today = d.year == today.year and d.month == today.month and d.day == today.day,
        weekend = column == 1 or column == 7,
      }
    end
  end
  -- Six rows always, as the reference's grid: the next month runs on.
  local last = weeks[#weeks][7]
  local n = last.current and 0 or last.day
  while #days < 42 do
    n = n + 1
    local column = #days % 7 + 1
    days[#days + 1] = { day = n, current = false, today = false, weekend = column == 1 or column == 7 }
  end
  local title = morf.time.format("%B %Y", morf.time.time { year = year, month = month, day = 1, hour = 12 })
  return { title = title, days = days }
end

function M.calendar()
  morf.minute_clock:get()
  return M.month(M.month_offset:get())
end
function M.shift_month(delta) M.month_offset:set(M.month_offset:get() + delta) end
function M.select(index)
  if M.tabs[index] then M.tab:set(index) end
end
function M.present(index) M.displayed:set(index) end
function M.overview_active() return M.opened:get() and M.displayed:get() == 1 end
local function visible(...)
  if not M.opened:get() then return false end
  local current = M.displayed:get()
  for _, index in ipairs {...} do if current == index then return true end end
  return false
end
-- Retain the last reading during visual departure without keeping sources awake.
local last={weather={available=false},system={uptime=0,hostname="",user=""},cpu=0,memory=0,storage=0,battery={},player={}}
function M.weather()
  if visible(1,5) then last.weather=services.weather() end
  return last.weather
end
M.weather_symbol = services.weather_symbol
function M.system()
  if M.opened:get() then last.system=sysinfo.system() or {} end
  return last.system
end
M.username = morf.env("USER") or morf.env("LOGNAME") or "user"
local face = morf.fs.home() .. "/.face"
M.face = morf.fs.exists(face) and face or ""
function M.desktop()
  if services.hyprland.available() then return "Hyprland" end
  local desktop = morf.env("XDG_CURRENT_DESKTOP")
  return desktop and desktop ~= "" and desktop or "Wayland"
end
function M.clock(format)
  morf.minute_clock:get()
  return morf.time.format(format)
end
local function percent(kind,field)
  if visible(1,3) then
    local ok, value = pcall(sysinfo[kind])
    last[kind]=ok and tonumber(value[field]) or 0
  end
  return last[kind]
end
function M.cpu() return percent("cpu","usage") end
function M.memory() return percent("memory","percent") end
function M.storage()
  if not visible(1,3) then return last.storage end
  local ok, list = pcall(sysinfo.disks)
  if not ok then return last.storage end
  last.storage=list[1] and list[1].percent or 0
  for _, disk in ipairs(list or {}) do if disk.mount == "/" then last.storage=disk.percent or 0 break end end
  return last.storage
end
function M.battery()
  if visible(1,4) then
    local batteries=(sysinfo.battery() or {}).batteries or {}
    last.battery=batteries[1] or {}
  end
  return last.battery
end
function M.player()
  if visible(1,2) then last.player=services.player() end
  return last.player
end
function M.artwork() return require("lib.util.remote").file(M.player().art_url) end
function M.media_control(action)
  if services.media and services.media[action] then pcall(services.media[action]) end
end
local pages = {}
function M.page(index)
  if pages[index] then return pages[index] end
  if index == 6 then
    pages[index] = require("lule_page")
  else pages[index] = require("dashboard_" .. M.tabs[index].key) end
  return pages[index]
end
function M.desk_size()
  local _,_,w,h = require("bar").desk()
  return w,h
end
return M
