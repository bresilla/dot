local hexe = require("hexe")

local layout = hexe.layout("default", {
  enabled = true,
  tabs = {
    hexe.tab("main", {
      enabled = true,
      root = hexe.pane({ cwd = "." }),
    }),
  },
  floats = {
    hexe.float("opencode", {
      key = "1",
      enabled = true,
      title = "opencode",
      attrs = { per_cwd = true, inherit_env = true, exclusive = true },
      command = "opencode",
    }),
    hexe.float("claude", {
      key = "2",
      enabled = true,
      attrs = { per_cwd = true, inherit_env = true, exclusive = true },
      title = "claude",
      command = "bun x --package @anthropic-ai/claude-code claude",
    }),
    hexe.float("codex", {
      key = "3",
      enabled = true,
      attrs = { per_cwd = true, inherit_env = true, exclusive = true },
      title = "codex",
      command = "codex",
    }),
    hexe.float("explorer", {
      key = "p",
      enabled = true,
      title = "explorer",
      position = { x = 100, y = 50 },
      size = { width = 40, height = 80 },
      attrs = { global = false, navigatable = true, inherit_env = true },
    }),
    hexe.float("sandbox", {
      key = "0",
      enabled = true,
      title = "sandbox",
      isolation = {
        profile = "sandbox",
        memory = "512M",
        pids = 100,
        cpu = "50000 100000",
      },
    }),
  },
})

return hexe.setup({
  keys = {
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.s }, hexe.action.layout.save()),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.l }, hexe.action.layout.load()),

    hexe.key({ hexe.key.alt, hexe.key["1"] }, hexe.action.float.toggle("1")),
    hexe.key({ hexe.key.alt, hexe.key["2"] }, hexe.action.float.toggle("2")),
    hexe.key({ hexe.key.alt, hexe.key["3"] }, hexe.action.float.toggle("3")),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key["9"] }, hexe.action.float.toggle("p")),
    hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key["0"] }, hexe.action.float.toggle("0")),
  },

  ses = {
    layouts = {
      layout,
    },
  },
})
