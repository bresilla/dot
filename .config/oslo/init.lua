-- oslo configuration. Lua, and the file the shell reads last.
--
-- `require` rather than the `oslo` global, because the shell runs a real VM and this is a real Lua
-- program: the dependency is named at the top, the name is a local the rest of the file closes
-- over, and a reader knows where `oslo` came from without being told. It is the same table either
-- way — `require "oslo" == _G.oslo` — so this is about saying so, not about reaching something the
-- global could not.
local oslo = require "oslo"

-- No version banner or exit hint at startup.
oslo.misc.welcome = false

-- Three Ctrl-C takes the terminal back from a job that will not give it up. The job is *stopped*
-- rather than killed and lands in `jobs`, so `fg`, `bg` and `kill %1` all still work on it, and
-- `exit` asks before leaving one behind.
--
-- Off by default: it costs one helper process per session, which is the only way the shell can see
-- a Ctrl-C at all while a job owns the terminal. It cannot rescue a process wedged in an
-- uninterruptible kernel call — nothing can.
oslo.misc.interrupt_escape = 3

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

-- ---------------------------------------------------------------------------------------------
-- The prompt, painted by pixy
-- ---------------------------------------------------------------------------------------------
--
-- What `prompt.lua` used to ask hexe for. `hexe shp prompt` no longer exists — the subcommand is
-- gone from the binary — so the painter is pixy now, reading ~/.config/pixy/init.lua.
--
-- **Guarded, so this file still works where pixy is not installed.** Setting `oslo.prompt.left`
-- to a command that is not there costs a failed spawn on every prompt and leaves the line blank;
-- unset, oslo draws its own prompt instead. `oslo.fs.stat` answers nil for a path that is not
-- there, and the type check keeps a *directory* named `pixy` on PATH from counting.
--
-- **`--target=ansi`, never a shell-specific target.** The bash and zsh targets wrap escapes in
-- that shell's "these bytes take no columns" markers, and oslo measures visible width itself, so
-- those markers would be printed literally and the layout would be wrong by however many there
-- are. This is the same reason `prompt.lua` passed `--shell=bash` to hexe.
--
-- **Every argument written out.** `{ table.unpack(base), "--set", … }` is shorter and wrong: a
-- call that is not the *last* element of a Lua table constructor is truncated to one value, which
-- silently drops everything before it.
--
-- **Values go through `--set`, not named flags.** pixy has no `--status` or `--vimode`; what a
-- prompt is made of is named by the zones in ~/.config/pixy/init.lua, and Rust holds no
-- vocabulary of its own. A new value needs a segment that reads `ctx.values`, and one more
-- `--set` here.
local function on_path(program)
  for directory in (oslo.env.get("PATH") or ""):gmatch("[^:]+") do
    local found = oslo.fs.stat(directory .. "/" .. program)
    if found and found.type ~= "directory" then
      return true
    end
  end
  return false
end

if on_path("pixy") then
  oslo.prompt.left = {
    command = "pixy",
    args = { "render", "prompt.left", "--target=ansi",
             "--set", "status=$status", "--set", "duration_ms=$duration_ms",
             "--set", "jobs=$jobs", "--set", "language=$language",
             "--set", "vimode=$vimode" },
    timeout_ms = 10,
    async = true,
  }

  oslo.prompt.right = {
    command = "pixy",
    args = { "render", "prompt.right", "--target=ansi",
             "--set", "status=$status", "--set", "language=$language",
             "--set", "vimode=$vimode" },
    timeout_ms = 10,
    async = true,
  }
end

-- Aliases used to be sourced from ~/.config/profile/aliases.sh here. They are in the oslo macro
-- database now — `oslo macros show` — which every shell reads for itself at startup, so there is
-- nothing to source and a change reaches the terminal beside this one before its next prompt.
--
-- `~/.profile` is still deliberately absent: a *login* shell reads `/etc/profile` and then
-- `~/.profile` on its own, as every shell does, and sourcing it here would run it twice.

-- `rm` at the prompt moves what it removes to /tmp rather than unlinking it, so a mistake is
-- recoverable until the next reboot. Anything over 100MB is destroyed instead: /tmp is tmpfs
-- here, so a large file would be copied into RAM and stay there.
--
-- None of this reaches a script — `rm` in a `#!/bin/sh` file is POSIX `rm`, and `rm -s` asks for
-- the same at the prompt.
oslo.builtin.rm.to_tmp     = true
oslo.builtin.rm.max_to_tmp = 100
oslo.builtin.rm.trash      = "/tmp"


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

