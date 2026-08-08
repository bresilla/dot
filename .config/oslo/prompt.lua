-- hexe, as oslo's prompt and as its shell↔mux link.
--
-- ⚠ REQUIRES A REBUILT HEXE. `--language` and `--vimode` were added to `hexe shp prompt` at the
-- same time as this; hexe's argument parser is strict, so against an older binary they are a hard
-- error, hexe prints nothing, and oslo falls back to its own prompt. If the prompt reverts, that
-- is the reason — `zig build` in ../hexe.
--
-- This is what `eval "$(hexe shp init zsh)"` does in .zshrc, rewritten as configuration rather
-- than as generated shell. It is a better integration than the zsh one, not merely a translation:
-- zsh has to override the `accept-line` ZLE widget and rebind `^D` to intercept `exit`, where
-- oslo has hooks for both moments.
--
-- Split out of config.lua and pulled in with `dofile`. `~/.config/oslo/conf.d/*.lua` would also
-- work and needs no import line — but conf.d is for things a *package* drops in, and this is
-- hand-written, so it belongs where it can be read.

-- ---------------------------------------------------------------------------------------------
-- The prompt
-- ---------------------------------------------------------------------------------------------
--
-- **`--shell=bash`, never `--shell=zsh`.** zsh mode wraps every escape in `%{ %}`, which is zsh
-- telling itself "these bytes occupy no columns". oslo measures visible width itself, so those
-- markers would be printed literally and the layout would be wrong by however many there are.
-- bash and fish modes emit raw ANSI, which is what oslo wants.
--
-- `async` is why this costs nothing: the last prompt hexe produced is drawn immediately and the
-- next one is computed behind it, so spawning a process never sits between a keystroke and the
-- screen. `timeout_ms` bounds the first one, which is the only one that can be waited for.
-- **Written out, not spliced.** `{ table.unpack(base), "--status=…" }` looks tidier and is
-- wrong: in Lua a call that is not the *last* element of a table constructor is truncated to one
-- value. That turned this into `hexe shp --status=…` — `prompt` and `--shell=bash` silently gone —
-- and hexe answered `unrecognized option 'status'`, which points nowhere near the cause.
--
-- **`async = false`, deliberately.** The async path answers with whatever the tool said last time
-- *for these exact arguments* and runs the fresh one behind the prompt. The arguments include
-- `--duration=$duration_ms`, which is different after almost every command — so the lookup misses,
-- the answer is nothing, and oslo falls back to its own prompt. The visible symptom is a prompt
-- that looks untouched with the right side simply gone, which points nowhere near the cause.
--
-- Synchronous costs one `fork`/`exec` per prompt, bounded by `timeout_ms`, and is what .zshrc
-- already pays through `$(hexe shp prompt …)`. If it ever shows up as lag, the fix is to drop
-- `--duration` from the arguments so the key is stable — not to turn `async` back on with it.
oslo.prompt.left = {
  command = "hexe",
  args = { "shp", "prompt", "--shell=bash",
           "--status=$status", "--duration=$duration_ms", "--jobs=$jobs",
           "--language=$language", "--vimode=$vimode" },
  timeout_ms = 400,
  async = false,
}

oslo.prompt.right = {
  command = "hexe",
  args = { "shp", "prompt", "--shell=bash", "--right", "--status=$status",
           "--language=$language", "--vimode=$vimode" },
  timeout_ms = 400,
  async = false,
}

-- ---------------------------------------------------------------------------------------------
-- The shell → mux link
-- ---------------------------------------------------------------------------------------------

--- Whether this shell is running inside a hexe pane. Everything below is a no-op when it is not,
--- so the same config works in a bare terminal.
local function connected()
  return oslo.env.get("HEXE_MUX_SOCKET") ~= nil and oslo.env.get("HEXE_PANE_UUID") ~= nil
end

--- The environment, where hexe can read it — what a new pane is opened with.
local function snapshot()
  local pane = oslo.env.get("HEXE_PANE_UUID")
  if pane then
    oslo.run{ "sh", "-c", "env -0 > /tmp/hexe-env-" .. pane }
  end
end

--- Whether hexe is willing to let this shell go. A pane with something still running says no.
local function may_exit()
  return oslo.run{ "hexe", "shp", "exit-intent", capture = true }.ok
end

local function tell(...)
  oslo.run{ "hexe", "shp", "shell-event", ..., capture = true }
end

-- A command is about to run.
--
-- **This hook can also refuse.** Returning `false` cancels the line, which is how `exit` is
-- intercepted — the job zsh needs an `accept-line` widget override for.
oslo.on.pre_cmd(function(c)
  if not connected() then
    return
  end
  if c.text == "exit" or c.text == "logout" then
    if not may_exit() then
      return false
    end
  end
  snapshot()
  tell("--phase=start", "--running", "--cmd=" .. c.text,
       "--cwd=" .. c.cwd, "--jobs=" .. #oslo.job.list())
end)

-- It finished.
--
-- **`--duration` is sent, which the zsh integration cannot do.** hexe's `shell-event` has accepted
-- it all along (`src/cli/app.zig`, and `ShellEventPayload.duration_ms` stores it), but .zshrc has
-- no timing to give it — zsh's init shells out to `date +%s%3N` twice per command just to compute
-- one, and then does not pass the result. oslo measures it in-process and hands it over.
oslo.on.post_cmd(function(c)
  if not connected() then
    return
  end
  snapshot()
  tell("--phase=end", "--cmd=" .. c.text, "--status=" .. c.status,
       "--duration=" .. c.duration_ms, "--cwd=" .. c.cwd,
       "--jobs=" .. #oslo.job.list())
end)

-- Ctrl-D on an empty line is the other way out, and it never becomes a command — so `pre_cmd`
-- cannot see it. `on_key` runs before the editor acts, and returning `false` swallows the key.
-- This is zsh's `bindkey '^D'` override, without the widget.
oslo.on.key(function(k)
  if k.name == "delete" and k.text == "" and connected() and not may_exit() then
    return false
  end
end)

-- OSC 7 is deliberately absent. hexe's zsh init prints it by hand in `precmd`; oslo emits OSC 7
-- and OSC 133 itself on every prompt and directory change, so doing it here would send it twice.
