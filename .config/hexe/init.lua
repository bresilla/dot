local hexe = require("hexe")

local function segments(list)
  for i, segment in ipairs(list) do
    list[i] = hexe.segment(segment)
  end
  return list
end

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

local function focused_process_is_editor(ctx)
  local p = ctx.pane(0)
  return p and (p.process_name == "nvim" or p.process_name == "vim")
end

local function focused_split(ctx)
  local p = ctx.pane(0)
  return p and p.focus_split
end

local style_git_branch = "bg:1 fg:0"
local style_prompt_host = "bg:237 italic fg:15"
local style_status_directory = "bg:237 fg:15"
local style_recording_active = "bg:1 fg:15 bold"

local function git_branch(opts)
  opts = opts or {}
  return hexe.segment.git_branch({
    priority = opts.priority or 4,
    style = opts.style or style_git_branch,
    prefix = opts.prefix or " ",
    suffix = opts.suffix or " ",
  })
end

local function git_status(opts)
  opts = opts or {}
  return hexe.segment.git_status({
    priority = opts.priority or 5,
    style = opts.style or style_git_branch,
    prefix = opts.prefix or " ",
    suffix = opts.suffix or " ",
  })
end

local function session_segment(opts)
  opts = opts or {}
  return hexe.segment.session({
    priority = opts.priority or 30,
    style = opts.style or style_git_branch,
    prefix = opts.prefix or { output = "| " },
    suffix = opts.suffix or { output = " |" },
  })
end

local function battery_segment(opts)
  opts = opts or {}
  return hexe.segment.battery({
    priority = opts.priority or 40,
    style = opts.style or "bg:237 fg:250",
    suffix = opts.suffix or " ",
  })
end

local function pod_name_segment(opts)
  opts = opts or {}
  return hexe.segment.pod_name({
    priority = opts.priority or 1,
    style = opts.style or "bg:5 fg:0",
    prefix = opts.prefix or "| ",
    suffix = opts.suffix or " |",
  })
end

local function directory_segment(opts)
  opts = opts or {}
  return hexe.segment.directory({
    priority = opts.priority or 2,
    style = opts.style or style_status_directory,
    suffix = opts.suffix or " ",
  })
end

local function fish_style_truncate(path)
  if not path or path == "" then return "/" end

  local home = os and os.getenv("HOME") or ""
  local p = path
  if home and home ~= "" and p:sub(1, home:len()) == home then
    p = "~" .. p:sub(home:len() + 1)
  end

  local starts_with_tilde = p:sub(1, 1) == "~"
  local starts_with_slash = p:sub(1, 1) == "/"
  local base = p
  if starts_with_tilde then
    base = p:sub(2)
  elseif starts_with_slash then
    base = p:sub(2)
  end

  local components = {}
  for comp in base:gmatch("[^/]+") do
    table.insert(components, comp)
  end

  if #components == 0 then
    return p:sub(1, 1)
  end

  local result = {}
  for i, comp in ipairs(components) do
    if i < #components then
      if comp:sub(1, 1) == "." and comp:len() > 1 then
        table.insert(result, "." .. comp:sub(2, 2))
      else
        table.insert(result, comp:sub(1, 1))
      end
    else
      table.insert(result, comp)
    end
  end

  local prefix = ""
  if starts_with_tilde then
    prefix = "~"
  elseif starts_with_slash then
    prefix = "/"
  end

  return prefix .. table.concat(result, "/")
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

