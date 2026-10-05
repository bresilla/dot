-- Material's authentication presentation; no secret or agent access.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local V = {}
function V.build(M)
  local W, PAD = 452, 28
  local INNER = W - 2 * PAD
  local FIELD_H, DOT, MAX_DOTS = 52, 11, 18
  local typed = M.typed
  local function pending() local p=M.phase:get() return p=="waiting" or p=="checking" end
  local function final() local p=M.phase:get() return p=="done" or p=="refused" end
  local function face()
    return M.phase:get()=="waiting" and M.info:get():lower():find("look at the camera",1,true)~=nil
  end
  local shake = morf.signal("caelestia.polkit.shake", 0)
  local dots = {}
  for i = 1, MAX_DOTS do
    dots[i] = kit.surface {
      id = "polkit-dot-"..i,
      width = DOT, height = DOT, radius = DOT / 2,
      color = function() return C.primary end,
      visible = function() return typed:get() >= i end,
      scale = function() return typed:get() >= i and 1 or 0 end,
      behavior = { scale = { duration = 260, easing = "out_back" } },
    }
  end

  local submit_area
  submit_area = kit.action {
    id = "polkit-submit",
    anchors = { right = true, right_margin = 7, vertical_center = true },
    width = FIELD_H - 14, height = FIELD_H - 14, cursor = "pointer",
    on_clicked = function() M.submit() end,
    kit.icon("arrow_forward", 22, function() return typed:get() > 0 and C.onPrimary or C.onSurfaceVariant end,
      { anchors = { center_in = true } }),
  }
  kit.hover(submit_area, function(hovered)
    local base = typed:get() > 0 and C.primary or C.surfaceContainerHigh
    return hovered and base:mix(typed:get() > 0 and C.onPrimary or C.onSurface, 0.08) or base
  end, (FIELD_H - 14) / 2)

  local field = ui.MouseArea {
    id = "polkit-field",
    visible = M.can_answer,
    width = INNER, height = FIELD_H, cursor = "text",
    on_clicked = function() M.focus() end,
    translate_x = function() return (shake:get() % 2 == 1) and 10 or 0 end,
    behavior = { translate_x = ui.spring { stiffness = 900, damping = 9 } },
    kit.surface {
      anchors = { fill = true }, radius = FIELD_H / 2,
      color = function() return C.surfaceContainerHighest end,
      border_width = function() return M.phase:get() == "wrong" and 2 or 0 end,
      border_color = kit.signal("alert"),
    },
    kit.decor("corners", { length = 6, color = function()
      return M.phase:get() == "wrong" and kit.signal("alert")() or kit.stroke("mark")()
    end }) or ui.Item {},
    kit.icon(function() return M.phase:get() == "checking" and "hourglass" or "key" end, 22,
      kit.ink("lo"), { x = 20, anchors = { vertical_center = true } }),
    kit.text {
      anchors = { vertical_center = true }, x = 56, width = INNER - 120, elide = "right",
      text = function()
        local r = M.request:get()
        local p = r and r.prompt or ""
        p = p:gsub(":%s*$", "")
        return p ~= "" and p or "Password"
      end,
      color = kit.ink("lo"),
      visible = function() return typed:get() == 0 end,
    },
    ui.Row { x = 56, anchors = { vertical_center = true }, gap = 5, table.unpack(dots) },
    submit_area,
  }

  -- ------------------------------------------------------------ the badge --

  local LOADING = { "soft_burst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval", "flower" }
  local step = morf.signal("caelestia.polkit.step", 1)
  local stepper
  -- The badge works only while something is being checked (a password,
  -- a face); waiting for the person to type, it rests.
  local function busy() return M.phase:get() == "checking" or face() end
  morf.effect("caelestia.polkit.stepper", function()
    local checking = M.opened:get() and busy()
    morf.timer(1, function()
      if checking and not stepper then
        stepper = morf.timer(650, function() step:set(step:get() % #LOADING + 1) end, true)
      elseif not checking and stepper then
        stepper:cancel()
        stepper = nil
      end
    end, false)
  end)

  local function badge_colour()
    local p = M.phase:get()
    if p == "wrong" or p == "refused" then return C.errorContainer end
    if p == "done" then return C.primary end
    return C.primaryContainer
  end
  local function badge_ink()
    local p = M.phase:get()
    if p == "wrong" or p == "refused" then return C.onErrorContainer end
    if p == "done" then return C.onPrimary end
    return C.onPrimaryContainer
  end

  local badge = ui.Item {
    width = 60, height = 60,
    kit.shape {
      id = "polkit-badge", anchors = { fill = true },
      shape = function()
        local p = M.phase:get()
        if busy() then return LOADING[step:get()] end
        if p == "wrong" or p == "refused" then return "sunny" end
        if p == "done" then return "circle" end
        return "cookie9"
      end,
      color = badge_colour,
      loop = function()
        if not M.opened:get() or not busy() then return nil end
        return { rotation = { to = 360, duration = 2600, hold = true } }
      end,
    },
    kit.icon(function()
      local p = M.phase:get()
      if p == "done" then return "check" end
      if p == "wrong" or p == "refused" then return "priority_high" end
      if face() then return "face" end
      if p == "checking" then return "more_horiz" end
      return "shield_lock"
    end, 28, badge_ink, { anchors = { center_in = true }, fill = true }),
  }

  -- ------------------------------------------------------------- the panel --

  local function button(id, label, filled, on_clicked)
    local area = kit.pill {
      id = id, height = 40, width = filled and 148 or 104, label = label,
      on_clicked = on_clicked,
      color = function() return filled and C.primary or C.onSurface:alpha(0) end,
      ink = function() return filled and C.onPrimary or C.primary end,
    }
    if filled then area.visible = M.can_answer end
    return area
  end

  local column = ui.Column {
    x = PAD, y = PAD, width = INNER, gap = 14,
    ui.Row {
      gap = 16, align = "center",
      badge,
      ui.Column {
        gap = 2,
        kit.heading { id = "polkit-title", scope = "polkit", text = function()
          if M.phase:get()=="done" then return "Authenticated" end
          if M.phase:get()=="refused" then return "Not authorized" end
          if pending() then return "Verifying identity" end
          return "Authentication required"
        end, font_size = theme.size.large, font_weight = 600,
          width = INNER - 76, elide = "right" },
        kit.text {
          width = INNER - 76, elide = "right", font_size = theme.size.small,
          color = kit.ink("lo"),
          text = function()
            local r = M.request:get()
            return r and ("as " .. tostring(r.user)) or ""
          end,
        },
      },
    },
    kit.text {
      id = "polkit-message", width = INNER, wrap = true, max_lines = 4, line_height = 1.35,
      text = function() local r = M.request:get() return r and r.message or "" end,
    },
    kit.label {
      width = INNER, elide = "middle", font_size = theme.size.small - 2,
      color = kit.stroke("mark"),
      text = function() local r = M.request:get() return r and r.action or "" end,
    },
    ui.Item {width=INNER,height=FIELD_H,field,
      kit.card {id="polkit-status",anchors={fill=true},radius=16,
        visible=function() return not M.can_answer() end,
        color=function() return C.primaryContainer end,
        kit.icon(function()
          if M.phase:get()=="done" then return "check_circle" end
          if M.phase:get()=="refused" then return "block" end
          return face() and "face" or "hourglass_top"
        end,24,function() return C.onPrimaryContainer end,{x=16,anchors={vertical_center=true}}),
        kit.text {id="polkit-status-text",x=52,width=INNER-68,anchors={vertical_center=true},
          font_size=theme.size.small,wrap=true,max_lines=2,color=function() return C.onPrimaryContainer end,
          text=function()
            if M.phase:get()=="done" then return "Authentication successful" end
            if M.phase:get()=="refused" then return "Authentication ended" end
            return face() and "Looking for your face…" or "Checking authentication…"
          end},
      },
    },
    kit.text {
      id = "polkit-info", width = INNER, wrap = true, max_lines = 2, font_size = theme.size.small,
      visible = function() return M.info:get() ~= "" end,
      color = function()
        local p = M.phase:get()
        return (p == "wrong" or p == "refused") and kit.signal("alert")() or kit.ink("lo")()
      end,
      text = function() return M.info:get() end,
    },
    ui.Item {
      width = INNER, height = 40,
      ui.Row {
        anchors = { right = true }, gap = 8,
        button("polkit-cancel",function() return final() and "Close" or "Cancel" end,false,
          function() if final() then M.dismiss() else M.cancel() end end),
        button("polkit-ok", "Authenticate", true, function() M.submit() end),
      },
    },
  }

  local content = ui.Item {
    id = "polkit",
    anchors = { fill = true },
    column,
  }

  if theme.motion.auth_result then
    theme.motion.auth_result(content,"polkit",{active=function() return M.opened:get() end,
      read=function() return M.phase:get() end})
  end
  return {content=content,width=W,edge="top",
    height=function() return (column.layout_height or 330)+2*PAD end,
    shake=function()
      shake:set(1)
      morf.timer(70,function() shake:set(0) end,false)
    end}
end
return V
