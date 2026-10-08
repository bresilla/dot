-- Pattern numbering is row-major. Diagonals count as neighbours; no skips.
local M = {}
function M.validate(dots)
  if type(dots) ~= "table" or #dots < 4 or #dots > 9 then
    return false, "Connect four to nine dots"
  end
  local seen, previous = {}, nil
  for _, dot in ipairs(dots) do
    if type(dot) ~= "number" or dot % 1 ~= 0 or dot < 1 or dot > 9 then
      return false, "Use only the dots 1 to 9"
    end
    if seen[dot] then return false, "Each dot can be used only once" end
    if previous and (math.abs((dot-1)//3 - (previous-1)//3) > 1
        or math.abs((dot-1)%3 - (previous-1)%3) > 1) then
      return false, "Connect neighbouring dots; diagonals are allowed"
    end
    seen[dot], previous = true, dot
  end
  return true
end
return M