-- Two shortcuts on keys that mean nothing at an empty prompt: a second space runs `nav`, and Enter
-- on a blank line runs `ls`.
--
-- **`on-key` rather than `oslo.keys`**, because neither of these is a chord — they are ordinary
-- keys that should keep their ordinary meaning everywhere except on an empty line, and a binding
-- would take them away entirely.
--
-- **A pasted space cannot reach this.** A bracketed paste arrives as one event and is inserted
-- whole; only a keystroke goes through the path this hook is on. So pasting `a  b` types two
-- spaces and runs nothing, which is the difference that makes the space shortcut safe to have.
--
-- Double-space needs no memory of the last key: after one space the line *is* one space, so the
-- second is just "space pressed while the line is a single space".
--
-- This runs on every keystroke, so it stays two comparisons and returns nothing the rest of the
-- time — `nil` means the key does what it always did.
-- Enter at a Lua prompt. The default runs a block as soon as it parses, which works on every
-- terminal; `newline` makes Enter always start another line so a block ends only on an empty one.
--
-- Asked of the terminal rather than assumed: Ctrl+Enter does not exist without the kitty keyboard
-- protocol — in the legacy encoding Ctrl-M *is* Enter — so `newline` is only worth having where
-- the modifier is actually reported. `oslo.term` answers what was negotiated at startup; see
-- `oslo.term.all()` for the rest of it.
if oslo.term.kitty_keyboard() then
  oslo.lua.enter = "newline"
end

-- **Shell only.** `k.language` says which prompt the key was pressed at, and both of these are
-- shell shortcuts: `nav` and `la` are commands. Enter on an empty line matters more than it looks —
-- at a Lua prompt that is what ends a multi-line block, so running `la` there made a block
-- impossible to finish.
oslo.on.key(function(k)
  if k.language ~= "sh" then
    return
  end
  if k.name == "char" and k.char == " " and k.text == " " then
    return { text = "nav", submit = true, erase = true }
  end
  if k.name == "enter" and k.text == "" then
    return { text = "la --git-ignore", submit = true }
  end
end)

-- Browse with trek, and in a hexe session browse in a float.
--
-- `nav` stays the builtin — it is the half that only a builtin can do, because a separate process
-- cannot reach into its parent and change the working directory. What it draws is swappable, and
-- this swaps it. Unset `command` and oslo's own browser comes straight back.
--
-- **The float is the whole point of the hexe branch.** Run inline, trek takes the terminal and the
-- shell behind it is gone until you leave. In a float the shell stays on screen, the pane is
-- destroyed on exit, and `hexe mux float` waits for that — so `nav` still reads the answer and
-- `cd`s exactly as it does inline. Nothing about the handback changes.
--
-- `{answer}` is a file in a 0700 directory oslo makes for the one run; trek writes the directory it
-- ended in and oslo goes there. `{dir}` is where to start. They substitute *inside* the argument,
-- which is what carries them through `--command`'s nested line to the trek that finally runs.
--
-- **`--pass-env`** hands the pane this shell's environment, so a float lands in the same nix dev
-- shell and the same `.env.lua` as the terminal it was opened from.
--
-- **`--serve`** leaves a socket behind while trek is up, so hexe or this shell can ask it what is
-- selected — `trek --lua-api` prints the client. That is what previews are built on.
--
-- The float is sized as `w,h` in **percent** — hexe stores `width_percent`/`height_percent`, and
-- the separator is a comma. An `x` between them fails hexe's `parseInt`, which it catches to 0,
-- which means "default" — so a float asked for `70x60` came up 243 columns wide.
--
-- `21,81` is the inline browser's 60x50 cells, measured: percent of the hexe *window*, not of this
-- shell's pane, so `oslo.term.size()` is the wrong number to compute it from. Percentages are also
-- the reason the float survives a terminal resize, which cells would not.
if os.getenv("HEXE_MUX_SOCKET") then
  oslo.builtin.nav.command = {
    "hexe", "mux", "float",
    "--command", "trek --explore --serve --cwd-file {answer} {dir}",
    "--cwd", "{dir}",
    "--title", "trek",
    "--size", "21,81",
    "--pass-env",
  }
