-- Fade the whole disabled button once, so its caption, icon and background
-- stay together. A layout-owned area or an explicit opacity keeps its own
-- presentation; the archetype still decides whether it can take input.
local M={}

function M.install(skins,opacity)
  local names={"Press"}
  for _,name in ipairs(require("lib.kit.contract").archetypes.Press.widgets) do names[#names+1]=name end
  for _,name in ipairs(names) do
    local draw=skins[name]
    if type(draw)=="function" then
      skins[name]=function(t,spec,node,...)
        if node and spec.widget~="area" and spec.opacity==nil then
          node.opacity=function() return t.enabled==false and opacity or 1 end
        end
        return draw(t,spec,node,...)
      end
    end
  end
end

return M
