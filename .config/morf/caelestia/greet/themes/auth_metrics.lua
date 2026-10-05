-- Logical pixels: compositor scaling already accounts for monitor DPI.
-- Keep controls readable on short outputs; the sheet scrolls instead of
-- shrinking text and keyboard targets until they are unusable.
return function(width, height, keyboard)
  local onscreen = height > width or not keyboard
  local scale = math.min(2.4, math.max(.75, math.min(width / 1920, height / 1080)))
  local function s(value) return math.max(1, math.floor(value * scale + .5)) end
  return s, onscreen
end
