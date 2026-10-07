-- Enumerate installed families only when the picker opens; no background scan.
local morf = require("morf")
local M = {
  opened = morf.signal("appearance.fonts.opened", false),
  query = morf.signal("appearance.fonts.query", ""),
  page = morf.signal("appearance.fonts.page", 1),
  rows = morf.signal("appearance.fonts.rows", {}),
  status = morf.signal("appearance.fonts.status", ""),
}
local families, loading = nil, false
function M.filter(query)
  M.query:set(query)
  M.page:set(1)
  local rows, needle = {}, query:lower()
  for _, family in ipairs(families or {}) do
    if family:lower():find(needle, 1, true) then rows[#rows + 1] = family end
  end
  M.rows:set(rows)
end
function M.open()
  M.opened:set(true)
  if families or loading then return end
  loading = true
  M.status:set("Loading installed fonts…")
  morf.run({"fc-list", "--format", "%{family[0]}\n"}, {timeout_ms=5000,max_output=262144}, function(result)
    loading = false
    if not result.ok then M.status:set("Could not read installed fonts. Open again to retry.") return end
    families = {}
    local seen = {}
    for family in (result.stdout or ""):gmatch("[^\r\n]+") do
      family = family:match("^%s*(.-)%s*$")
      if family ~= "" and #family <= 200 and not seen[family:lower()] then
        seen[family:lower()] = true
        families[#families + 1] = family
      end
    end
    table.sort(families, function(a,b) return a:lower()<b:lower() end)
    M.status:set("")
    M.filter(M.query:get())
  end)
end
function M.close() M.opened:set(false) end
function M.step(delta, size)
  M.page:set(math.max(1, math.min(math.max(1, math.ceil(#M.rows:get()/size)), M.page:get()+delta)))
end
function M.choose(family)
  if family ~= "" then
    local found = false
    for _, installed in ipairs(families or {}) do if family == installed then found = true break end end
    if not found then return false end
  end
  local appearance = require("themes.switcher")
  if family == (require("themes").font or "") then M.close() return true end
  if appearance.request_font(family) then M.close() return true end
  return false
end
return M
