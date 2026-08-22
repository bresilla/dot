# The five rules, with reasoning

The whole style: **assign the settings, register the behaviour, return nothing.** A description
— a plugin, preset or theme — stays a table; it is just handed to something instead of returned.

## 1. Settings are assigned, not declared in a table

```lua
tool.misc.welcome = false
tool.vi.cursor_insert = "underscore"
tool.suggest.sources = { "predict", "history", "path" }

return tool.setup({ settings = { welcome = false } })   -- no
```

A setting the config never mentions is left alone — the environment or a flag decides it. There
is no defaults table to keep in sync, and no way to blank a setting by forgetting to list it.

**Nested data stays nested.** The rule is about how a setting is *delivered*, not about
flattening its value:

```lua
tool.prompt.left = {
  command = "pixy",
  args = { "render", "prompt.left", "--target=ansi" },
  timeout_ms = 10,
  async = true,
}
```

That is rule 1 done right, and it is the answer to "but my settings are a big tree": assign the
tree. Turning a deep table into fifty assignment statements is worse than the table, and the rule
never asked for it. A config that is mostly such trees — border glyphs, widget geometry, colour
numbers — should keep them and take only rules 2 through 5 seriously.

Namespace where there is genuinely more than one subsystem. A namespace with one member is a
directory with one file in it.

**The cost.** Settings now share a namespace with the API functions. A typo (`tool.thmee`) is
silently ignored, because the host cannot distinguish it from the user stashing a helper there,
and a setting named like a function would shadow it. Under a `settings` sub-table both were
structurally impossible. A `tool.set.*` namespace recovers this without giving up registration.

## 2. Behaviour is registered, and registration repeats

```lua
tool.on.event(handler)      -- as often as you like
```

This is the rule the others follow from. If a hook is one field in a returned table there is
exactly one place to put anything, so everything a config does piles into one function — this is
arithmetic, not taste. If it is a call, the config is as many small named functions as it wants:

```lua
local function write_cache(c) ... end
local function recolour_terminals(c) ... end
local function reload_desktop(c) ... end

tool.on.colors(write_cache)
tool.on.colors(recolour_terminals)
tool.on.colors(reload_desktop)
```

Registrations apply in the order they were made. **One that raises is reported and the rest still
run** — a mistake in the third handler is not a reason to skip the fourth, which has nothing to do
with it. This is only implementable once handlers are separable; it is the concrete robustness win
that repeatable registration buys.

### List form versus keyed form

**Keyed registration is the second form.** Where a registration is identified by something — a key
name, a zone name, a command — assigning into a map beats appending to a list, because it is
idempotent: registering `f4` twice replaces rather than fires twice.

```lua
tool.keys["f4"] = function(line) ... end

for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
  tool.keys["alt-" .. c] = function(line) ... end
end
```

This is not a deviation, it is the half of the rule that solves the append-only form's one real
weakness. A list registrar re-run duplicates its entries; a keyed one is safe to run twice.

- **List** where entries genuinely accumulate: handlers for one event.
- **Map** where each entry has an identity that can be replaced: keys, zones, named templates.

The map form is also what makes overriding a preset possible — register the same name again
afterwards and the later one wins.

## 3. The config file returns nothing

No `return tool.setup({...})`, no `return M`. The config is a list of statements, so it can
compute freely between them:

```lua
for _, app in ipairs({ "kitty", "waybar", "rofi" }) do
  tool.template(app, { input = shared, output = "~/.config/" .. app .. "/colors.ini" })
end

if tool.term.kitty_keyboard() then
  tool.lua.enter = "newline"
end

if on_path("pixy") then
  tool.prompt.left = { ... }
end
```

That last shape is worth noticing: the config **degrades on the machine it is running on**. The
same file works where a dependency is absent, because it asked. A returned table cannot ask.

The host reads its settings off the module table after the chunk has run, so there is nothing to
hand back.

**The cost.** The config is a side effect rather than a value: it cannot be loaded twice, held in
two instances, or inspected in a test without running it. Registration is also not idempotent —
re-sourcing duplicates list-form entries. nvim's answer is the named autocommand group with
`clear = true`; the keyed form above is the other answer.

