-- Desktop bindings for the keyboard gestures shared with lock and greet.
local shared=require("themes.keyboard")
local M={area=shared.area}
function M.contacts(region,allowed,single)
  local function keyboard() return require("keyboard") end
  return shared.contacts(region,{
    allowed=function() return require("responsive").portrait() and (not allowed or allowed()) end,
    active=function() return keyboard().active() end,
    show=function(mode) return keyboard().show(mode) end,
    hide=function() return keyboard().set(false) end,
    mode=function() return keyboard().keys.mode:get() end,
    cancel=function()
      local kb=package.loaded.keyboard
      if kb and kb.keys then kb.keys.cancel() end
    end,
    height=function() return (((morf.screens or {})[1] or {}).height or morf.surface.height)-shared.inset:get() end,
  },single)
end
return M
