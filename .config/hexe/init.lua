local hx = require("hexe")
local section = HEXE_SECTION

-- ============================================================================
-- MUX Configuration (Terminal UI)
-- ============================================================================
if section == nil or section == "mux" then
  -- General MUX settings
  hx.mux.config.setup({
    confirm_on_exit = true,
    confirm_on_detach = true,
    confirm_on_disown = true,
    confirm_on_close = true,
    winpulse_enabled = true,
    winpulse_duration_ms = 500,
    winpulse_brighten_factor = 2.5,
    selection_color = 238,
  })

  -- Keybindings
  hx.mux.keymap.set({
    { key = { hx.key.ctrl, hx.key.alt, hx.key.q }, action = { type = hx.action.mux_quit } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.d }, action = { type = hx.action.mux_detach } },

    { key = { hx.key.ctrl, hx.key.alt, hx.key.z }, action = { type = hx.action.pane_disown } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.a }, action = { type = hx.action.pane_adopt } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.c }, action = { type = hx.action.clipboard_copy } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.v }, action = { type = hx.action.clipboard_request } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.n }, action = { type = hx.action.system_notify } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.k }, action = { type = hx.action.keycast_toggle } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.o }, action = { type = hx.action.pane_select_mode } },

    { key = { hx.key.ctrl, hx.key.alt, hx.key.h }, when = "focus_split", action = { type = hx.action.split_h } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.v }, when = "focus_split", action = { type = hx.action.split_v } },

    { key = { hx.key.ctrl, hx.key.alt, hx.key.t }, action = { type = hx.action.tab_new } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.x }, action = { type = hx.action.tab_close } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.dot }, action = { type = hx.action.tab_next } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.comma }, action = { type = hx.action.tab_prev } },

    -- Focus movement: passthrough to nvim/vim, otherwise do focus_move
    { key = { hx.key.ctrl, hx.key.alt, hx.key.up }, when = { lua = function(ctx) return ctx.fg_process == "nvim" or ctx.fg_process == "vim" end }, mode = hx.mode.passthrough_only },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.down }, when = { lua = function(ctx) return ctx.fg_process == "nvim" or ctx.fg_process == "vim" end }, mode = hx.mode.passthrough_only },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.left }, when = { lua = function(ctx) return ctx.fg_process == "nvim" or ctx.fg_process == "vim" end }, mode = hx.mode.passthrough_only },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.right }, when = { lua = function(ctx) return ctx.fg_process == "nvim" or ctx.fg_process == "vim" end }, mode = hx.mode.passthrough_only },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.up }, action = { type = hx.action.focus_move, dir = "up" } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.down }, action = { type = hx.action.focus_move, dir = "down" } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.left }, action = { type = hx.action.focus_move, dir = "left" } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.right }, action = { type = hx.action.focus_move, dir = "right" } },

    { key = { hx.key.ctrl, hx.key.alt, hx.key["1"] }, action = { type = hx.action.float_toggle, float = "1" } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key["2"] }, action = { type = hx.action.float_toggle, float = "2" } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key["3"] }, action = { type = hx.action.float_toggle, float = "3" } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key["4"] }, action = { type = hx.action.float_toggle, float = "4" } },
    { key = { hx.key.ctrl, hx.key.alt, hx.key["0"] }, action = { type = hx.action.float_toggle, float = "p" } },

    -- Pokemon sprite overlay
    { key = { hx.key.ctrl, hx.key.alt, hx.key.p }, action = { type = hx.action.sprite_toggle }, mode = hx.mode.act_and_consume },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.shift, hx.key.p }, action = { type = hx.action.sprite_toggle }, mode = hx.mode.act_and_consume },
  })

  -- Default float settings
  hx.mux.float.set_defaults({
    size = { width = 80, height = 70 },
    attributes = {
      exclusive = true,
      sticky = true,
      global = true,
      destroy = false,
    },
    color = { active = 1, passive = 237 },
    style = {
      title = {
        name = "title",
        value = function(ctx)
          local t = hexe.segment.title(ctx)
          return {
            { text = " ", style = "bg:0 fg:1" },
            { text = t, style = "bg:1 fg:0" },
            { text = " ", style = "bg:0 fg:1" },
          }
        end,
        position = "bottomright",
      },
    },
  })

  -- Splits configuration
  hx.mux.splits.setup({
    color = { active = 1, passive = 237 },
    separator_v = "│",
    separator_h = "─",
  })

  -- Tab status bar
  hx.mux.tabs.set_status(true)

  -- Tab status segments - Left
  hx.mux.tabs.add_segment("left", {
    name = "time_lua",
    priority = 10,
    value = function(_)
      return {
        { text = " ", style = "bg:237 fg:250" },
        { text = os.date("%H:%M:%S"), style = "bold bg:237 fg:250" },
        { text = " ", style = "bg:237 fg:250" },
      }
    end,
  })

  hx.mux.tabs.add_segment("left", {
    name = "session",
    priority = 30,
    builtin = function(_)
      return hexe.segment.builtin.session({ style = "bg:1 fg:0", prefix = " ", suffix = " " })
    end,
  })

  hx.mux.tabs.add_segment("left", {
    name = "spinner",
    priority = 20,
    builtin = function(ctx)
      if (ctx.shell_running and not ctx.alt_screen) or ctx.adhoc_float then
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
  })

  hx.mux.tabs.add_segment("left", {
    name = "randomdo",
    priority = 200000,
    builtin = function(ctx)
      if (ctx.shell_running and not ctx.alt_screen) or ctx.adhoc_float then
        return hexe.segment.builtin.randomdo({ style = "bg:0 fg:1", suffix = " " })
      end
      return nil
    end,
  })

  -- Tab status segments - Center
  hx.mux.tabs.add_segment("center", {
    name = "tabs",
    priority = 1,
    value = function(ctx)
      return hexe.segment.tabs(ctx)
    end,
    tab_title = "basename",
    active_style = "bg:1 fg:0",
    inactive_style = "bg:237 fg:250",
    separator = " | ",
    separator_style = "fg:7",
  })

  -- Tab status segments - Right
  local rec_opts = {
    scope = "pod",
    out = "/tmp/hexe-active-pod.cast",
    capture_input = false,
  }

  hx.mux.tabs.add_segment("right", {
    name = "rec",
    priority = 11,
    value = function(_)
      local st = hexe.record.status({ scope = "pod" })
      if st and st.active then
        return { { text = " REC ", style = "bg:1 fg:15 bold" } }
      end
      return { { text = " rec ", style = "bg:1 fg:15 bold" } }
    end,
    button = {
      on_left_click = hx.record.toggle(rec_opts),
      on_right_click = hx.record.stop(rec_opts),
      active_when = "test \"$(hexe record status --scope pod 2>/dev/null)\" = 1",
      left_style = "bg:2 fg:0 bold",
      middle_style = "bg:3 fg:0 bold",
      right_style = "bg:1 fg:15 bold",
      inverse_on_hover = true,
    },
  })

  hx.mux.tabs.add_segment("right", {
    name = "virt",
    priority = 12,
    value = function(_)
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
        return { { text = " >> ", style = "bg:5 fg:0" } }
      end
      return { { text = " :: ", style = "bg:5 fg:0" } }
    end,
  })

  hx.mux.tabs.add_segment("right", {
    name = "cpu",
    priority = 15,
    builtin = function(_)
      return hx.segment.builtin.cpu({ style = "bg:1 fg:0", prefix = " ", suffix = " " })
    end,
  })

  hx.mux.tabs.add_segment("right", {
    name = "mem",
    priority = 20,
    builtin = function(_)
      return hx.segment.builtin.mem({ style = "bg:237 fg:250", prefix = " ", suffix = " " })
    end,
  })

  hx.mux.tabs.add_segment("right", {
    name = "battery",
    priority = 40,
    builtin = function(_)
      return hx.segment.builtin.battery({ style = "bg:237 fg:250", suffix = " " })
    end,
  })

  hx.mux.tabs.add_segment("right", {
    name = "jobs_lua",
    priority = 200,
    builtin = function(_)
      return hx.segment.builtin.jobs({ style = "fg:7", prefix = " " })
    end,
  })
