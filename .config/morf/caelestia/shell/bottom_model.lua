-- Navigation and connection state for the bottom workspace. Visual themes
-- receive these contexts; they do not own integrations or persistent settings.
local morf = require("morf")
local M = {}
function M.new()
  local model = {
    tab = require("themes.session").keep("caelestia.bottom.tab", 1),
    displayed = require("themes.session").keep("caelestia.bottom.displayed", 1),
    opened = require("themes.session").keep("caelestia.bottom.opened", false),
    tabs = {
      { key = "assistant", name = "Assistant", icon = "auto_awesome" },
      { key = "drop", name = "Drop", icon = "forum" },
    },
  }
  function model.index(key)
    for i, tab in ipairs(model.tabs) do if tab.key == key then return i end end
  end
  function model.select(key)
    local i = type(key) == "number" and key or model.index(key)
    if i and model.tabs[i] then model.tab:set(i) return i end
  end
  function model.showing(key) return model.tabs[model.tab:get()].key == key end
  function model.present(index)
    if index == model.tab:get() then model.displayed:set(index) end
  end
  function model.screen_size()
    morf.screens_revision()
    local screen = morf.screens[1] or {}
    return screen.width or 1920, screen.height or 1080
  end
  function model.desk_size()
    local _, _, w, h = require("bar").desk()
    return w, h
  end
  local contexts = {}
  for i, tab in ipairs(model.tabs) do
    contexts[tab.key] = { key = tab.key, title = tab.name,
      status = tab.key == "assistant" and "Not connected" or "Not connected yet",
      active = function() return model.opened:get() and model.displayed:get() == i end }
  end
  -- In the one frame every panel page has (themes/layouts/page.lua).
  function model.page(key, w, h)
    local ctx = contexts[key]
    local page = require("pages").all[key]
    return (require("themes.layouts.page").frame { id = "page-" .. key, width = w, height = h, title = ctx.title,
      titled = require("responsive").compact(), title_id = page and page.title_id, active = ctx.active,
      build = function(bw, bh) return require(key).build(ctx, bw, bh) end })
  end
  morf.effect("caelestia.bottom.presentation", function()
    for _, tab in ipairs(model.tabs) do
      require("presentation").set("bottom." .. tab.key, contexts[tab.key].active())
    end
  end)
  return model
end
return M
