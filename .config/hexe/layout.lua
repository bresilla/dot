local hexe = require("hexe")

-- add_env/add_path below take effect when a float's process is SPAWNED, so an
-- already-running float keeps its old environment until it is recreated.

-- Common env for the AI floats; env(extra) returns it plus that float's own
-- keys (extra wins, so a float can override a common value too).
-- OSLO_ALLHIST is off: an agent's `sh -c` string is its own wrapper, not a command
-- anybody typed, so recording it fills the history with unrecallable lines.
local float_env = { HEXE_FLOAT = 1  }

local function env(extra)
  local t = {}
  for k, v in pairs(float_env) do t[k] = v end
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end

-- Prepended to PATH, in order, ahead of whatever the float inherits.
--
-- No "~" expansion: hexe passes these through as written, so they have to be absolute by the time
-- they arrive. Built from $HOME rather than spelled out, because a config that ships is read on
-- machines with a different one.
local home = os.getenv("HOME") or ""
local float_path = {
  home .. "/.local/bin",
  home .. "/.local/share/shell",
}

hexe.layout("default", {
  enabled = true,
  tabs = {
    hexe.tab("main", {
      enabled = true,
      root = hexe.pane({ cwd = "." }),
    }),
  },
  floats = {
    hexe.float("pi", {
      key = "1",
      enabled = true,
      title = "pi",
      attrs = { per_cwd = true, inherit_env = true, exclusive = true },
      command = "bun x --package @earendil-works/pi-coding-agent pi",
      add_env = env({ OSLO_PROFILE = "pi", HEXE_FLOAT_NAME = "pi" }),
      add_path = float_path,
    }),
    hexe.float("claude", {
      key = "2",
      enabled = true,
      attrs = { per_cwd = true, inherit_env = true, exclusive = true },
      title = "claude",
      command = "bun x --package @anthropic-ai/claude-code claude",
      add_env = env({ HEXE_FLOAT_NAME = "claude" }),
      add_path = float_path,
    }),
    hexe.float("codex", {
      key = "3",
      enabled = true,
      attrs = { per_cwd = true, inherit_env = true, exclusive = true },
      title = "codex",
      command = "codex",
      add_env = env({ HEXE_FLOAT_NAME = "codex" }),
      add_path = float_path,
    }),
    hexe.float("antigravity", {
      key = "4",
      enabled = true,
      attrs = { per_cwd = true, inherit_env = true, exclusive = true },
      title = "antigravity",
      command = "agy",
      add_env = env({ HEXE_FLOAT_NAME = "antigravity" }),
      add_path = float_path,
    }),
    hexe.float("explorer", {
      key = "p",
      enabled = true,
      title = "explorer",
      position = { x = 100, y = 50 },
      size = { width = 40, height = 80 },
      attrs = { global = false, navigatable = true, inherit_env = true },
      add_env = { HEXE_FLOAT = 1, HEXE_FLOAT_NAME = "explorer" },
      add_path = float_path,
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

hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.s }, hexe.action.layout.save())
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key.l }, hexe.action.layout.load())

hexe.key({ hexe.key.alt, hexe.key["1"] }, hexe.action.float.toggle("1"))
hexe.key({ hexe.key.alt, hexe.key["2"] }, hexe.action.float.toggle("2"))
hexe.key({ hexe.key.alt, hexe.key["3"] }, hexe.action.float.toggle("3"))
hexe.key({ hexe.key.alt, hexe.key["4"] }, hexe.action.float.toggle("4"))

hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key["9"] }, hexe.action.float.toggle("p"))
hexe.key({ hexe.key.ctrl, hexe.key.alt, hexe.key["0"] }, hexe.action.float.toggle("0"))