end

-- ============================================================================
-- SES Configuration (Session Manager)
-- ============================================================================
if section == nil or section == "ses" then
  -- Define default layout
  hx.ses.layout.define({
    name = "default",
    enabled = true,
    tabs = {
      {
        name = "main",
        enabled = true,
        root = { cwd = "." },
      },
    },
    floats = {
      {
        key = "1",
        enabled = true,
        title = "opencode",
        attributes = { per_cwd = true, inherit_env = true },
        command = "/env/bin/opencode",
      },
      {
        key = "2",
        enabled = true,
        attributes = { per_cwd = true, inherit_env = true },
        title = "opencode",
        command = "/env/bin/opencode",
      },
      {
        key = "3",
        enabled = true,
        attributes = { per_cwd = true, inherit_env = true },
        title = "claude",
        command = "/env/bin/bun x --package @anthropic-ai/claude-code claude",
      },
      {
        key = "p",
        enabled = true,
        title = "scratchpad",
        position = { x = 100, y = 50 },
        size = { width = 40, height = 80 },
        padding = { x = 2, y = 1 },
        attributes = { global = false, navigatable = true, inherit_env = true },
        style = {
          shadow = { color = 236 },
          border = {
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
          },
          title = {
            name = "title",
            value = function(ctx)
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
      {
        key = "0",
        enabled = true,
        title = "sandbox",
        isolation = {
          profile = "sandbox",  -- Full isolation + network allowed
          memory = "512M",
          pids = 100,
          cpu = "50000 100000",  -- 0.5 cores max
        },
      },
    },
  })
end

-- ============================================================================
-- SHP Configuration (Shell Prompt)
-- ============================================================================
if section == nil or section == "shp" then
  hx.shp.prompt.left({
    {
      name = "ssh",
      priority = 60,
      value = "return ctx.env.SSH_CONNECTION and { { text = ' //', style = 'bg:237 italic fg:15' } } or nil",
    },
    {
      name = "hostname",
      priority = 15,
      builtin = function(_)
        return hexe.segment.builtin.hostname({ style = "bg:237 italic fg:15", suffix = " " })
      end,
    },
    {
      name = "distro",
      priority = 10,
      value = [[
        local p = io.popen('/env/dot/.func/shell/distrologo')
        if not p then return nil end
        local raw = p:read('*a') or ''
        p:close()
        local t = raw:match('^%s*(.-)%s*$')
        if not t or t == '' then return nil end
        return { { text = ' ' .. t, style = 'bg:1 fg:0' } }
      ]],
    },
    {
      name = "username",
      priority = 1,
      builtin = function(_)
        return hexe.segment.builtin.username({ style = "bg:1 fg:0", suffix = " " })
      end,
    },
    {
      name = "direnv",
      priority = 25,
      value = "return ctx.env.DIRENV_DIR and { { text = '▓', style = 'bg:1 fg:0' } } or nil",
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
      value = [[
        local tab = ((ctx and ctx.env and ctx.env.TAB) or ''):match('^%s*(.-)%s*$')
        if tab ~= '' and tab ~= '.reset-prompt' and tab ~= 'reset-prompt' then
          return nil
        end
        local p = io.popen('tab -l 2> /dev/null | wc -l')
        if not p then return nil end
        local raw = p:read('*a') or ''
        p:close()
        local total = tonumber((raw:match('^%s*(.-)%s*$')) or '0') or 0
        local n = total - 1
        if n <= 0 then return nil end
        return {
          { text = '|', style = 'fg:7' },
          { text = ' ' .. tostring(n) .. ' ', style = 'bg:237 italic fg:15' },
        }
      ]],
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
      value = [[
        local p = io.popen('systemd-detect-virt 2>/dev/null')
        if not p then return nil end
        local out = p:read('*a') or ''
        p:close()
        local virt = out:match('^%s*(.-)%s*$')
        if virt == '' or virt == 'none' then return nil end
        if virt == 'lxc' then
          return {
            { text = ' ', style = 'bg:0 fg:0' },
            { text = ' >> ', style = 'bg:5 fg:0' },
          }
        end
        return {
          { text = ' ', style = 'bg:0 fg:0' },
          { text = ' :: ', style = 'bg:5 fg:0' },
        }
      ]],
    },
    {
      name = "separator",
      priority = 20,
      value = "return { { text = '|', style = 'fg:7' } }",
    },
  })

  hx.shp.prompt.right({
    {
      name = "pod_name",
      priority = 1,
      builtin = function(_)
        return hexe.segment.builtin.pod_name({ style = "bg:5 fg:0", prefix = "| ", suffix = " ||" })
      end,
    },
    {
      name = "git_branch",
      priority = 4,
      builtin = function(_)
        return hexe.segment.builtin.git_branch({ style = "bg:1 fg:0", prefix = "  ", suffix = " " })
      end,
    },
    {
      name = "git_status",
      priority = 5,
      builtin = function(_)
        return hexe.segment.builtin.git_status({ style = "bg:1 fg:0", suffix = " " })
      end,
    },
    {
      name = "directory",
      priority = 2,
      builtin = function(_)
        return hexe.segment.builtin.directory({ style = "bg:237 fg:15", suffix = " " })
      end,
    },
  })
end

-- ============================================================================
-- POP Configuration (Popups & Overlays)
-- ============================================================================
if section == nil or section == "pop" then
  -- Notification styles
  hx.pop.notify.setup({
    carrier = {
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
  })

  -- Confirmation dialog styles
  hx.pop.confirm.setup({
    carrier = {
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
  })

  -- Choose dialog styles
  hx.pop.choose.setup({
    carrier = {
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
  })

  -- Widget configurations
  hx.pop.widgets.pokemon({
    enabled = false,
    position = "topright",
    shiny_chance = 0.01,
  })

  hx.pop.widgets.keycast({
    enabled = false,
    position = "bottomright",
    duration_ms = 2000,
    max_entries = 8,
    grouping_timeout_ms = 700,
  })

  hx.pop.widgets.digits({
    enabled = false,
    position = "topleft",
    size = "small",
  })
end