local rec_opts = {
  scope = "pod",
  out = "/tmp/hexe-active-pod.cast",
  capture_input = false,
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
  theme = hexe.theme({
    colors = {
      bg = 237,
      fg = 250,
      accent = 1,
      good = 2,
      warn = 3,
    },

    styles = {
      ["status.active"] = "bg:1 fg:0 bold",
      ["status.inactive"] = "bg:237 fg:250",
      ["status.directory"] = "bg:237 fg:15",
      ["recording.active"] = "bg:1 fg:15 bold",
      ["prompt.host"] = "bg:237 italic fg:15",
      ["git.branch"] = "bg:1 fg:0",
    },

    chars = {
      split_vertical = "│",
      split_horizontal = "─",
    },
  }),

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
          title = {
            name = "title",
            render = function(ctx)
              local t = hexe.segment.title(ctx)
              return {
                { text = " ", style = "bg:1 fg:1" },
                { text = t, style = "bg:1 fg:0" },
                { text = " ", style = "bg:1 fg:1" },
              }
            end,
            position = "bottomright",
          },
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
            title = {
              name = "title",
              render = function(ctx)
                local t = hexe.segment.title(ctx)
                return {
                  { text = " ", style = "bg:0 fg:1" },
                  { text = t, style = "bg:1 fg:0" },
                  { text = " ", style = "bg:0 fg:1" },
                }
              end,
              position = "topright",
            },
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

  status = {
    enabled = true,

    left = segments({
      {
        name = "time_lua",
        priority = 10,
        render = function(_)
          return {
            { text = " ", style = "bg:237 fg:250" },
            { text = os.date("%H:%M:%S"), style = "bold bg:237 fg:250" },
            { text = " ", style = "bg:237 fg:250" },
          }
        end,
      },
      session_segment(),
      {
        name = "spinner",
        priority = 20,
        builtin = function(ctx)
          local p = ctx.pane(0)
          if p and ((p.shell_running and not p.alt_screen) or p.adhoc_float) then
            return hexe.segment.builtin.spinner({
              kind = "knight_rider",
              width = 10,
              step = 40,
              hold = 20,
              colors = { 243, 242, 241, 240, 239, 238, 237, 236 },
              bg = 0,
              prefix = " ",
              suffix = " ",
            })
          end
          return nil
        end,
      },
      {
        name = "randomdo",
        priority = 200000,
        builtin = function(ctx)
          local p = ctx.pane(0)
          if p and ((p.shell_running and not p.alt_screen) or p.adhoc_float) then
            return hexe.segment.builtin.randomdo({ style = "bg:0 fg:1", suffix = " " })
          end
          return nil
        end,
      },
    }),

    center = segments({
      {
        name = "tabs",
        priority = 1,
        render = function(ctx)
          return hexe.segment.tabs(ctx)
        end,
        tab_title = "basename",
        active_style = style_git_branch,
        inactive_style = "bg:237 fg:250",
        separator = " | ",
        separator_style = "fg:7",
      },
    }),

    right = segments({
      {
        name = "rec",
        priority = 11,
        render = function(_)
          local st = hexe.status.recording(rec_opts.scope)
          if st and st.active then
            return { { text = " REC ", style = style_recording_active } }
          end
          return { { text = " rec ", style = style_recording_active } }
        end,
        button = {
          on_left_click = function(ctx)
            local rec = hexe.record.active(ctx, rec_opts)
            if not rec then return nil end
            return rec.switch()
          end,
          on_right_click = function(_)
            return hexe.record.stop({ scope = rec_opts.scope })
          end,
          active_when = function(_)
            local st = hexe.status.recording(rec_opts.scope)
            return st and st.active == true
          end,
          left_style = "bg:2 fg:0 bold",
          middle_style = "bg:3 fg:0 bold",
          right_style = style_recording_active,
          inverse_on_hover = true,
        },
      },
      battery_segment(),
      {
        name = "directory",
        priority = 50,
        render = function(ctx)
          local cwd = ctx and ctx.cwd and ctx.cwd ~= "" and ctx.cwd or nil
          if not cwd then
            cwd = os and os.getenv and os.getenv("PWD") or nil
          end
          if not cwd and ctx and ctx.pane then
            local p = ctx.pane(0)
            if p and p.cwd and p.cwd ~= "" then
              cwd = p.cwd
            end
          end
          if cwd and cwd ~= "" then
            local truncated = fish_style_truncate(cwd)
            return {
              { text = " " .. truncated, style = style_status_directory },
              { text = " ", style = style_status_directory },
            }
          end
          return nil
        end,
      },
    }),
  },

  prompt = {
    left = segments({
      {
        name = "ssh",
        priority = 60,
        render = function(ctx)
          if not ctx.env.SSH_CONNECTION then
            return nil
          end
          return { { text = " //", style = style_prompt_host } }
        end,
      },
      {
        name = "hostname",
        priority = 15,
        builtin = function(_)
          return hexe.segment.builtin.hostname({ style = style_prompt_host, suffix = " " })
        end,
      },
      {
        name = "distro",
        priority = 10,
        render = function(_)
          local p = io.popen("~/.config/profile/functions/shell/distrologo")
          if not p then
            return nil
          end
          local raw = p:read("*a") or ""
          p:close()
          local t = raw:match("^%s*(.-)%s*$")
          if not t or t == "" then
            return nil
          end
          return { { text = " " .. t, style = style_git_branch } }
        end,
      },
      {
        name = "username",
        priority = 1,
        builtin = function(_)
          return hexe.segment.builtin.username({ style = style_git_branch, suffix = " " })
        end,
      },
      {
        name = "direnv",
        priority = 25,
        render = function(ctx)
          if not ctx.env.DIRENV_DIR then
            return nil
          end
          return { { text = "▓", style = style_git_branch } }
        end,
      },
      {
        name = "sudo",
        priority = 6,
        builtin = function(_)
          return hexe.segment.builtin.sudo({ style = "bold bg:240 fg:171" })
        end,
      },
      {
        name = "tab",
        priority = 35,
        render = function(ctx)
          local tab = ((ctx and ctx.env and ctx.env.TAB) or ""):match("^%s*(.-)%s*$")
          if tab ~= "" and tab ~= ".reset-prompt" and tab ~= "reset-prompt" then
            return nil
          end

          local p = io.popen("tab -l 2> /dev/null | wc -l")
          if not p then
            return nil
          end
          local raw = p:read("*a") or ""
          p:close()
          local total = tonumber((raw:match("^%s*(.-)%s*$")) or "0") or 0
          local n = total - 1
          if n <= 0 then
            return nil
          end
          return {
            { text = "|", style = "fg:7" },
            { text = " " .. tostring(n) .. " ", style = style_prompt_host },
          }
        end,
      },
      {
        name = "status",
        priority = 3,
        builtin = function(_)
          return hexe.segment.builtin.status({ style = "bg:0 fg:9", prefix = " ", suffix = " " })
        end,
      },
      {
        name = "container",
        priority = 50,
        render = function(_)
          local p = io.popen("systemd-detect-virt 2>/dev/null")
          if not p then
            return nil
          end
          local out = p:read("*a") or ""
          p:close()
          local virt = out:match("^%s*(.-)%s*$")
          if virt == "" or virt == "none" then
            return nil
          end
          if virt == "lxc" then
            return {
              { text = " ", style = "bg:0 fg:0" },
              { text = " >> ", style = "bg:5 fg:0" },
            }
          end
          return {
            { text = " ", style = "bg:0 fg:0" },
            { text = " :: ", style = "bg:5 fg:0" },
          }
        end,
      },
      {
        name = "separator",
        priority = 20,
        render = function(_)
          return { { text = "|", style = "fg:7" } }
        end,
      },
    }),

    right = segments({
      pod_name_segment(),
      directory_segment(),
      git_branch(),
      git_status(),
    }),
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
