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
    { key = { hx.key.ctrl, hx.key.alt, hx.key.up }, when = { any = {"fg:nvim", "fg:vim"} }, mode = hx.mode.passthrough_only },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.down }, when = { any = {"fg:nvim", "fg:vim"} }, mode = hx.mode.passthrough_only },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.left }, when = { any = {"fg:nvim", "fg:vim"} }, mode = hx.mode.passthrough_only },
    { key = { hx.key.ctrl, hx.key.alt, hx.key.right }, when = { any = {"fg:nvim", "fg:vim"} }, mode = hx.mode.passthrough_only },
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
        position = "bottomright",
        outputs = {
          { style = "bg:0 fg:1", format = "" },
          { style = "bg:1 fg:0", format = " $output " },
          { style = "bg:0 fg:1", format = "" },
        },
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
    name = "time",
    priority = 10,
    outputs = {
      { style = "bg:237 fg:250", format = " " },
      { style = "bold bg:237 fg:250", format = "$output" },
      { style = "bg:237 fg:250", format = " " },
      { style = "fg:237 bg:1", format = "" },
    },
  })

  hx.mux.tabs.add_segment("left", {
    name = "session",
    priority = 30,
    outputs = {
      { style = "bg:1 fg:0", format = " $output " },
      { style = "fg:1", format = "" },
    },
  })

  hx.mux.tabs.add_segment("left", {
    name = "spinner",
    priority = 20,
    when = {
      any = {
        { all = { "process_running", "not_alt_screen" } },
        "adhoc_float",
      },
    },
    spinner = {
      kind = "knight_rider",
      width = 10,
      step = 40,
      hold = 20,
      colors = { 243, 242, 241, 240, 239, 238, 237, 236 },
      bg = 0,
    },
    outputs = {
      { format = " $output " },
    },
  })

  hx.mux.tabs.add_segment("left", {
    name = "randomdo",
    priority = 200000,
    when = {
      any = {
        { all = { "process_running", "not_alt_screen" } },
        "adhoc_float",
      },
    },
    outputs = {
      { style = "bg:0 fg:1", format = "$output " },
    },
  })

  -- Tab status segments - Center
  hx.mux.tabs.add_segment("center", {
    name = "tabs",
    priority = 1,
    tab_title = "basename",
    active_style = "bg:1 fg:0",
    inactive_style = "bg:237 fg:250",
    separator = " | ",
    separator_style = "fg:7",
  })

  -- Tab status segments - Right
  hx.mux.tabs.add_segment("right", {
    name = "cpu",
    priority = 15,
    outputs = {
      { style = "bg:1 fg:0", format = " $output " },
      { style = "fg:1 bg:237", format = "" },
    },
  })

  hx.mux.tabs.add_segment("right", {
    name = "mem",
    priority = 20,
    outputs = {
      { style = "bg:237 fg:250", format = " $output " },
    },
  })

  hx.mux.tabs.add_segment("right", {
    name = "battery",
    priority = 40,
    outputs = {
      { style = "bg:237 fg:250", format = "$output " },
    },
  })

  hx.mux.tabs.add_segment("right", {
    name = "jobs",
    priority = 200,
    outputs = {
      { style = "fg:7", format = " $output" },
    },
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
        attributes = { per_cwd = true },
        command = "/env/bin/opencode",
      },
      {
        key = "2",
        enabled = true,
        attributes = { per_cwd = true },
        title = "opencode",
        command = "/env/bin/opencode",
      },
      {
        key = "3",
        enabled = true,
        attributes = { per_cwd = true },
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
        attributes = { global = false, navigatable = true },
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
            position = "topright",
            outputs = {
              { style = "bg:0 fg:1", format = "" },
              { style = "bg:1 fg:0", format = " $output " },
              { style = "bg:0 fg:1", format = "" },
            },
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
      command = "echo //",
      when = { bash = "[[ -n $SSH_CONNECTION ]]" },
      outputs = {
        { style = "bg:237 italic fg:15", format = " $output" },
      },
    },
    {
      name = "hostname",
      priority = 15,
      outputs = {
        { style = "bg:237 italic fg:15", format = "$output " },
      },
    },
    {
      name = "distro",
      priority = 10,
      command = "/env/dot/.func/shell/distrologo",
      when = { bash = "true" },
      outputs = {
        { style = "bg:1 fg:0", format = " $output" },
      },
    },
    {
      name = "username",
      priority = 1,
      outputs = {
        { style = "bg:1 fg:0", format = "$output " },
      },
    },
    {
      name = "direnv",
      priority = 25,
      command = "echo ▓",
      when = { bash = "[[ -n $DIRENV_DIR ]]" },
      outputs = {
        { style = "bg:1 fg:0", format = "$output" },
      },
    },
    {
      name = "sudo",
      priority = 6,
      outputs = {
        { style = "bold bg:240 fg:171", format = " ROOT " },
      },
    },
    {
      name = "tab",
      priority = 30,
      command = "echo $TAB | tr -d '/'",
      when = { bash = "[[ -n $TAB && $TAB != '.reset-prompt' && $TAB != 'reset-prompt' ]]" },
      outputs = {
        { style = "fg:7", format = "|" },
        { style = "bg:6 italic fg:0", format = " t: $output " },
      },
    },
    {
      name = "tab2",
      priority = 35,
      command = "echo $(( $(tab -l 2> /dev/null | wc -l) - 1 ))",
      when = { bash = "[[ ! -n $TAB ]] && [[ $(( $(tab -l 2> /dev/null | wc -l) - 1 )) -gt 0 ]]" },
      outputs = {
        { style = "fg:7", format = "|" },
        { style = "bg:237 italic fg:15", format = " $output " },
      },
    },
    {
      name = "status",
      priority = 3,
      outputs = {
        { style = "bg:0 fg:9", format = " $output " },
      },
    },
    {
      name = "container",
      priority = 50,
      command = "/env/dot/.func/shell/incontainer",
      when = { bash = "[[ $(systemd-detect-virt) != 'none' ]]" },
      outputs = {
        { style = "bg:0 fg:0", format = " " },
        { style = "bg:5 fg:0", format = "$output" },
      },
    },
    {
      name = "separator",
      priority = 20,
      outputs = {
        { style = "fg:7", format = "|" },
      },
    },
  })

  hx.shp.prompt.right({
    {
      name = "pod_name",
      priority = 1,
      when = { bash = "[[ -n $HEXE_POD_NAME ]]" },
      outputs = {
        { style = "fg:7", format = "|" },
        { style = "bg:5 fg:0", format = " $output " },
        { style = "fg:7", format = "||" },
      },
    },
    {
      name = "separator",
      priority = 2,
      when = { bash = "[[ -n $HEXE_POD_NAME ]]" },
      outputs = {
        { style = "fg:7", format = "|" },
      },
    },
    {
      name = "git_branch",
      priority = 4,
      outputs = {
        { style = "bg:1 fg:0", format = "  " },
        { style = "bg:1 fg:0", format = "$output " },
      },
    },
    {
      name = "git_status",
      priority = 5,
      outputs = {
        { style = "bg:1 fg:0", format = "$output " },
      },
    },
    {
      name = "directory",
      priority = 2,
      outputs = {
        { style = "bg:237 fg:15", format = "$output " },
      },
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
