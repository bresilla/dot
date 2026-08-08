-- oslo configuration. Lua, and the only config file the shell reads.

-- No version banner or exit hint at startup.
oslo.misc.welcome = false

-- pywal's palette, which .zshrc sends with
--   [ -f ~/.cache/wal/sequences ] && (cat ~/.cache/wal/sequences &)
--
-- 256 `OSC 4` redefinitions plus `OSC 10/11/12` for foreground, background and cursor. It
-- reprograms the *terminal's* colour table, so it is not about oslo's own theme — every escape
-- any program emits afterwards resolves against this palette instead of the terminal's default.
--
-- Without it hexe's prompt is drawn with exactly the same escape codes and looks nothing like it
-- does under zsh, because `48;5;237` means whatever grey the terminal shipped with rather than
-- whatever grey wal chose.
--
-- Written straight to the terminal rather than `cat`ed through a child: the file is 4 KB and this
-- runs once, so a process is not worth it, and the `&` .zshrc uses exists only to keep that
-- process off the startup path.
-- **Only for a session with a terminal.** The config is read by `oslo --help` and by any other
-- non-interactive invocation too, and writing 4 KB of escapes there puts them in whatever pipe
-- was listening — `oslo --help | grep` came back full of `OSC 4`, and oslo's own test for "help is
-- never coloured into a pipe" failed because of it.
--
-- `oslo.fs.read`, not `io.open`: oslo's Lua has no file handles.
if oslo.sys.interactive() then
  local wal = oslo.fs.read(oslo.env.get("HOME") .. "/.cache/wal/sequences")
  if wal then
    io.write(wal)
  end
end

-- vi key bindings while editing a line. Off by default since oslo 0.2.5.
oslo.vi.enabled = true

-- The cursor each mode draws: block / line / underscore, each optionally " blink".
oslo.vi.cursor_insert  = "underscore"
oslo.vi.cursor_normal  = "block"

-- Aliases, shared with every other shell on this machine. `oslo.source` runs the file *in this
-- shell*, so its aliases and functions stick — unlike `oslo.run`, which would run it in a child
-- that then exits with everything it defined.
--
-- `~/.profile` is deliberately absent: a *login* shell reads `/etc/profile` and then `~/.profile`
-- on its own, as every shell does. Sourcing it here as well would run it twice in the session
-- that already had it. Aliases are here rather than there because `.profile` is read once at
-- login and aliases are not exported, so every later shell needs its own copy.
oslo.source(oslo.env.get("HOME") .. "/.config/profile/aliases.sh")

-- `rm` at the prompt moves what it removes to /tmp rather than unlinking it, so a mistake is
-- recoverable until the next reboot. Anything over 100MB is destroyed instead: /tmp is tmpfs
-- here, so a large file would be copied into RAM and stay there.
--
-- None of this reaches a script — `rm` in a `#!/bin/sh` file is POSIX `rm`, and `rm -s` asks for
-- the same at the prompt.
oslo.builtin.rm.to_tmp     = true
oslo.builtin.rm.max_to_tmp = 100
oslo.builtin.rm.trash      = "/tmp"

-- hexe: the prompt, and the shell↔mux link that .zshrc gets from `eval "$(hexe shp init zsh)"`.
-- Its own file because it is a whole subsystem rather than a setting. An absolute path rather
-- than `require`, whose search path depends on the working directory — which for a shell is
-- wherever you happened to open the terminal.
dofile(oslo.env.get("HOME") .. "/.config/oslo/prompt.lua")

-- Alt+<letter> runs `_<letter>`, the same 26 shortcuts .zshrc binds with
--   for key in {a..z}; do bindkey -s "^[${key}" " _${key}\n"; done
-- The text is inserted at the cursor and submitted, which is what zsh's trailing \n does. The
-- leading space keeps it out of the history, as it does there.
for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
  oslo.keys["alt-" .. c] = function(line)
    local at = line.cursor
    return {
      text = line.text:sub(1, at) .. " _" .. c .. line.text:sub(at + 1),
      submit = true,
    }
  end
end

-- Classic `direnv` used to be handed over to the real one from here. It is not any more.
--
-- oslo reads `.envrc` itself, against direnv's stdlib reimplemented in Rust, so an `.envrc`
-- project is oslo's like any other: one allow gate, one undo record, one report. What stood here
-- was a hundred lines working around the one sentence that is no longer true — that oslo read
-- `.env.lua` and nothing else — and every one of them was a place for the two to disagree:
--
--   * a feature predicate turning oslo's direnv **off** in any directory with an `.envrc`, which
--     also handed the `direnv` name back to `$PATH` so the hook below could reach the binary;
--   * a `post_change_dir` hook running `env direnv export bash` and sourcing the result, with a
--     note explaining that the predicate and the hook were evaluated in the wrong order relative
--     to each other and had to share a helper to stay in step;
--   * a `$PATH` walk to find out whether direnv was installed at all, because turning oslo's own
--     off on a machine without it left directories with nothing.
--
-- All of that was the cost of not reading the file. See `oslo.direnv` and `direnv --help`.

