-- Lule page actions and presentation data. The studio retains file scanning,
-- preview workers, applied-palette watching and command lifecycle.
local M = {}
function M.new(studio)
  studio=studio or require("lule_studio")
  local model={key="lule",appearance=require("themes.switcher")}
  for _,key in ipairs {"scheme","selected","mode","method","busy","active","message","failed",
    "folder","folder_draft","files","page","browsing","preview","preview_error"} do model[key]=studio[key] end
  local function ready() return model.active:get() and not model.busy:get() and not model.appearance.busy:get() end
  for _,key in ipairs {"set_folder","select","shuffle","random_apply","step","browse","apply"} do
    model[key]=function(...) if not ready() then return false end return studio[key](...) end
  end
  function model.copy(value) if model.active:get() then return studio.copy(value) end end
  function model.set_mode(value)
    if ready() and (value=="dark" or value=="light") then model.mode:set(value) return true end
    return false
  end
  function model.set_method(value)
    if not ready() then return false end
    for _,name in ipairs {"pigment","median","histogram","tonal"} do
      if value==name then model.method:set(value) return true end
    end
    return false
  end
  function model.pages(size) return math.max(1,math.ceil(#model.files:get()/size)) end
  function model.page_by(delta,size)
    if ready() then model.page:set(math.max(1,math.min(model.pages(size),model.page:get()+delta))) end
  end
  function model.color(key,fallback)
    local scheme=model.scheme:get() or {}
    return (type(key)=="number" and (scheme.colors or {})[key+1] or scheme[key]) or fallback or "#808080"
  end
  function model.filename()
    local path=model.selected:get()
    return path:match("([^/]+)$") or path
  end
  function model.current() return model.selected:get()==(model.scheme:get() or {}).wallpaper end
  function model.escape()
    model.browsing:set(false)
    require("dashboard").drawer.set(false)
  end
  return model
end
return M