This rule is about the **config** file. A plugin, preset or theme is a different kind of file —
rule 4.

## 4. A table is an argument, never a fragment somebody has to merge

Registration is for behaviour. A plugin, preset or theme is a *description* — a pile of values —
and a table is the right shape for one. The two coexist as long as the table is handed **to**
something:

```lua
make.recipe{ name = "smoke", deps = { "build" }, run = function() ... end }   -- an argument
tool.plugin({ "author/thing", opts = { ... } })                              -- an argument
```

What goes wrong is the table that is only returned, leaving the caller to assemble it:

```lua
-- layout.lua
return { keys = {...}, ses = { layouts = {...} } }

-- init.lua
local layout = dofile(os.getenv("HOME") .. "/.config/tool/layout.lua")
local keys = layout.keys or {}
if layout.__tool_type == "layout" then
  layouts = { layout }
elseif layout.ses and layout.ses.layouts then
  layouts = layout.ses.layouts
end
```

The merge, the `or {}` defaults and the shape sniffing all live in the config, and every further
fragment file re-implements them.

Two ways to keep it an argument instead:

- **registered** — the fragment calls the registrar itself and returns nothing; the config just
  requires it. Overriding is registering the same name again afterwards.
- **discovered** — the host scans a directory and merges the returned tables itself, the way
  lazy.nvim does. Then `return {...}` is fine: the merge exists once, in the host.

nvim splits along exactly this line — `vim.o.background = "dark"` and dozens of
`vim.keymap.set(...)` in the config, `return { "author/plugin", opts = {...} }` in a plugin spec
that lazy discovers and merges. Treat nvim as the evidence that the hybrid works, not as a
counterexample.

## 5. A handler's return value means something, or nothing

Where a handler can influence what happens next, `nil` means "not mine, carry on" and a table
means "here is what to do instead":

```lua
tool.on.key(function(k)
  if k.language ~= "sh" then return end          -- not mine
  if k.name == "enter" and k.text == "" then
    return { text = "la --git-ignore", submit = true }
  end
end)
```

Where a handler is purely a side effect, the return value is ignored and the handler returns
nothing. A render function is a third case: its return value *is* the result, and returning
nothing renders nothing.

All three are fine. What matters is that a config author can tell which kind they are writing
without checking the source.

## What the host implements

Language-agnostic; only the binding calls differ.

- Create the module table, add the host's functions to it, and **park it before the config chunk
  runs** — it is what the config assigns settings onto and what the registrars are found on
  afterwards. Set `package.loaded['<tool>'] = tool` so `require` never touches the filesystem
  looking for a `<tool>.lua`.
- Registrars append to a plain Lua list, or assign into a plain Lua map, on that table. Keeping
  them in Lua rather than in the host means they can also be assigned outright and read back by
  the config.
- After the chunk runs, read what the host needs off the module table. **Missing key means unset,
  not zero** — a setting the config did not mention must not overwrite the environment or a flag.
- Discard whatever the chunk evaluated to. It should be nothing.
- **A raise at load time is fatal** and must name file and line: carrying on with defaults
  silently applies something the user did not ask for. Name the chunk when loading it, or the
  error quotes the whole source instead of a line number.
- **A raise inside a handler is not fatal.** Call handlers one at a time under `pcall`, in
  registration order, and report a failure with enough context to identify which one.
- Build the argument passed to handlers once and reuse it rather than rebuilding it per handler.

## Naming

- `tool.on.<noun>` for events — the thing that happened, not when. `on.colors`, `on.attach`,
  `on.key`. Not `after`, `post`, `hook`: those say when, and a config full of `after` tells you
  nothing about what any of it does.
- A hook reached through `on` does not repeat it: `tool.on.key`, not `tool.on.on_key`. Where the
  canonical name carries an `on-` prefix because it is read outside the namespace too, the field
  spelling still drops it. `on.pre_cmd` is fine as it is — a before-hook that can veto genuinely
  has to say it runs before.
- Settings take the same name as the equivalent command-line flag.
- A registrar that takes a name uses it so a warning can say *which* one is wrong, and so the host
  can address or replace one later rather than duplicating it.