-- What a directory environment says when it loads, unloads, or refuses to.
--
-- oslo draws its own block for this and it is a perfectly good one — but it answers "what
-- *changed*", and in a shell that already inherited the nix dev shell from its parent the answer
-- is "nothing", which reads as though the file did not run. Returning `true` from `on-report`
-- means we drew it and oslo prints nothing of its own.
--
-- **This one may read the environment.** `direnv` and `slow` fire from the read loop with nothing
-- locked; `chain`, `job` and `time` fire from inside a builtin and would raise on `oslo.env.get`.
-- That is why the values below can be looked up at all.

-- The colours, in one table rather than scattered through the handler — the one place to edit when
-- the palette changes. ANSI names rather than hex: these follow whatever wal loaded at the top of
-- this file, which is the whole reason the palette is programmed into the terminal.
local HUE = {
  loaded   = "green",
  left     = "brightblack",
  blocked  = "yellow",
  denied   = "red",
  failed   = "red",
  watched  = "cyan",     -- a variable we print the value of
  added    = "green",
  changed  = "yellow",
  removed  = "red",
  aliases  = "magenta",
  value    = "brightblack",
}

-- The variables worth seeing the *value* of rather than just the name. Everything else is
-- summarised by name, because a nix dev shell brings thirty-five and the list is the information.
local WATCH = { "TOP_HEAD", "PATH" }

-- `~/data/code` rather than the whole path: the front of it is never the interesting part.
local function tilde(path)
  local home = oslo.env.get("HOME")
  if home and home ~= "" and path:sub(1, #home) == home then
    return "~" .. path:sub(#home + 1)
  end
  return path
end

-- `direnv` in colour, then the rest of the headline plain, so the word is the thing your eye lands
-- on and the path is context.
local function head(colour, word, rest)
  return oslo.ui.style("direnv", { fg = colour, bold = true })
    .. " " .. oslo.ui.style(word, { fg = colour })
    .. (rest and (" " .. rest) or "")
end

oslo.on.on_report(function(r)
  if r.kind ~= "direnv" then
    return
  end

  if r.state ~= "loaded" then
    -- One line for the three that are not a load. `blocked` is a security decision, so it says
    -- what to type rather than leaving you to remember — and gets the colour you cannot skim past.
    local line
    if r.state == "unloaded" then
      line = head(HUE.left, "left", tilde(r.owner))
    elseif r.state == "blocked" then
      line = head(HUE.blocked, "blocked", tilde(r.owner) .. "  → "
        .. oslo.ui.style("direnv allow", { fg = HUE.blocked, bold = true }))
    elseif r.state == "denied" then
      line = head(HUE.denied, "denied", tilde(r.owner))
    else
      line = head(HUE.failed, "failed", tilde(r.owner) .. "  " .. tostring(r.problem))
    end
    oslo.ui.block(line):done()
    return true
  end

  local b = oslo.ui.block(head(HUE.loaded, "loaded", tilde(r.owner)))

  -- The named ones with their values, cut at the right edge rather than wrapped: for `$PATH` the
  -- front is what you want to see, and the rest is thirty store paths.
  for _, name in ipairs(WATCH) do
    local value = oslo.env.get(name)
    if value then
      b:row(name, value, {
        overflow    = "ellipsis",
        label_style = HUE.watched,
        style       = HUE.value,
      })
    end
  end

  -- Everything else by name, grouped by what happened to it. `count` is the default: past the edge
  -- of the terminal the number of them is worth more than the next name.
  local by_change = {}
  for _, v in ipairs(r.changed) do
    local skip = false
    for _, watched in ipairs(WATCH) do
      if v.name == watched then skip = true end
    end
    if not skip then
      by_change[v.change] = (by_change[v.change] or "") .. " " .. v.name
    end
  end
  for _, change in ipairs({ "added", "changed", "removed" }) do
    if by_change[change] then
      b:row(change, by_change[change]:sub(2), { label_style = HUE[change] })
    end
  end

  if #r.aliases > 0 then
    local names = ""
    for _, v in ipairs(r.aliases) do names = names .. " " .. v.name end
    b:row("aliases", names:sub(2), { label_style = HUE.aliases, style = HUE.aliases })
  end

  b:done()
  return true
end)
