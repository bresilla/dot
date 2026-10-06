-- The font picker over the Lule page: the kit's font picker (a search over
-- a list of installed families, each previewed in itself), a page of
-- families at a time, in a popup card.
local morf, ui = require("morf"), require("morf.ui")
-- `page_w`: the Lule page's width; on a narrow one the popup fits it and
-- opens just above the Font button (`above`, its y on the page).
return function(state, page_w, above)
  local kit, theme = require("kit"), require("theme")
  local C, fonts = theme.color, require("themes.fonts")
  local narrow = page_w and page_w < 600
  local W, SIZE = narrow and math.min(434, page_w - 24) or 434, 5
  local POP_X = narrow and math.floor((page_w - W) / 2) or 510
  local POP_Y = narrow and above and math.max(8, above - 330 - 8) or 130
  -- The page in sight; a short last page keeps its rows' places, empty.
  local function page()
    local rows, out = fonts.rows:get(), {}
    if #rows == 0 then return out end
    local first = (fonts.page:get() - 1) * SIZE
    for i = 1, SIZE do out[i] = rows[first + i] or "" end
    return out
  end
  local picker = require("lib.kit.composites").font_picker { id = "lule-font", x = 12, y = 10, width = W - 24,
    height = 270, row_height = 42, sample = false, filter = false, fonts = page,
    preview = "The quick brown fox · 0123456789", placeholder = "Search installed fonts…",
    value = function() return require("themes").font end,
    focus = function() return fonts.opened:get() end,
    status = function() return fonts.status:get() end,
    on_search = function(value) fonts.filter(value) end,
    on_escape = fonts.close,
    on_picked = function(family)
      if not state.busy:get() and not state.appearance.busy:get() then fonts.choose(family) end
    end }
  local function button(id, label, width, action)
    return kit.pill { id = id, label = label, width = width, height = 30, on_clicked = action }
  end
  local popup = kit.card { id = "lule-font-popup", x = POP_X, y = POP_Y, width = W, height = 330, radius = 16,
    ui.MouseArea { anchors = { fill = true }, on_clicked = function() end },
    picker,
    ui.Row { x = 12, y = 288, gap = 8,
      button("lule-font-default", "Theme default", narrow and 112 or 138, function() fonts.choose("") end),
      button("lule-font-prev", "Back", 64, function() fonts.step(-1, SIZE) end),
      button("lule-font-next", "More", 64, function() fonts.step(1, SIZE) end),
      kit.subtitle { width = 100, y = 8, font_size = 11, horizontal_alignment = "right",
        text = function() return fonts.page:get() .. " / " .. math.max(1, math.ceil(#fonts.rows:get() / SIZE)) end },
    },
  }
  local root = ui.Item { id = "lule-font-picker", anchors = { fill = true }, z = 100,
    visible = function() return fonts.opened:get() end,
    -- The scrim holds presses back from the page; the picker is a kit
    -- Popup, shut by Escape or a press outside it.
    ui.MouseArea { anchors = { fill = true },
      kit.surface { anchors = { fill = true }, color = function() return C.surface:alpha(.5) end } }, popup,
  }
  require("lib.kit.popup").track(popup, { open = function() return fonts.opened:get() end,
    close_policy = "escape+outside", modal = true, on_close = function() fonts.close() end })
  morf.effect("lule.font-picker.close", function()
    if not state.active:get() or state.appearance.busy:get() then fonts.close() end
  end, { owner = root })
  return root
end
