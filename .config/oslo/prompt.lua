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
-- **`async = true` with a short `timeout_ms`, and the two go together.**
--
-- This used to say `async = false, deliberately`, because the async cache keyed on the
-- *substituted* argv: `--duration=$duration_ms` differs after almost every command, so every
-- lookup missed, the answer was nothing, and the prompt fell back to oslo's own. That is fixed —
-- `external::render` keys on the spec instead ("the last output for *this* prompt"), which is
-- stable across commands, so `--duration` can stay.
--
-- The deadline is the part that actually decides the cost, because the async path still *waits*
-- `timeout_ms` for a fresh answer before falling back to the last one. Measured against a prompt
-- deliberately made to take 150 ms, Enter-to-prompt was:
--
--     async = false, timeout_ms = 400   336 ms
--     async = true,  timeout_ms = 400   338 ms   -- no better: it waits for the fresh one
--     async = true,  timeout_ms = 10     31 ms   -- and still the real prompt, not a fallback
--
-- So 10, not 400. hexe answers in about 33 ms here, which is over the deadline — the trade is
-- that the prompt carries the *previous* command's status whenever hexe overruns, and catches up
-- on the next one. Raise the deadline to trade instant back for fresh.
oslo.prompt.left = {
  command = "hexe",
  args = { "shp", "prompt", "--shell=bash",
           "--status=$status", "--duration=$duration_ms", "--jobs=$jobs",
           "--language=$language", "--vimode=$vimode" },
  timeout_ms = 10,
  async = true,
}

oslo.prompt.right = {
  command = "hexe",
  args = { "shp", "prompt", "--shell=bash", "--right", "--status=$status",
           "--language=$language", "--vimode=$vimode" },
  timeout_ms = 10,
  async = true,
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
---
--- **Written from this process, not by `sh -c 'env -0 > …'`.** That spelling forked a shell and
--- exec'd `env` on *both* `pre_cmd` and `post_cmd`, so every command paid four process starts —
--- about 20 ms — to write a file oslo can already describe. `oslo.env.all()` is the same set
--- (188 names either way here) and `oslo.fs.write` is one `write(2)`.
---
--- The NUL separator is what `env -0` produces and what hexe parses, so the format is unchanged.
local function snapshot()
  local pane = oslo.env.get("HEXE_PANE_UUID")
  if not pane then
    return
  end
  local entries = {}
  for name, value in pairs(oslo.env.all()) do
    entries[#entries + 1] = name .. "=" .. value
  end
  oslo.fs.write("/tmp/hexe-env-" .. pane, table.concat(entries, "\0") .. "\0")
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
