-- Lule's applied palette and an independent wallpaper selection. Merely
-- browsing never writes a scheme or calls the desktop hooks.
local morf = require("morf")
local lule = require("lib.integrations.lule")
local config = require("config")
local M = {}
local function expand(path)
  if path == "~" then return morf.fs.home() end
  if path:sub(1, 2) == "~/" then return morf.fs.home() .. path:sub(2) end
  return path
end
M.scheme = lule.watch("caelestia.lule.scheme")
local initial = M.scheme:get() or {}
M.selected = require("themes.session").keep("caelestia.lule.selected", initial.wallpaper or "")
M.mode = require("themes.session").keep("caelestia.lule.mode", initial.theme or "dark")
M.method = require("themes.session").keep("caelestia.lule.method", "pigment")
M.busy = morf.signal("caelestia.lule.busy", false)
M.active = morf.signal("caelestia.lule.active", false)
M.message = require("themes.session").keep("caelestia.lule.message", "Choose a wallpaper, then apply its colors.")
M.failed = require("themes.session").keep("caelestia.lule.failed", false)
M.folder = require("themes.session").keep("caelestia.lule.folder", "")
M.folder_draft = require("themes.session").keep("caelestia.lule.folder-draft", false)
M.files = require("themes.session").keep("caelestia.lule.files", {})
M.page = require("themes.session").keep("caelestia.lule.page", 1)
M.browsing = require("themes.session").keep("caelestia.lule.browsing", false)
M.preview = require("themes.session").keep("caelestia.lule.preview", "")
M.preview_error = require("themes.session").keep("caelestia.lule.preview_error", "")
local pictures = { png = true, jpg = true, jpeg = true, webp = true, bmp = true, gif = true, avif = true }
local function message(text, failed) M.failed:set(failed or false) M.message:set(text) end
function M.scan(path)
  path = expand(path or "")
  if not morf.fs.is_dir(path) then message("That wallpaper folder does not exist.", true) return false end
  local ok, entries = pcall(morf.fs.list, path, { follow = true })
  if not ok or type(entries) ~= "table" then message("Cannot read that wallpaper folder.", true) return false end
  local files = {}
  for _, entry in ipairs(entries) do
    if entry.is_file and pictures[(entry.extension or ""):lower()] then
      files[#files + 1] = { path = entry.path, name = entry.name }
    end
  end
  table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
  M.folder:set(path) M.files:set(files) M.page:set(1)
  if #files == 0 then message("No images in this folder. Choose another wallpaper folder.") end
  return true
end
function M.set_folder(path)
  if M.busy:get() then return false end
  path = expand(path or "")
  if path:sub(1, 1) ~= "/" then message("Enter a full folder path, or start with ~/.", true) return false end
  if not M.scan(path) then return false end
  M.folder_draft:set(false)
  config.set("lule.folder", path)
  M.browsing:set(true)
  if #M.files:get() > 0 then
    message("Folder saved · " .. #M.files:get() .. " wallpapers. Browse or use Random & apply.")
  end
  return true
end
function M.select(path)
  if M.busy:get() then return false end
  path = expand(path or "")
  if morf.fs.is_dir(path) then
    return M.set_folder(path)
  end
  if not morf.fs.is_file(path) then message("That image does not exist.", true) return false end
  M.selected:set(path) M.browsing:set(false)
  message("Preview only · Apply to change your desktop.")
  return true
end
function M.shuffle()
  if M.busy:get() then return false end
  if not M.scan(M.folder:get()) then return false end
  local files = M.files:get()
  if #files == 0 then message("Choose a folder containing wallpapers first.", true) return false end
  local i = math.random(#files)
  if #files > 1 and files[i].path == M.selected:get() then i = i % #files + 1 end
  return M.select(files[i].path)
end
function M.random_apply()
  -- A failed pick must never apply the previous selection instead.
  if not M.shuffle() then return false end
  return M.apply()
end
function M.step(delta)
  if M.busy:get() or not M.scan(M.folder:get()) then return false end
  local files = M.files:get()
  if #files == 0 then return false end
  local i = 1
  for n, file in ipairs(files) do if file.path == M.selected:get() then i = n break end end
  return M.select(files[(i - 1 + delta) % #files + 1].path)
end
function M.browse()
  if M.busy:get() then return false end
  if M.browsing:get() then M.browsing:set(false) return true end
  if not M.scan(M.folder:get()) then return false end
  M.browsing:set(true)
  return true
end
function M.apply()
  if M.busy:get() then return false end
  local dry=morf.env("CAELESTIA_DRY_RUN")
  if dry and dry~="" and dry~="0" then
    message("Applying wallpapers is disabled in this preview.",true)
    return false
  end
  local path = M.selected:get()
  if not morf.fs.is_file(path) then message("Choose an existing wallpaper first.", true) return false end
  M.busy:set(true) message("Generating colors and applying your Lule configuration…")
  local ok, child, why = pcall(lule.generate, {
    image = path, theme = M.mode:get(), palette = M.method:get(),
  }, function(result)
    M.busy:set(false)
    if result.ok then
      local scheme, err = lule.read()
      if scheme then
        M.scheme:set(scheme)
        local warning = (result.stderr or ""):gsub("\27%[[%d;]*m", ""):match("^%s*(.-)%s*$")
        message(warning ~= "" and ("Colors generated; Lule reported: " .. warning:sub(1, 220))
          or "Applied · Wallpaper, terminals and desktop colors updated.", warning ~= "")
      else message(err or "Lule finished, but its palette could not be read.", true) end
    else
      local detail = result.error or result.stderr or ""
      detail = detail:gsub("\27%[[%d;]*m", ""):match("^%s*(.-)%s*$")
      message(result.timed_out and "Lule took too long. Check its desktop hooks and try again."
        or (detail ~= "" and detail:sub(1, 260) or "Lule could not apply this wallpaper."), true)
    end
  end)
  if not ok or not child then
    M.busy:set(false) message(tostring(not ok and child or why or "Could not start Lule."), true)
    return false
  end
  return true
end
function M.copy(value)
  if not value or value == "" then return end
  local ok, copied = pcall(morf.clipboard.set, value)
  message(ok and copied ~= false and ("Copied " .. value) or "Could not copy this color.", not ok or copied == false)
end
local previous = initial.wallpaper or ""
morf.effect("caelestia.lule.follow", function()
  local scheme = M.scheme:get()
  if not scheme then return end
  local selected = M.selected:get()
  if selected == "" or selected == previous then M.selected:set(scheme.wallpaper or "") end
  previous = scheme.wallpaper or ""
end)
local scanned = false
local restoring = require("themes.session").restoring
morf.effect("caelestia.lule.open", function()
  if not M.active:get() then scanned = false return end
  local folder = config.get("lule.folder")
  if folder == "" then folder = morf.env("LULE_W") or "" end
  if folder == "" then folder = (M.selected:get():match("^(.*)/") or (morf.fs.home() .. "/Pictures/Wallpapers")) end
  folder = expand(folder)
  if scanned and M.folder:get() == folder then return end
  local page = M.page:get()
  scanned = M.scan(folder)
  if restoring then M.page:set(math.min(page,math.max(1,math.ceil(#M.files:get()/4)))) restoring=false end
end)
-- Resize on an image worker, only while this page is open. One scratch file
-- per output is overwritten; a data URI avoids stale filename image caches.
local output = ((morf.screens[1] or {}).name or "primary"):gsub("[^%w_-]", "_")
local scratch = morf.cache_path("lule-preview-" .. output .. ".jpg")
local working, wanted, timer = false, "", nil
local pump
pump = function()
  if working or wanted == "" or not M.active:get() then return end
  morf.fs.mkdir(morf.cache_dir(), { parents = true })
  local source = wanted
  wanted, working = "", true
  local function done(ok, result)
    working = false
    if M.active:get() and M.selected:get() == source then
      if ok then
        local bytes = morf.fs.read(scratch)
        if bytes then M.preview:set("data:image/jpeg;base64," .. morf.encoding.base64_encode(bytes)) end
      else M.preview_error:set("Cannot preview this image: " .. tostring(result)) end
    end
    if wanted ~= "" then pump() end
  end
  local ok, queued, why = pcall(morf.image.process, { source = source, output = scratch,
    quality = 85, ops = { { "resize", 960, 540, "fit" } }, on_done = done })
  if not ok or not queued then done(false, why or queued) end
end
local restored_preview = require("themes.session").restoring and M.preview:get() ~= ""
local restored_path = M.selected:get()
morf.effect("caelestia.lule.preview", function()
  local active, path = M.active:get(), M.selected:get()
  if restored_preview and path == restored_path then
    if active then restored_preview = false end
    return
  end
  restored_preview = false
  if timer then timer:cancel() timer = nil end
  wanted = "" M.preview:set("") M.preview_error:set("")
  if not active or path == "" then return end
  wanted = path
  timer = morf.timer(120, function() timer = nil pump() end, false)
end)
return M
