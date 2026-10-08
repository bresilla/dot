-- Non-visual helpers every theme's kit may share. Nothing here draws or
-- decides how anything looks (see THEMING.md, theme rule 2). Append only.
local M = {}

--- A spec value that may be a binding.
function M.get(v) if type(v) == "function" then return v() end return v end

function M.clamp01(v)
  v = tonumber(v) or 0
  return v < 0 and 0 or v > 1 and 1 or v
end

--- Keep a range's moving pieces together. Values received from a service
--- ease; a held control follows the hand immediately. Each target supplies
--- a node and numeric property bindings; the theme supplies its own timing.
function M.follow_range(state,owner,targets,motion)
  local running,initial=nil,true
  morf.effect("range.follow."..tostring(owner),function()
    local direct=state.down or state.dragging
    local timing=M.get(motion)
    local steps={}
    for _,target in ipairs(targets) do
      for property,binding in pairs(target.values) do
        steps[#steps+1]={node=target.node,property=property,to=binding(),
          duration=timing.duration,easing=timing.easing}
      end
    end
    if running then running:stop() running=nil end
    if initial or direct then
      for _,step in ipairs(steps) do step.node[step.property]=step.to end
    else
      running=morf.animation.play {{parallel=steps}}
    end
    initial=false
  end,{owner=owner})
end

--- Bytes in binary units, one decimal under ten: "1.1", "MiB". `unit`
--- forces one.
function M.bytes(n, unit)
  n = tonumber(n) or 0
  local units = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" }
  local i = 1
  if unit then
    for k, u in ipairs(units) do if u == unit then i = k end end
    n = n / 1024 ^ (i - 1)
  else
    while n >= 1024 and i < #units do n = n / 1024 i = i + 1 end
  end
  local text = (n < 10 and i > 1) and ("%.1f"):format(n) or ("%d"):format(math.floor(n + 0.5))
  return text, units[i]
end

local codes = {}
--- A stable pseudo-random string for `key`, `#` digits and `X` hex digits
--- filled from a hash of the key, for themes that print decorative codes.
function M.code(key, shape)
  key = tostring(key or "") .. (shape or "")
  if codes[key] then return codes[key] end
  local h = 5381
  for i = 1, #key do h = (h * 33 + key:byte(i)) % 2147483647 end
  local function n(m) h = (h * 1103515245 + 12345) % 2147483648 return h % m end
  local out = (shape or "##.###/##.##"):gsub("#", function() return tostring(n(10)) end)
    :gsub("X", function() return string.format("%X", n(16)) end)
  codes[key] = out
  return out
end

--- NOW / AVG / PEAK of a list of numbers.
function M.summary(list)
  local n, sum, peak = 0, 0, 0
  for _, v in ipairs(list or {}) do
    v = tonumber(v) or 0
    n, sum = n + 1, sum + v
    if v > peak then peak = v end
  end
  return (list and list[#list]) or 0, n > 0 and sum / n or 0, peak
end

return M
