-- Presentation helpers shared by notification views.
local morf = require("morf")
local M = {}
function M.plain(value)
  return (tostring(value or ""):gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end
function M.ago(time)
  morf.minute_clock:get()
  local seconds = math.max(0, morf.time.now() - (time or 0))
  if seconds < 60 then return "now" end
  if seconds < 3600 then return ("%dm"):format(seconds // 60) end
  if seconds < 86400 then return ("%dh"):format(seconds // 3600) end
  return ("%dd"):format(seconds // 86400)
end

-- What a notification reads as, for the status cards: critical is an
-- alert, trouble a warning, success ok, anything else info.
local function has(text, words)
  for _, w in ipairs(words) do
    if text:find("%f[%a]" .. w) then return true end
  end
  return false
end
function M.kind(x)
  if not x then return "info" end
  if (x.urgency or 1) >= 2 then return "alert" end
  local text = (tostring(x.summary or "") .. " " .. tostring(x.body or "")):lower()
  if has(text, { "fail", "error", "warn", "low", "denied", "lost", "disconnect", "unable", "cannot", "crash" }) then
    return "warn"
  end
  if (x.urgency or 1) == 0 or has(text, { "complete", "done", "success", "finish", "saved", "connected",
    "ready", "installed", "updated", "copied", "sent", "passed" }) then
    return "ok"
  end
  return "info"
end
--- A notification's progress (0..1) when its sender gave one (`value`).
function M.progress(x)
  local hints = x and x.hints
  local v = type(hints) == "table" and tonumber(hints.value) or nil
  if not v then return nil end
  return math.max(0, math.min(1, v / 100))
end
-- The plain words for each kind: a theme may say them its own way through
-- L.term ("notice.<kind>", "notice.verdict.<kind>").
M.WORDS = { alert = "Urgent", warn = "Warning", ok = "Done", info = "Info" }
M.VERDICT = {
  alert = "Needs your attention",
  warn = "Worth a look",
  ok = "Nothing to do",
  info = "For your information",
}
--- The kind's word and verdict in the theme's voice.
function M.word(kind)
  local L = require("themes.layouts.parts")
  return L.term("notice." .. kind, M.WORDS[kind])
end
function M.verdict(kind)
  local L = require("themes.layouts.parts")
  return L.term("notice.verdict." .. kind, M.VERDICT[kind])
end
return M
