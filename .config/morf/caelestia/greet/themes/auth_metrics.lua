-- Logical pixels: compositor scaling already accounts for monitor DPI.
-- Keep controls readable on short outputs; the sheet scrolls instead of
-- shrinking text and keyboard targets until they are unusable.
return function(width, height, keyboard)
  local onscreen = height > width or not keyboard
  -- Upright (a phone) the design is the 1080 x 1920 one.
  local fit = height > width and math.min(width / 1080, height / 1920) or math.min(width / 1920, height / 1080)
  local scale = math.min(2.4, math.max(.75, fit))
  local function s(value) return math.max(1, math.floor(value * scale + .5)) end
  return s, onscreen
end
