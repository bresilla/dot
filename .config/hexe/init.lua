local hexe = require("hexe")


-- Conditions and actions are plain Lua over live state. The callback argument
-- `ctx` is the query API (also `hexe.live` outside a callback): ctx.pane(),
-- ctx.panes(), ctx.floats{}, ctx.splits{}, ctx.tabs(), ctx.session(), ctx.ui(),
-- ctx.count(), ctx.env(). All read the frontend as it is when the key is pressed.

local function focused_process_is_editor(ctx)
  local p = ctx.pane()
  return p ~= nil and (p.process == "nvim" or p.process == "vim")
end

local function focused_split(ctx)
  local p = ctx.pane()
  return p ~= nil and p.is_split
end

-- Nothing here needed a new Zig-side token to become expressible:
--   local function no_floats_shown(ctx) return ctx.count("visible_floats") == 0 end
--   local function crowded(ctx)         return #ctx.floats{ visible = true } > 2 end
--   local function deep_in_repo(ctx)    return (ctx.pane().cwd or ""):find("/src/") ~= nil end
--   local function last_failed(ctx)     return (ctx.pane().exit_status or 0) ~= 0 end

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

---------------------------------------------------------------------------- settings

-- Nested data stays nested: what changed is how a setting is delivered, not
-- the shape of its value.

hexe.mux = {
  confirm = {
    exit = true,
    detach = true,
    disown = true,
    close = true,
  },

  selection_color = 238,

  mouse = {
    selection_override = { "ctrl", "alt" },
  },

  floats = {
    defaults = {
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
    },

    adhoc = {
      size = { width = 82, height = 72 },
      color = { active = 4, passive = 237 },
    },

    match = {
      ["^container$"] = {
        color = { active = 1, passive = 237 },
        padding = { x = 2, y = 1 },
        style = {
          shadow = { color = 236 },
          border = border,
          position = "topright",
        },
      },
    },
  },

  splits = {
    color = { active = 1, passive = 237 },
    chars = {
      vertical = "│",
      horizontal = "─",
    },
  },
}


  -- The bar, the pane and float titles and the sprite overlay are drawn by an
  -- external painter over a small JSON protocol -- hexe draws no chrome of its
  -- own. See docs/regions.md for the wire format, and contrib/painter.py for a
  -- working one you can copy:
  --
  --     python3 contrib/painter.py &
  --
hexe.status = {
  enabled = true,
  -- Three regions, not one.
  --
  -- A single flat `view = "status"` makes the painter fake alignment with
  -- spacers, and two equal spacers put the middle at `left + slack/2` -- so the
  -- pane list slid sideways by half of every change in the clock or the
  -- spinner. Zones let hexe place them: the centre is anchored to the bar and a
  -- neighbour changing width cannot move it.
  zones = {
    left   = { view = "status.left" },
    center = { view = "status.center" },
    right  = { view = "status.right" },
  },
  shrink = { "right", "left", "center" },
  refresh_ms = 250,
  -- socket  = nil,   -- nil = $HEXE_PAINTER_SOCKET, then
  --                  --       $XDG_RUNTIME_DIR/hexe/painter.sock
  -- command = nil,   -- optional: hexe starts this if nothing is listening
}


hexe.pop = {
  notify = {
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
  },

  confirm = {
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
  },

  choose = {
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
  },

  widgets = {
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
  },
}
