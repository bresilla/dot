-- The wallpaper: which picture, and a background layer that paints it.
--
-- The picture is, first found: CAELESTIA_WALLPAPER, the one lule last made
-- its colours from (lib/lule: its colors.json, watched, so a new `lule
-- create` brings its picture along with its colours), the setting
-- `wallpaper.path`, or the path the caelestia tools keep in
-- ~/.local/state/caelestia/wallpaper/path.txt. Without one there is no
-- layer at all, and whatever already paints the desk shows through.

local morf = require("morf")
local ui = require("morf.ui")
local config = require("config")
local theme = require("theme")

local M = {}

local function expand(path)
  if path:sub(1, 2) == "~/" then return morf.fs.home() .. path:sub(2) end
  return path
end

local function state_file()
  local base = (morf.env and morf.env("XDG_STATE_HOME")) or (morf.fs.home() .. "/.local/state")
  return base .. "/caelestia/wallpaper/path.txt"
end

M.current = morf.signal("caelestia.wallpaper", "")

local lule = require("lib.integrations.lule")
local lule_scheme = lule.watch("caelestia.wallpaper.lule")

local function resolve()
  local path = (morf.env and morf.env("CAELESTIA_WALLPAPER")) or ""
  if path == "" then
    local scheme = lule_scheme:get()
    path = scheme and scheme.wallpaper or ""
  end
  if path == "" then path = config.get("wallpaper.path") end
  if path == "" then path = (morf.fs.read(state_file()) or ""):match("^%s*(.-)%s*$") end
  path = expand(path or "")
  if path ~= "" and not morf.fs.exists(path) then
    morf.log("warn", "caelestia: no wallpaper at " .. path)
    path = ""
  end
  return path
end

M.current:set(resolve())
-- lule changing its picture changes this one.
morf.effect("caelestia.wallpaper.follow", function()
  lule_scheme:get()
  local path=resolve()
  M.current:set(path)
  require("themes.wallpaper_handoff").publish(path,lule.path())
end)

--- Sets the picture (and the setting), and the scheme follows it.
function M.set(path)
  config.set("wallpaper.path", path)
  M.current:set(resolve())
end

--- A background layer with the picture on it, opened once there is a
--- picture: without one the desk's own wallpaper is left alone.
local layer
function M.open_layer()
  morf.effect("caelestia.wallpaper.layer", function()
    if layer or M.current:get() == "" then return end
    layer = M.layer()
  end)
end

function M.layer()
  return morf.window.layer {
    blend = "srgb",
    namespace = "caelestia-wallpaper",
    layer = "background",
    anchors = { top = true, bottom = true, left = true, right = true },
    -- Zero on both axes: the output's size (a layer is 32 px tall unless
    -- told otherwise).
    width = 0, height = 0,
    exclusive_zone = -1,
    keyboard_focus = "none",
    visible = true,
    -- Opaque: a solid fill under the picture, so the compositor draws
    -- nothing of its own under it -- one full-screen layer fewer to blend
    -- on every redraw of whatever sits over it.
    opaque = true,
    root = ui.Item {
      anchors = { fill = true },
      ui.Rect { anchors = { fill = true }, color = function() return theme.color.surface end },
      ui.Image {
        id = "wallpaper",
        anchors = { fill = true },
        fill_mode = "preserve_aspect_crop",
        source = function() return M.current:get() end,
        visible = function() return M.current:get() ~= "" end,
      },
    },
  }
end

return M
