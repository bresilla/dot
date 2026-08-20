local hexe = require("hexe")

local function concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    if list then
      for _, item in ipairs(list) do
        table.insert(out, item)
      end
    end
  end
  return out
end

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


local layout_config = dofile(os.getenv("HOME") .. "/.config/hexe/layout.lua")
local layout_keys = layout_config.keys or {}
local layouts = {}

if layout_config.__hexe_type == "layout" then
  layouts = { layout_config }
elseif layout_config.ses and layout_config.ses.layouts then
  layouts = layout_config.ses.layouts
end

return hexe.setup({
  keys = concat(layout_keys, {
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.q }, hexe.action.quit()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.d }, hexe.action.detach()),

    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.z }, hexe.action.pane.disown()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.a }, hexe.action.pane.adopt()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.c }, hexe.action.clipboard.copy()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.v }, hexe.action.clipboard.request()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.n }, hexe.action.system.notify()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.k }, hexe.action.overlay.keycast_toggle()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.o }, hexe.action.pane.select()),

    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.h }, hexe.action.split.horizontal(), { when = focused_split }),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.v }, hexe.action.split.vertical(), { when = focused_split }),

    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.t }, hexe.action.tab.new()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.x }, hexe.action.tab.close()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.dot }, hexe.action.tab.next()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.comma }, hexe.action.tab.prev()),

    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.up }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only }),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.down }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only }),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.left }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only }),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.right }, nil, { when = focused_process_is_editor, mode = hexe.mode.passthrough_only }),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.up }, hexe.action.focus.move("up")),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.down }, hexe.action.focus.move("down")),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.left }, hexe.action.focus.move("left")),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.right }, hexe.action.focus.move("right")),

    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.p }, hexe.action.overlay.sprite_toggle(), { mode = hexe.mode.act_and_consume }),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.shift, hexe.key.p }, hexe.action.overlay.sprite_toggle(), { mode = hexe.mode.act_and_consume }),
  }),

  mux = {
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
  },

  -- The bar is drawn by an external painter (see hexe's docs/regions.md).
  -- hexe says which view to ask for; the painter decides what it looks like.
  -- Started below by `command`, which hexe runs when nothing holds the socket.
  status = {
    enabled = true,
    refresh_ms = 250,
    -- Three zones, each an ordinary painter request for its own selector.
    zones = {
      left   = { view = "status.left" },
      center = { view = "status.center" },
      right  = { view = "status.right" },
    },
    shrink = { "center", "right", "left" },  -- who gives up width first
    -- socket  = nil,   -- nil = $HEXE_PAINTER_SOCKET, then
    --                  --       $XDG_RUNTIME_DIR/hexe/painter.sock
    command = "pixy serve",  -- hexe starts this when nothing is listening
  },

  pop = {
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
  },

  ses = {
    layouts = layouts,
  },
})