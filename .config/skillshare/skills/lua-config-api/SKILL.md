---
name: lua-config-api
description: Designs, converts and reviews embedded-Lua configuration APIs in the registration style — settings assigned onto a module table, behaviour registered through repeatable calls, and the config file returning nothing. Use when adding a Lua config layer to a tool, converting a `return tool.setup({...})` table config to registration, reviewing such an API or a config written against one, or writing an init.lua for a tool that reads one. Not for editing third-party configs such as neovim or wezterm, and not for embedding Lua as a scripting or plugin runtime rather than as configuration.
---

# Registration-style Lua config APIs

A configuration API in this style reads:

```lua
local tool = require("tool")

tool.theme = "dark"                                  -- settings assigned
tool.template("kitty", { input = "…", output = "…" }) -- descriptions handed in
tool.on.colors(function(c) ... end)                   -- behaviour registered
                                                      -- no return
```

Apply this to APIs you control. Read [the five rules](references/five-rules.md) before
designing or reviewing one; it carries the reasoning, the worked examples and the failure
modes. This file is the decision procedure.

## Decide whether the style applies at all

The style is not universally correct. Classify the config before applying it:

- **Behaviour-dominant** — the config's job is to *do things* when something happens. Apply
  every rule. This is where registration pays for itself.
- **Value-dominant** — the config is mostly a tree of data (glyphs, dimensions, colour
  numbers, per-widget toggles). Apply rules 2 through 5, and apply rule 1 only in the sense
  of *delivery*: assign the tree, do not flatten it into a hundred statements.

Say which one it is and why before proposing a conversion. Flattening a large data tree into
assignment statements makes a config worse, and it is the most common way to over-apply this
style.

## The five rules

1. **Settings are assigned, not declared in a table.** `tool.theme = "dark"`. A setting the
   config never mentions is left alone. Nested data stays nested — assign the table.
2. **Behaviour is registered, and registration repeats.** `tool.on.event(fn)`, callable as
   often as the config likes. Two forms: a **list** where entries accumulate (many handlers
   for one event) and a **map** where each entry has a replaceable identity
   (`tool.keys["f4"] = fn`). The map form is idempotent; prefer it whenever the registration
   is identified by something.
3. **The config file returns nothing.** It is a list of statements, so it can branch, loop and
   probe the machine it is running on.
4. **A table is an argument, never a fragment somebody has to merge.** A plugin, preset or
   theme stays a table — it is passed to a registrar, or discovered and merged by the host.
   Never returned for the config to assemble by hand.
5. **A handler's return value means something, or nothing.** Either `nil` = "not mine, carry
   on" and a table = "do this instead", or the handler is pure side effect and returns
   nothing. A config author must be able to tell which without checking.

## Designing a new API

1. List the events the tool actually has. Most tools have one or two; do not invent a taxonomy.
2. Name each `on.<noun>` — the thing that happened, never `after`, `post` or `hook`, which say
   when and tell a reader nothing about what.
3. Decide list or map registration per registrar (rule 2).
4. Decide each handler's return contract (rule 5) and make it uniform across the tool.
5. Implement the host contract in [five-rules.md](references/five-rules.md#what-the-host-implements).
   The contract is language-agnostic; only the binding calls differ.

## Converting a `setup({...})` config

Work in this order, and keep the output verifiable at each step:

1. **Capture current behaviour first.** Run the tool against a fixture and keep the output.
   The conversion is a refactor: the generated files, rendered text or applied state must come
   out byte-identical afterwards. Diff to prove it.
2. Move settings from the `settings` sub-table onto the module.
3. Turn each list-valued key into a registrar call that appends or assigns.
4. Turn the single hook field into `on.<noun>`, then **split the caller's one big function into
   named handlers** — this is the point of the exercise, not a side effect of it.
5. Wrap each handler in its own `pcall` on the host side so one raise no longer costs the rest.
6. Delete the `setup` function, the wrapper table and the `return`.
7. Update the tool's own tests, example config and docs in the same change.

State the cost honestly in the summary. Assigning settings onto the module table puts them in
the same namespace as the API functions, so a typo is silently ignored and a setting named like
a function would shadow it. A `tool.set.*` namespace buys that back if it matters.

## Reviewing an existing API or config

Check, in this order:

- Does a hook occupy a single field somewhere, forcing everything into one function?
- Does a raise in one handler take down the others? Load-time raises should be fatal and name
  file and line; handler raises should be reported and survived.
- Is a registrar append-only where it should be keyed, so re-running duplicates entries?
- Does any fragment file return a table that a config has to shape-check and merge by hand?
- Do the names say what happened, or when?
- Is rule 1 being applied to a data tree that should stay a tree?

Report what is wrong and why it costs something concrete. Do not report a deviation that
serves the tool better than the rule would.