else
  oslo.builtin.nav.command = {
    "trek", "--explore", "--cwd-file", "{answer}",
    "--width", "{width}", "--height", "{height}", "{dir}",
  }
end

-- A model of what this shell actually does, learned from the commands that have run here and kept
-- beside the history. `predict` is not in the default source order, so it has to be asked for; it
-- goes first because it answers about *this* shell rather than about every line ever typed.
--
-- One list per prompt: `predict` and `path` are trained on and made of shell, so neither means
-- anything at a Lua prompt. There `completion` is the whole list — the names that exist in the
-- session — which is what makes it behave like an editor rather than like a history.
oslo.suggest.sh_sources  = { "predict", "history", "path" }
oslo.suggest.lua_sources = { "completion" }

-- The correction is drawn after the line as you type — reversed, so it reads as the shell
-- disagreeing rather than as more of your text — and Right takes it when there is no suggestion in
-- the way. F4 is the same thing on a key of its own, for when the cursor is not at the end.
--
-- `oslo.repair` rather than `oslo.predict.repair`: that one asks the model, which can only offer a
-- command already run here, and this asks `$PATH` as well — `lsvlk` is a misspelling of a real
-- program on the first day of a new machine.
--
-- Guarded on it existing, like `c.commands` is below: this file is shared with machines whose oslo
-- may not have it yet, and there the key does nothing rather than raising.
-- **On an empty line it fixes the command that just failed**, which is the `thefuck` case and the
-- one a key on the input line cannot reach: by the time you want it, the line is gone. Both put the
-- result in the editor, so Enter is still yours.
oslo.keys["f4"] = function(line)
  if not oslo.repair then
    return line.text
  end
  if line.text == "" then
    return oslo.repair() or ""
  end
  return oslo.repair(line.text) or line.text
end

-- Classic `direnv` is handed back to the real one, per directory.
--
-- oslo read `.envrc` itself for a while, against direnv's stdlib reimplemented in Rust. That is
-- gone: 1100 lines tracking somebody else's 1.4k lines of bash, so that `use flake` and
-- `layout python` meant here what they mean there, is a standing bet oslo loses eventually. direnv
-- is installed, it is good at this, and the two now divide the directories between them.
--
-- **Three lines, and each one is load-bearing.**
--
--   * `$PROMPT_COMMAND` is direnv's own bash hook. It is evaluated against the live environment
--     before every prompt, which is what makes it load on the way in *and* unload on the way out
--     with nothing of oslo's in the middle.
--   * `oslo.feature.when` turns oslo's builtin — and `.env.lua` reading — on only where one of
--     oslo's own files governs.
--   * `oslo.command.when` shows the real `direnv` binary only where one of direnv's files governs.
--
-- **The `type` guard is not decoration.** Both tools answer to the word `direnv`, and in an
-- `.env.lua` directory oslo's builtin holds it — so an unguarded hook runs `direnv export bash`
-- against the builtin and prints `export: not a direnv command` on every prompt. `type`
-- writes a path for a file and `is a shell builtin` for a builtin, and it respects the mask below,
-- so it is the one question that tells them apart.
--
-- **The `DIRENV_DIFF` clause is not either.** direnv has to be *run from outside* a directory to
-- unload it. Hide the binary the moment you leave and the unload never happens, so the project's
-- variables stay set for the rest of the session.
oslo.env.set("PROMPT_COMMAND", 'type direnv 2>/dev/null | grep -q / && eval "$(direnv export bash)"')

oslo.feature.when("direnv", function(dir)
  return oslo.fs.find_up(".env.lua", dir) ~= nil
end)

oslo.command.when("direnv", function(dir)
  return oslo.fs.find_up(".envrc", dir) ~= nil or oslo.env.get("DIRENV_DIFF") ~= nil
end)

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

