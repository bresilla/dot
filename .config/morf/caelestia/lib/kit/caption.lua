-- A bounded button legend. Skins supply their own text, measurements and
-- adornments; this keeps the caption between those adornments as it resizes.
local ui=require("morf.ui")
local M={}
local preferred=setmetatable({}, {__mode="k"})
local function get(v) if type(v)=="function" then return v() end return v end

-- Layouts can ask how wide the themed caption wants to be, including its
-- adornments, even while the displayed caption is constrained and elided.
function M.preferred_width(node)
  return preferred[node] and preferred[node]() or nil
end

function M.make(spec)
  local gap=spec.gap or 8
  local left,right=spec.left or 12,spec.right or 12
  local before,after=spec.before or {},spec.after or {}
  local function has_label() return spec.label~=nil and get(spec.label_visible)~=false end
  local function extras()
    local width,n=0,has_label() and 1 or 0
    for _,list in ipairs {before,after} do
      for _,node in ipairs(list) do
        if node.visible~=false then width,n=width+(node.layout_width or 0),n+1 end
      end
    end
    return width+math.max(0,n-1)*gap
  end
  local function natural() return has_label() and spec.measure and (spec.measure.layout_width or 0) or 0 end
  local function wanted() return natural()+extras()+left+right end
  local function width() return math.max(1e-3,get(spec.width) or wanted()) end
  local function label_width() return math.max(1e-3,math.min(natural(),width()-left-right-extras())) end
  local row={gap=gap,align="center",anchors={vertical_center=true}}
  for _,node in ipairs(before) do row[#row+1]=node end
  if spec.label then
    local label=spec.label(label_width)
    label.visible=has_label
    row[#row+1]=label
  end
  for _,node in ipairs(after) do row[#row+1]=node end
  row=ui.Row(row)
  row.x=function()
    return left+(spec.align=="start" and 0 or math.max(0,(width()-left-right-(row.layout_width or 0))/2))
  end
  local node=ui.Item {anchors={center_in=true},width=width,height=spec.height,clip=true,row,
    spec.measure and ui.Item {width=1,height=1,clip=true,spec.measure} or nil}
  preferred[node]=wanted
  return node
end

return M
