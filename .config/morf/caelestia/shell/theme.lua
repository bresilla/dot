-- Compatibility facade: palette roles and visual design are independent.
local morf = require("morf")
local config = require("config")
local appearance = require("themes")
local M = require("palette")
M.appearance = appearance.current
for key, value in pairs(M.appearance.tokens) do M[key] = value end
M.font_file = morf.env("CAELESTIA_FONT_FILE") or config.get("appearance.font_file")
if M.font_file ~= "" and not morf.fs.exists(M.font_file) then M.font_file = "" end
if appearance.font and appearance.font ~= "" then
  M.font, M.mono, M.font_file = appearance.font, appearance.font, ""
end
M.motion = require(M.appearance.motion)(M)
return M