oslo.on.report(function(r)
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

-- ---------------------------------------------------------------------------------------------
-- `cat` on a directory means `ls`
-- ---------------------------------------------------------------------------------------------
--
-- `cat` on a directory is never what anybody meant — it is a typo for `ls` or a habit from a
-- shell that autocompleted the wrong thing — and coreutils answers it with `Is a directory`,
-- which is true and useless. This runs what you meant instead, and says so.
--
-- **Registered last, and that is not arbitrary.** Handlers run in the order they were added and
-- the *first* one to answer with anything stops the rest. `prompt.lua`'s `pre_cmd` — the hexe
-- link — returns nothing on an ordinary command, so it runs and falls through to this. Putting
-- this above the `dofile` above would mean a rewritten line never reaches hexe at all.
--
-- `c.commands` is the parsed line rather than its text: `argv[1]` is the command and `argv[2]` is
-- its first word with quoting already resolved, so `cat 'my dir'` is one argument here and not
-- two. It is absent on a line that does not parse, and on a shell older than the field, which is
-- what the first line guards.
oslo.on.pre_cmd(function(c)
  if not c.commands then
    return
  end
  local first = c.commands[1]
  if not (first and first.argv and first.argv[1] == "cat") then
    return
  end
  -- Only a lone argument. `cat a b`, `cat -n x` and `cat x | less` all mean what they say, and a
  -- rewrite that guessed at those would be the surprising kind.
  if #c.commands > 1 or #first.argv ~= 2 then
    return
  end
  local target = first.argv[2]
  local found = oslo.fs.stat(target)
  if found and found.type == "directory" then
    -- Quoted on the way back out: the word arrived with its quoting resolved, so `a dir` is one
    -- argument here and would be two if it were concatenated in raw.
    return "ls " .. oslo.quote(target)
  end
end)

-- ---------------------------------------------------------------------------------------------
-- nix, where a flake is
-- ---------------------------------------------------------------------------------------------
--
-- All of this is behind `oslo.nix`, which exists only in a build with the `nix` feature. Guarded
-- as one block: this file is shared with machines whose oslo is `oslo-minimal`, and there the
-- names below simply never appear rather than raising on the first line.
if oslo.nix then
  -- Completion for the real `nix` binary, from the flake's own outputs — `nix develop .#<TAB>`.
  -- Every other word falls through to oslo's ordinary completion, and so does a named flake:
  -- `nix build nixpkgs#<TAB>` would evaluate the whole of nixpkgs, which is not a thing to do
  -- between a keystroke and the screen.
  oslo.completion.for_command.nix = oslo.nix.complete

  -- `stale` — how old every input of this flake is pinned.
  --
  -- **Rows rather than printed text**, which is the whole point of a tool here: the shell draws
  -- them when a person is looking and passes them on when something else is, so
  --
  --   stale | where 'days > 365'
  --   stale | sort-by days | cols name days
  --
  -- both work without this knowing anything about them. `oslo.nix.inputs` reads `flake.lock` and
  -- evaluates nothing, so this costs one 27 ms call and no nix build.
  oslo.register_tool{
    name     = "stale",
    accepts  = "nothing",
    produces = "rows",
    rows = function(_)
      local found, err = oslo.nix.inputs()
      if not found then
        io.write("stale: " .. tostring(err) .. "\n")
        return {}
      end
      local rows = {}
      for _, i in ipairs(found) do
        rows[#rows + 1] = {
          name   = i.name,
          type   = i.type or "?",
          days   = i.days,
          pinned = os.date("%Y-%m-%d", i.pinned),
        }
      end
      return rows
    end,
  }
end

-- Answer other programs. Every shell, because that is what makes it useful: a session manager
-- asking "what is this pane's environment" wants the shell that is actually there, not the one it
-- happens to have started, and a shell that only sometimes answers is one nothing can rely on.
--
-- **What it costs when nobody asks: a socket file, a descriptor and a thread parked in `accept`.**
-- oslo binds nothing without this line — the default is silent — so this is a decision rather than
-- something inherited, and `oslo.live.stop()` takes it back for one shell.
--
-- **What it can be asked** is `oslo lua-api --verbs`: the working directory, the session id, and the
-- exported environment. Nothing on that surface runs a command, which is why turning it on
-- everywhere is a small decision rather than a large one — a peer can read this shell and change a
-- variable in it, and cannot make it execute anything.
--
-- Reachable only by this user: the socket sits in a 0700 directory under `$XDG_RUNTIME_DIR`, and
-- the server checks the connecting uid with the kernel rather than believing what the peer says.
oslo.live.serve()
