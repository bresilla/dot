-- Notification history, in the page template (themes/layouts/page.lua):
-- the panel's frame titles it "Notifications"; under that a summary card
-- (how many, from how many apps, Clear all), then one card per
-- application -- its emblem, name, the card's word, and its lines (shut)
-- or, opened, every entry as a small status card with Dismiss and Copy.
-- An empty history is the template's empty block. Grouping, expansion and
-- actions are shell/notification_history.lua's.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")
local P = require("themes.layouts.page")
local text_of = require("themes.notification_text")
local C = theme.color
local V = {}
local plain, ago, kind_of = text_of.plain, text_of.ago, text_of.kind

function V.build(state, width, height)
  local W = type(width) == "number" and width or 408
  local INNER = P.inner(W)
  local GROUPS, LINES = 8, 4
  local LABEL_H = L.lh(L.role_size("label"))
  local BODY = theme.size.small
  local BODY_H = L.lh(BODY)
  local LINE = math.max(22, BODY_H)
  local APP_H = L.heading_h(L.role_size("section"))
  local HEAD_H = math.max(40, APP_H + LABEL_H + 2)
  -- An opened entry's card.
  local ITEM_SIZE = theme.size.small + 1
  local IT_Y = 8 + LABEL_H + 2
  local IB_Y = IT_Y + L.heading_h(ITEM_SIZE)
  local BTN_Y = IB_Y + BODY_H + 6
  local BTN_H = 30
  local ITEM_H = BTN_Y + BTN_H + 10

  local function group_kind(g)
    if not g then return "info" end
    if g.urgency == 2 then return "alert" end
    return kind_of(g.items[1])
  end

  -- One line of a shut group: a mark, the summary, then the body, cut to fit.
  local function line(n_of, tag, shown)
    local function signal() return kit.signal(kind_of(n_of()))() end
    local summary = kit.heading { id = "sidebar-summary-" .. tag, scope = "sidebar.notifications", level = "caption",
      visible = shown, ink = signal, font_size = BODY, height = LINE,
      text = function() local n = n_of() return n and plain(n.summary) or "" end,
    }
    local body = kit.text {
      text = function() local n = n_of() return n and plain(n.body) or "" end,
      font_size = BODY, elide = "right", height = LINE, vertical_alignment = "center",
      width = function() return math.max(0, INNER - 20 - (summary.layout_width or summary.width or 0) - 14) end,
      color = kit.ink("lo"),
    }
    return ui.Row {
      width = INNER, height = LINE, gap = 7, align = "center",
      visible = function() return n_of() ~= nil end,
      ui.Item { width = 6, height = 6 },
      kit.surface { width = 6, height = 6, radius = L.control_round(6), color = signal },
      summary, body,
    }
  end

  -- An entry of an opened group: a small status card.
  local function item(n_of, tag, shown)
    local function kind() return kind_of(n_of()) end
    local function signal() return kit.signal(kind())() end
    local function act(action) return function() local n = n_of() if n then action(n) end end end
    local IW = INNER
    return ui.Item {
      width = IW, height = ITEM_H,
      visible = function() return n_of() ~= nil end,
      kit.surface { anchors = { fill = true }, radius = kit.round(12),
        color = function() return C.surfaceContainerHigh:mix(signal(), .05) end },
      kit.label { x = 12, y = 8, width = IW - 24 - 70, elide = "right", color = signal,
        text = function()
          local n = n_of()
          if not n then return "" end
          local code = kit.code(n.id, "SD. ###/##.##")
          return text_of.word(kind()) .. (code ~= "" and ("  " .. code) or "")
        end },
      kit.label { anchors = { right = true, right_margin = 12 }, y = 8, width = 70, horizontal_alignment = "right",
        text = function() local n = n_of() return n and ago(n.time) or "" end },
      kit.emblem { x = 12, y = IT_Y + 2, size = 26, kind = kind },
      kit.heading { id = "sidebar-item-title-" .. tag, scope = "sidebar.notifications", level = "caption", visible = shown,
        x = 48, y = IT_Y, width = IW - 60, elide = "right", ink = signal, font_size = ITEM_SIZE,
        text = function() local n = n_of() return n and plain(n.summary) or "" end,
      },
      kit.text { x = 48, y = IB_Y, width = IW - 60, height = BODY_H, elide = "right", font_size = BODY,
        text = function() local n = n_of() return n and plain(n.body) or "" end, color = kit.ink("lo") },
      ui.Row { x = 48, y = BTN_Y, gap = 8,
        P.button { id = "sidebar-dismiss-" .. tag, icon = "close", label = "Dismiss", height = BTN_H,
          on_clicked = act(function(n) state.forget(n.id) end) },
        P.button { id = "sidebar-copy-" .. tag, icon = "content_copy", label = "Copy", height = BTN_H,
          on_clicked = act(function(n) state.copy(n) end) },
      },
    }
  end

  -- An application's card: its head (emblem, name, word and time, the
  -- disclosure), then its lines or its entries.
  local rows = {}
  local function group_row(i)
    local function g() return state.groups()[i] end
    local function kind() return group_kind(g()) end
    local function signal() return kit.signal(kind())() end
    local function is_open() local x = g() return x ~= nil and state.is_open(x.app) end
    local lines, items = { width = INNER, gap = 0 }, { width = INNER, gap = 6 }
    local item_nodes = {}
    for k = 1, LINES do
      local function n_of()
        local x = g()
        return x and x.items[k] or nil
      end
      lines[k] = line(n_of, i .. "-" .. k, function() return n_of() ~= nil and not is_open() end)
      item_nodes[k] = item(n_of, i .. "-" .. k, function() return n_of() ~= nil and is_open() end)
      items[k] = item_nodes[k]
    end
    lines.visible = function() return g() ~= nil and not is_open() end
    items.visible = function() return g() ~= nil and is_open() end
    local expand = kit.disclose_area({
      id = "sidebar-group-expand-" .. i,
      anchors = { right = true, vertical_center = true }, width = 52, height = 30, cursor = "pointer",
      ui.Row {
        anchors = { center_in = true }, gap = 2, align = "center",
        kit.text { text = function() local x = g() return x and tostring(#x.items) or "" end,
          font_size = theme.size.small, color = signal },
        kit.icon(function() return is_open() and "expand_less" or "expand_more" end, 18, signal),
      },
    }, is_open, function()
      local x = g()
      if not x then return end
      state.toggle(x.app)
      -- Opening, its entries come in evenly, one after the other.
      if state.is_open(x.app) then kit.bud(item_nodes, true, { delay = 30, stagger = 40 }) end
    end)
    kit.hover(expand, function(hovered) return signal():alpha(hovered and .2 or .07) end, L.control_round(30))
    local text_w = INNER - 40 - 64
    local head = ui.Item { width = INNER, height = HEAD_H,
      kit.emblem { anchors = { vertical_center = true }, size = 28, kind = kind },
      ui.Column { x = 40, anchors = { vertical_center = true }, gap = 2,
        kit.heading { scope = "sidebar.notifications", level = "section", visible = function() return g() ~= nil end,
          id = "sidebar-group-app-" .. i, ink = kit.ink("hi"), width = text_w, height = APP_H, elide = "right",
          text = function() local x = g() return x and x.app or "" end },
        kit.label { width = text_w, elide = "right", color = signal,
          text = function()
            local x = g()
            if not x then return "" end
            local code = kit.code(x.app, "GRP. ##-###")
            local when = x.items[1] and ago(x.items[1].time) or ""
            return text_of.word(kind()) .. (when ~= "" and ("  ·  " .. when) or "") .. (code ~= "" and ("  " .. code) or "")
          end },
      },
      expand,
    }
    return P.section { id = "sidebar-group-" .. i, width = W, visible = function() return g() ~= nil end,
      head, L.rule { width = INNER }, ui.Column(lines), ui.Column(items) }
  end

  -- ------------------------------------------------------------- summary --

  local alert = kit.signal("alert")
  local function tally()
    local apps, n = #state.groups(), state.count()
    return ("%d app%s · %d notification%s"):format(apps, apps == 1 and "" or "s", n, n == 1 and "" or "s")
  end
  local clear = P.button { id = "sidebar-clear", icon = "clear_all", label = "Clear all", on_clicked = state.clear }
  local summary = P.section { id = "sidebar-summary", width = W, title = "History",
    note = function() local c = kit.code("history.buffer", "BUF ##/99") return c ~= "" and c or "" end,
    visible = function() return state.count() > 0 end,
    P.row { id = "sidebar-summary-row", width = INNER, icon = "notifications",
      on = function()
        for _, g in ipairs(state.groups()) do if g.urgency == 2 then return true end end
        return false
      end,
      title = function()
        local n = state.count()
        return ("%d notification%s"):format(n, n == 1 and "" or "s")
      end,
      subtitle = tally, trailing = clear },
    kit.meter { width = INNER, height = 6, count = 20,
      value = function() return math.min(1, state.count() / 20) end,
      color = function()
        for _, g in ipairs(state.groups()) do if g.urgency == 2 then return alert() end end
        return kit.signal("accent")()
      end },
  }

  -- Nothing kept: the template's empty block (with the ids the specs read).
  local empty = P.section { id = "sidebar-empty", width = W, visible = function() return state.count() == 0 end,
    ui.Column { width = INNER, gap = 8, align = "center",
      ui.Item { width = 1, height = 8 },
      kit.emblem { size = 42, kind = "ok" },
      kit.heading { scope = "sidebar.notifications", visible = function() return state.count() == 0 end,
        id = "sidebar-empty-label", level = "caption", ink = kit.ink("hi"),
        text = L.term("history.empty", "You're all caught up"), horizontal_alignment = "center", width = INNER - 2 * P.PAD },
      kit.text { text = "No notifications", font_size = L.SIZE.body, color = kit.ink("lo"),
        horizontal_alignment = "center", width = INNER - 2 * P.PAD },
      ui.Item { width = 1, height = 8 },
    } }

  -- The page scrolls (P.page's shape; built by hand so the groups' headings
  -- know the viewport they reveal in).
  local list_node, list, list_t, list_ctl = kit.scroll({ id = "sidebar-history-list", width = W, height = height,
    clip = true })
  local function build_rows() for i = 1, GROUPS do rows[i] = group_row(i) end end
  if kit.with_viewport then kit.with_viewport(function() return list end, build_rows) else build_rows() end
  local col = { width = W, gap = P.GAP, summary, empty }
  for i = 1, GROUPS do col[#col + 1] = rows[i] end
  col[#col + 1] = ui.Item { width = 1, height = P.GAP }
  local column = ui.Column(col)
  ui.reparent(column, list)
  list_ctl.set_content(column)

  --- Clears the history: the groups fade and shrink a touch, one after the
  --- other, then go.
  local clearing = false
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
    shown[#shown + 1] = summary
    leaving = kit.bud(shown, false, { leave_stagger = 35 })
    return 170 + 35 * (#shown - 1)
  end
  local function reset_clear()
    stop(leaving) leaving = {}
    clearing = false
    for _, row in ipairs(rows) do row.scale, row.opacity = 1, 1 end
    summary.scale, summary.opacity = 1, 1
  end

  local pane = ui.Item { id = "sidebar-history", width = W, height = height, list_node }

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
