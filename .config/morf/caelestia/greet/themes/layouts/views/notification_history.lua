-- Notification history: the log of status cards.
--
-- The pane: the count as its title and a meter of how full the history
-- is. Each application is a framed group with its emblem, name, the card's
-- word and a rule, then its lines (shut) or, opened, every entry as a
-- small status card with dismiss and copy controls. An empty history is
-- the clear card; the clear-all control sits at the foot. Grouping, expansion and actions are
-- shell/notification_history.lua's.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")
local text_of = require("themes.notification_text")
local C = theme.color
local V = {}
local plain, ago, kind_of = text_of.plain, text_of.ago, text_of.kind

function V.build(state, width, height)
  local CARD_W = type(width) == "number" and width or 408
  local ROW_W, GROUPS, LINES = CARD_W - 24, 8, 4
  local LABEL_H = L.lh(L.role_size("label"))
  local BODY = theme.size.small
  local BODY_H = L.lh(BODY)
  local LINE = math.max(20, BODY_H)
  local APP_H = L.heading_h(L.role_size("section"))
  -- A group's head: emblem, the application, its word and codes, a rule.
  local KIND_Y = 6 + APP_H
  local RULE_Y = KIND_Y + LABEL_H + 2
  local LINES_Y = RULE_Y + 6
  -- An opened entry's card.
  local ITEM_SIZE = theme.size.small + 1
  local IT_Y = 4 + LABEL_H + 2
  local IB_Y = IT_Y + L.heading_h(ITEM_SIZE)
  local BTN_Y = IB_Y + BODY_H + 4
  local BTN_H = 24
  local ITEM_H = BTN_Y + BTN_H + 6
  -- The pane's head and foot.
  local TITLE_H = L.heading_h(L.role_size("section"))
  local TITLE_Y = 12
  local METER_Y = TITLE_Y + LABEL_H + 2
  local TOP = TITLE_Y + math.max(TITLE_H, LABEL_H + 10) + 12
  local CLEAR_H, CLEAR_B = 30, 14
  local FOOT = CLEAR_B + 2 * LABEL_H + 12

  local function group_height(g)
    if not g then return 0 end
    local n = math.min(#g.items, LINES)
    if state.is_open(g.app) then return LINES_Y + n * ITEM_H + (n - 1) * 6 + 10 end
    return LINES_Y + n * LINE + 8
  end
  local function group_kind(g)
    if not g then return "info" end
    if g.urgency == 2 then return "alert" end
    return kind_of(g.items[1])
  end

  -- One line of a shut group: a mark, the summary, then the body, cut to fit.
  local function line(n_of, k, w, tag, shown)
    local function signal() return kit.signal(kind_of(n_of()))() end
    local summary = kit.heading { id = "sidebar-summary-" .. tag, scope = "sidebar.notifications", level = "caption",
      visible = shown, ink = signal, font_size = BODY, height = LINE,
      text = function() local n = n_of() return n and plain(n.summary) or "" end,
    }
    local body = kit.text {
      text = function() local n = n_of() return n and plain(n.body) or "" end,
      font_size = BODY, elide = "right", height = LINE, vertical_alignment = "center",
      width = function() return math.max(0, w - (summary.layout_width or summary.width or 0) - 22) end,
      color = kit.ink("lo"),
    }
    return ui.Row {
      x = 14, y = LINES_Y + (k - 1) * LINE, height = LINE, gap = 7, align = "center",
      visible = function() return n_of() ~= nil end,
      kit.surface { width = 6, height = 6, radius = L.control_round(6), color = signal },
      summary, body,
    }
  end

  -- An entry of an opened group: a small status card.
  local function item(n_of, k, tag, shown)
    local function kind() return kind_of(n_of()) end
    local function signal() return kit.signal(kind())() end
    local function button(icon, label, id, action)
      local area = kit.action {
        id = id, width = 96, height = BTN_H, cursor = "pointer",
        on_clicked = function() local n = n_of() if n then action(n) end end,
        ui.Row { anchors = { center_in = true }, gap = 5, align = "center",
          kit.icon(icon, 14, kit.ink("hi")),
          kit.label { text = label, color = kit.ink("hi") },
        },
      }
      return kit.hover(area, function(hovered) return signal():alpha(hovered and .18 or .06) end,
        L.control_round(BTN_H))
    end
    local W = ROW_W - 24
    return ui.Item {
      x = 12, y = LINES_Y + (k - 1) * (ITEM_H + 6), width = W, height = ITEM_H,
      visible = function() return n_of() ~= nil end,
      kit.surface { anchors = { fill = true }, radius = L.control_round(28),
        color = function() return C.surfaceContainerHigh:mix(signal(), .05) end },
      L.decor_box("corners", { length = 6, color = kit.stroke("mark") }),
      kit.label { x = 10, y = 4, width = W - 10 - 70, elide = "right", color = signal,
        text = function()
          local n = n_of()
          if not n then return "" end
          local code = kit.code(n.id, "SD. ###/##.##")
          return text_of.word(kind()) .. (code ~= "" and ("  " .. code) or "")
        end },
      kit.label { anchors = { right = true, right_margin = 10 }, y = 4, width = 60, horizontal_alignment = "right",
        text = function() local n = n_of() return n and ago(n.time) or "" end },
      kit.emblem { x = 10, y = IT_Y + 2, size = 26, kind = kind },
      kit.heading { id = "sidebar-item-title-" .. tag, scope = "sidebar.notifications", level = "caption", visible = shown,
        x = 44, y = IT_Y, width = W - 56, elide = "right", ink = signal, font_size = ITEM_SIZE,
        text = function() local n = n_of() return n and plain(n.summary) or "" end,
      },
      kit.text { x = 44, y = IB_Y, width = W - 56, height = BODY_H, elide = "right", font_size = BODY,
        text = function() local n = n_of() return n and plain(n.body) or "" end, color = kit.ink("lo") },
      ui.Row { x = 44, y = BTN_Y, gap = 8,
        button("close", "Dismiss", "sidebar-dismiss-" .. tag, function(n) state.forget(n.id) end),
        button("content_copy", "Copy", "sidebar-copy-" .. tag, function(n) state.copy(n) end),
      },
    }
  end

  local rows = {}
  local function group_row(i)
    local function g() return state.groups()[i] end
    local function kind() return group_kind(g()) end
    local function signal() return kit.signal(kind())() end
    local lines, items = {}, {}
    for k = 1, LINES do
      local function n_of()
        local x = g()
        return x and x.items[k] or nil
      end
      lines[k] = line(n_of, k, ROW_W - 28, i .. "-" .. k, function()
        local x = g()
        return n_of() ~= nil and x ~= nil and not state.is_open(x.app)
      end)
      items[k] = item(n_of, k, i .. "-" .. k, function()
        local x = g()
        return n_of() ~= nil and x ~= nil and state.is_open(x.app)
      end)
    end
    local shut = ui.Item { anchors = { fill = true }, visible = function() local x = g() return x ~= nil and not state.is_open(x.app) end, table.unpack(lines) }
    local open = ui.Item { anchors = { fill = true }, visible = function() local x = g() return x ~= nil and state.is_open(x.app) end, table.unpack(items) }
    -- The group's disclosure: it follows the history's open set, and a
    -- press or a key asks that set to change.
    local function is_open() local x = g() return x ~= nil and state.is_open(x.app) end
    local expand = kit.disclose_area({
      id = "sidebar-group-expand-" .. i,
      anchors = { right = true, right_margin = 10 }, y = 8, width = 48, height = 22, cursor = "pointer",
      ui.Row {
        anchors = { center_in = true }, gap = 2, align = "center",
        kit.text { text = function() local x = g() return x and tostring(#x.items) or "" end,
          font_size = theme.size.small - 2, color = signal },
        kit.icon(function() local x = g() return (x and state.is_open(x.app)) and "expand_less" or "expand_more" end, 14,
          signal),
      },
    }, is_open, function()
      local x = g()
      if not x then return end
      state.toggle(x.app)
      -- Opening, its entries come in evenly, one after the other.
      if state.is_open(x.app) then kit.bud(items, true, { delay = 30, stagger = 40 }) end
    end)
    kit.hover(expand, function(hovered) return signal():alpha(hovered and .2 or .07) end, L.control_round(22))
    return ui.Item {
      id = "sidebar-group-" .. i,
      width = ROW_W, clip = true,
      height = function() return group_height(g()) end,
      behavior = { height = { duration = theme.duration.normal, easing = theme.ease.emphasized_decel } },
      visible = function() return g() ~= nil end,
      kit.surface { anchors = { fill = true }, radius = L.control_round(34),
        color = function() return C.surfaceContainer:mix(signal(), kind() == "alert" and .08 or .02) end },
      L.decor_box("corners", { length = 8, color = kit.stroke("mark") }),
      kit.emblem { x = 10, y = 8, size = 22, kind = kind },
      kit.heading { scope = "sidebar.notifications", level = "section", visible = function() return g() ~= nil end,
        id = "sidebar-group-app-" .. i, ink = kit.ink("hi"),
        x = 40, y = 6, width = ROW_W - 40 - 130, height = APP_H, elide = "right",
        text = function() local x = g() return x and x.app or "" end,
      },
      kit.label { x = 40, y = KIND_Y, width = ROW_W - 40 - 70, elide = "right", color = signal,
        text = function()
          local x = g()
          if not x then return "" end
          local code = kit.code(x.app, "GRP. ##-###")
          return text_of.word(kind()) .. (code ~= "" and ("  " .. code) or "")
        end },
      kit.label { anchors = { right = true, right_margin = 66 }, y = 12, width = 60, horizontal_alignment = "right",
        text = function() local x = g() return x and x.items[1] and ago(x.items[1].time) or "" end },
      L.rule { x = 10, y = RULE_Y, width = ROW_W - 20 },
      expand,
      shut,
      open,
    }
  end
  -- The list scrolls; its headings reveal as they scroll into view.
  local list_node, list, list_t, list_ctl = kit.scroll({
    id = "sidebar-history-list",
    x = 12, y = TOP, width = ROW_W,
    height = function() return math.max(40, height() - TOP - FOOT) end,
    clip = true,
  })
  local function build_rows() for i = 1, GROUPS do rows[i] = group_row(i) end end
  if kit.with_viewport then kit.with_viewport(function() return list end, build_rows) else build_rows() end
  local column = ui.Column { gap = 8, table.unpack(rows) }
  ui.reparent(column, list)
  list_ctl.set_content(column)

  -- ------------------------------------------------------------------ pane --

  -- Nothing kept: the clear card.
  local EMB = 42
  local EH = 14 + EMB + 10 + L.heading_h(L.role_size("caption")) + 12
  local empty = ui.Item {
    id = "sidebar-empty",
    x = 12, y = TOP, width = ROW_W, height = EH,
    visible = function() return state.count() == 0 end,
    kit.panel { width = ROW_W, height = EH, color = kit.signal("ok") },
    kit.status_line { x = 14, y = 14, width = ROW_W - 28, kind = "ok", title = L.term("history.empty", "Clear"),
      subtitle = "No notifications", size = EMB, title_width = 120 },
    kit.heading { scope = "sidebar.notifications", visible = function() return state.count() == 0 end,
      id = "sidebar-empty-label", x = 14, y = 14 + EMB + 10, width = ROW_W - 28, level = "caption",
      ink = kit.signal("ok"), text = "You're all caught up",
    },
  }

  --- Clears the history: the groups fade and shrink a touch, one after the
  --- other, then go.
  local clearing = false
  local clear
  local running, leaving = {}, {}
  local function stop(handles)
    for _, handle in ipairs(handles) do handle:stop() end
  end
  local function animate_clear()
    clearing = true
    stop(running) running = {}
    local shown = {}
    for _, row in ipairs(rows) do if row.visible then shown[#shown + 1] = row end end
    if #shown == 0 then return 0 end
    shown[#shown + 1] = clear
    leaving = kit.bud(shown, false, { leave_stagger = 35 })
    return 170 + 35 * (#shown - 1)
  end
  local function reset_clear()
    stop(leaving) leaving = {}
    clearing = false
    for _, row in ipairs(rows) do row.scale, row.opacity = 1, 1 end
    clear.scale, clear.opacity = 1, 1
  end

  -- Clear all: an alert control at the foot of the pane.
  local alert = kit.signal("alert")
  clear = kit.action {
    id = "sidebar-clear",
    anchors = { right = true, bottom = true, right_margin = 12, bottom_margin = CLEAR_B },
    width = 132, height = CLEAR_H, cursor = "pointer",
    visible = function() return state.count() > 0 end,
    on_clicked = state.clear,
    L.decor_box("hatch", { x = 1, y = 1, width = 26, height = CLEAR_H - 2, spacing = 6, weight = 2.5, color = alert }),
    ui.Row { x = 34, y = 0, height = CLEAR_H, gap = 6, align = "center",
      kit.icon("clear_all", 16, alert),
      kit.label { text = "Clear all", color = alert },
    },
  }
  kit.hover(clear, function(hovered) return alert():alpha(hovered and .22 or .1) end, L.control_round(CLEAR_H))

  local pane = ui.Item {
    id = "sidebar-history",
    width = CARD_W, height = height,
    kit.surface { anchors = { fill = true }, radius = L.control_round(30), color = function() return C.surfaceContainerLow end },
    kit.heading { scope = "sidebar.notifications",
      id = "sidebar-title",
      x = 12, y = TITLE_Y, width = ROW_W - 140, height = TITLE_H, elide = "right",
      level = "section",
      text = function()
        local n = state.count()
        if n == 0 then return "Notifications" end
        return ("%d notification%s"):format(n, n == 1 and "" or "s")
      end,
      ink = kit.ink("hi"),
    },
    kit.label { anchors = { right = true, right_margin = 12 }, y = TITLE_Y, width = 120, horizontal_alignment = "right",
      elide = "left", text = kit.code("history.buffer", "BUF ##/99") },
    kit.meter { x = CARD_W - 12 - 120, y = METER_Y, width = 120, height = 6, count = 20,
      value = function() return math.min(1, state.count() / 20) end,
      color = function()
        for _, g in ipairs(state.groups()) do if g.urgency == 2 then return kit.signal("alert")() end end
        return kit.signal("accent")()
      end },
    L.rule { x = 12, y = TOP - 8, width = ROW_W },
    list_node,
    empty,
    -- The foot rule and the tally under the list.
    L.rule { x = 12, anchors = { bottom = true, bottom_margin = FOOT - 6 }, width = ROW_W },
    kit.label { x = 12, anchors = { bottom = true, bottom_margin = CLEAR_B + LABEL_H }, width = ROW_W - 150,
      elide = "right", text = function() local c = kit.code("history", "PT - ###") return c ~= "" and c or "History" end },
    kit.label { x = 12, anchors = { bottom = true, bottom_margin = CLEAR_B }, width = ROW_W - 150, elide = "right",
      text = function()
        local apps, n = #state.groups(), state.count()
        return ("%d app%s · %d notification%s"):format(apps, apps == 1 and "" or "s", n, n == 1 and "" or "s")
      end },
    clear,
  }

  local was, count = false, state.count()
  morf.effect("caelestia.history.presentation", function()
    local active, now = state.active(), state.count()
    if not clearing then
      if active ~= was then
        stop(running) running = {}
        if active then running = kit.bud(rows, true, { delay = 90, stagger = 30 }) end
      elseif active and now ~= count then
        stop(running)
        running = kit.bud({ now == 0 and empty or rows[1] }, true, { delay = 0 })
      end
    end
    was, count = active, now
  end, { owner = pane })
  return { node = pane, animate_clear = animate_clear, reset_clear = reset_clear }
end
return V
