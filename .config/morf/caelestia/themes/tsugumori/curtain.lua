-- A solid accent cover, never a fade over the controls. The cover retracts
-- to the right after the panel arrives. Only numeric scene properties move.
local ui = require("morf.ui")
-- Fictional unit call signs: each drawer has its own stable identity.
local units = {
  dashboard = {"ツクヨミ", "TSUKUYOMI", "001"},
  sidebar = {"ライデン", "RAIDEN", "002"},
  leftbar = {"シラヌイ", "SHIRANUI", "003"},
  bottom = {"カゲロウ", "KAGEROU", "004"},
  capture = {"ハヤブサ", "HAYABUSA", "005"},
  launcher = {"ハガネ", "HAGANE", "006"},
  session = {"アマテラス", "AMATERASU", "007"},
  keyboard = {"コダマ", "KODAMA", "008"},
  polkit = {"コンゴウ", "KONGOU", "009"},
  keyring = {"ヤタガラス", "YATAGARASU", "010"},
  authsteps = {"ムラサメ", "MURASAME", "011"},
}
return function(theme, host, id)
  local C = theme.color
  local unit = units[id:gsub("^drawer%-", "")] or {"ツクモ", "TSUKUMO", "000"}
  local function ink() return C.onPrimary end
  local function text(value, props)
    props.text, props.color = value, ink
    props.font_family = props.font_family or theme.font
    return ui.Text(props)
  end
  local cover = ui.Rect {
    id = id .. "-curtain", z = 100, clip = true,
    x = 0,
    width = host.width,
    anchors = { top = true, bottom = true },
    visible = false,
    color = function() return C.primary end,
    -- Ignore presses on covered controls, including during interrupted exits.
    require("lib.kit.widgets").shield { anchors = { fill = true } },
    ui.Column { anchors = { center_in = true }, align = "center", gap = 8,
      text(unit[1], {id=id.."-unit-name",font_size=32,font_weight=500,letter_spacing=3,
        font_family="M+1 Nerd Font, Noto Sans CJK JP, Noto Sans JP, sans-serif"}),
      text(unit[2], {id=id.."-unit-callsign",font_size=10,letter_spacing=2,opacity=.72}),
    },
    text("TS / "..unit[3], { x = 22, anchors = { bottom = true, bottom_margin = 20 }, font_size = 11 }),
    text("SYSTEM\nREGISTER", { anchors = { right = true, right_margin = 20, top = true, top_margin = 20 }, font_size = 11 }),
  }
  for _, anchors in ipairs {
    { left = true, top = true }, { right = true, top = true },
    { left = true, bottom = true }, { right = true, bottom = true },
  } do
    local corner = ui.Item { anchors = anchors, width = 24, height = 24,
      ui.Rect { x = 8, y = anchors.bottom and 14 or 8, width = 10, height = 2, color = ink },
      ui.Rect { x = anchors.right and 16 or 8, y = 8, width = 2, height = 8, color = ink },
    }
    ui.reparent(corner, cover)
  end
  ui.reparent(cover, host)
  return cover
end
