-- Bar preferences and validated mutations; views only receive this model.
local config=require("config")
local bar=require("bar")
local M={}
function M.new(active)
  local model={key="bar-settings",active=active,
    shows={{"on","visibility","On"},{"off","visibility_off","Off"},{"auto","smartphone","Auto"}},
    sides={{"top","vertical_align_top","Top"},{"bottom","vertical_align_bottom","Bottom"},
      {"left","align_horizontal_left","Left"},{"right","align_horizontal_right","Right"}},
    title_modes={{"on","title","Shown"},{"off","apps","Icons only"}},
  }
  function model.mode()
    local v=config.get("edgebar.enabled")
    return (v=="on" or v=="off") and v or "auto"
  end
  model.side=bar.side
  function model.titles() return config.get("edgebar.titles")~="off" and "on" or "off" end
  local function select(options,key,value)
    if not active() then return false end
    for _,option in ipairs(options) do
      if option[1]==value then
        if key=="edgebar.side" then bar.set_side(value) else config.set(key,value) end
        return true
      end
    end
    return false
  end
  function model.set_mode(value) return select(model.shows,"edgebar.enabled",value) end
  function model.set_side(value) return select(model.sides,"edgebar.side",value) end
  function model.set_titles(value) return select(model.title_modes,"edgebar.titles",value) end
  return model
end
return M
