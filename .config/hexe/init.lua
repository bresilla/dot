local hexe = require("hexe")

-- Conditions and actions are plain Lua over live state. `ctx` is the query API
-- (also reachable as `hexe.live` outside a callback): ctx.pane(), ctx.panes(),
-- ctx.floats{}, ctx.splits{}, ctx.tabs(), ctx.session(), ctx.ui(), ctx.count(),
-- ctx.env(). Everything is read at the moment the key is pressed.

local function focused_process_is_editor(ctx)
  local p = ctx.pane()
  return p ~= nil and (p.process == "nvim" or p.process == "vim")
end

local function focused_split(ctx)
  local p = ctx.pane()
  return p ~= nil and p.is_split
end

local border = {
  chars = {
    top_left = "╔",
    top_right = "╗",
    bottom_left = "╚",
    bottom_right = "╝",
    horizontal = "═",
    vertical = "║",
    left_t = "╠",
    right_t = "╣",
    top_t = "╦",
    bottom_t = "╩",
    cross = "╬",
  },
}

-- The layout, loaded for its declarations rather than for a value: the layout
-- and the keys in it register themselves as the file runs.
--
-- `require`, not `dofile`: a required file is loaded once no matter how many
-- times it is named, and running this one twice would register every key and
-- the layout a second time.
require("layout")

---------------------------------------------------------------------------- keys

hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.q }, hexe.action.quit())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.d }, hexe.action.detach())

hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.z }, hexe.action.pane.disown())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.a }, hexe.action.pane.adopt())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.c }, hexe.action.clipboard.copy())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.v }, hexe.action.clipboard.request())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.n }, hexe.action.system.notify())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.k }, hexe.action.overlay.keycast_toggle())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.o }, hexe.action.pane.select())

hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.h }, hexe.action.split.horizontal(), { when = focused_split })
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.v }, hexe.action.split.vertical(), { when = focused_split })

hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.t }, hexe.action.tab.new())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.x }, hexe.action.tab.close())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.dot }, hexe.action.tab.next())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.comma }, hexe.action.tab.prev())

-- The four passthrough guards come first on purpose: a bind is chosen in the
-- order it was registered, so these have to be able to claim the key before the
-- focus-move binds below take it.
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.up }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only })
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.down }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only })
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.left }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only })
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.right }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only })
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.up }, hexe.action.focus.move("up"))
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.down }, hexe.action.focus.move("down"))
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.left }, hexe.action.focus.move("left"))
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.right }, hexe.action.focus.move("right"))

hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.p }, hexe.action.overlay.sprite_toggle(), { mode = hexe.mode.act_and_consume })
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.shift, hexe.key.p }, hexe.action.overlay.sprite_toggle(), { mode = hexe.mode.act_and_consume })

---------------------------------------------------------------------------- the mux

hexe.mux.confirm = { exit = true, detach = true, disown = true, close = true }
hexe.mux.selection_color = 238
hexe.mux.mouse.selection_override = { "ctrl", "alt" }

hexe.mux.floats.defaults = {
  size = { width = 80, height = 70 },
  attrs = {
    exclusive = true,
    sticky = true,
    global = true,
    destroy = false,
  },
  color = { active = 1, passive = 237 },
  style = {
    border = border,
    position = "bottomright",
  },
}

hexe.mux.floats.adhoc = {
  size = { width = 82, height = 72 },
  color = { active = 4, passive = 237 },
}

hexe.mux.floats.match = {
  ["^container$"] = {
    color = { active = 1, passive = 237 },
    padding = { x = 2, y = 1 },
    style = {
      shadow = { color = 236 },
      border = border,
      position = "topright",
    },
  },
}

hexe.mux.splits.color = { active = 1, passive = 237 }
hexe.mux.splits.chars = { vertical = "│", horizontal = "─" }

---------------------------------------------------------------------------- the bar

-- Drawn by an external painter (see hexe's docs/regions.md). hexe says which
-- view to ask for; the painter decides what it looks like. `command` is what
-- hexe runs when nothing holds the socket.
hexe.status.enabled = true
hexe.status.refresh_ms = 250
-- Three zones, each an ordinary painter request for its own selector.
hexe.status.zones = {
  left   = { view = "status.left" },
  center = { view = "status.center" },
  right  = { view = "status.right" },
}
hexe.status.shrink = { "center", "right", "left" }  -- who gives up width first
-- hexe.status.socket stays unset: $HEXE_PAINTER_SOCKET, then
-- $XDG_RUNTIME_DIR/hexe/painter.sock
hexe.status.command = "pixy serve"

---------------------------------------------------------------------------- popups

-- Assigned as written rather than computed from a shared base: this is a tree
-- of plain data, and a helper that assembles it hides what the values are.
hexe.pop.notify = {
  mux = {
    fg = 232,
    bg = 1,
    bold = true,
    padding_x = 3,
    padding_y = 1,
    offset = 3,
    alignment = "center",
    duration_ms = 3000,
  },
  pane = {
    fg = 232,
    bg = 1,
    bold = true,
    padding_x = 3,
    padding_y = 1,
    offset = 2,
    alignment = "center",
    duration_ms = 3000,
  },
}

hexe.pop.confirm = {
  mux = {
    fg = 232,
    bg = 1,
    bold = true,
    padding_x = 3,
    padding_y = 1,
  },
  pane = {
    fg = 232,
    bg = 1,
    bold = true,
    padding_x = 3,
    padding_y = 1,
  },
}

hexe.pop.choose = {
  mux = {
    fg = 232,
    bg = 1,
    highlight_fg = 1,
    highlight_bg = 232,
    visible_count = 10,
  },
  pane = {
    fg = 232,
    bg = 1,
    highlight_fg = 1,
    highlight_bg = 232,
    visible_count = 10,
  },
}

hexe.pop.widgets = {
  pokemon = {
    enabled = false,
    position = "topright",
    shiny_chance = 0.01,
  },
  keycast = {
    enabled = false,
    position = "bottomright",
    duration_ms = 2000,
    max_entries = 8,
    grouping_timeout_ms = 700,
  },
  digits = {
    enabled = false,
    position = "topleft",
    size = "small",
  },
}
