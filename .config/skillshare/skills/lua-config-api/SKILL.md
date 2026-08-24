---
name: lua-config-api
description: Designs, converts and reviews embedded-Lua APIs for tools you control — both the registration-style config API a tool offers its own init.lua (settings assigned, behaviour registered, nothing returned) and the cross-process API it exposes to other programs over a socket, a spawned process, or one exec per call (client stub, server, exposed subset). Use when adding a Lua config layer, converting a `return tool.setup({...})` config to registration, reviewing such an API or a config written against one, or when implementing the client side (the exposed library another tool requires) and the server side (how a client connects and calls in), including letting a sibling query a tool that has no daemon. Not for editing third-party configs such as neovim or wezterm, and not for embedding Lua as a scripting or plugin runtime rather than as configuration.
---

# Embedded-Lua APIs for tools you control

Two jobs, one skill, because a tool that does the second almost always does the first, and the
second is built out of the first.

| the job | the surface | read |
|---|---|---|
| **config** — the API a tool offers its own `init.lua` | large, local, in-process | this file, then [the five rules](references/five-rules.md) |
| **cross-process** — the API a tool offers *other programs* | small, remote, over a socket or a spawn | [cross-process](references/cross-process.md) |

Work out which is being asked for before writing anything. "Add a Lua config to this tool", "convert
this `setup({...})`", "review my init.lua" is the first. "Let another tool call into this one",
"implement the client side and the server side", "expose the Lua API over a socket", "let another
tool query this one when it has no daemon" is the second.

When both are in play, design the config API first: the exposed surface is a deliberate subset of it,
so it cannot be chosen until there is something to choose from.

---

# Part 1 — Registration-style config APIs

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

---

# Part 2 — Exposing the API to other processes

When one tool must call into another's Lua — a shell and a terminal mux, a painter and the session
it draws for — read [cross-process](references/cross-process.md) in full before designing it. The
shape:

```lua
local tool = require "tool"     -- a plain Lua file the tool ships
local sh = tool.connect()       -- env var, else the runtime directory
print(sh.env.get("PATH"))
```

**Three layers, and only the bottom one is per-language:**

1. **A stream primitive** — `__stream.connect(path)`, `h:send`, `h:recv`, `h:close`. A host native
   like any other API entry, *not* a VM feature: a VM that cannot load C modules needs no change.
2. **The client stub** — a plain-Lua file each tool ships, holding framing, encoding, `connect` and
   the exposed verbs. Pure Lua, so siblings **copy it rather than port it**.
3. **The server** — dispatches a call by name into **the same Lua function the local API already
   uses**, so the two can never describe a pane, an environment or a session differently.

**The rules that decide whether it is any good:**

- The exposed surface is a **named, small subset** — never a mirror of the whole API. A small wrong
  vocabulary is worse than a large right one.
- **Never restate the surface in a second encoder.** Two field lists drift the moment either is
  edited.
- **Settle the reply shape before either server ships.** `{"ok":true,"n":1,"result":[value]}` — a
  *list* of return values, because a Lua function returns several. Two tools in one family
  disagreeing here fail **silently**: a client that unpacks reads a bare-value server as having
  returned nothing at all, so the bug presents as an empty session rather than an error.
- **Keep the connection open after replying.** A client that holds one connection — the obvious way
  to write one — otherwise dies on its *second* call with a broken pipe.
- **Every discovery bug is invisible from inside the tool that owns it.** Sockets in the wrong
  directory, a lister that only sees its own host, a name that does not match its file: all of them
  work when the tool talks to itself. Test by having the *sibling* connect, or do not claim it works.
- The server is **opt-in and lazily bound**. Most processes are never talked to and should have no
  socket at all.
- **Bound everything** — connections, request size, response size, timeout, encode depth — and never
  let a slow peer block the host's main loop.
- Take peer identity **from the kernel** (`SO_PEERCRED`), never from a number the peer sent.
- **A socket that runs commands is remote code execution.** Keep `run`-shaped verbs out of the first
  cut.
- **Functions cannot cross.** Callbacks make the connection long-lived and bidirectional and bring
  reentrancy with them — a separate, later layer. Ship calls first.
- **Not every tool is a server, and that is fine.** Spawning works when the tool's state lives
  outside the process and fails when the state *is* the process — a fresh process then knows about
  none of it and answers anyway, which is worse than an error. Same frames over a socket, over a
  spawned `tool serve --stdio`, or over one exec per request.
- **Two verbs, because a lifetime is not an implementation detail.** `connect()` is a channel you
  hold and close; `fetch(where, verb, ...)` is one question with nothing held — a socket if one is
  listening, else the tool's own one-shot mode: request in argv, wire-shaped reply on stdout. The
  verb says what the *caller* wanted, so a tool that later grows a daemon breaks no call site.
- **The one-shot mode prints the WIRE shape, not what the human CLI prints**, and a refused verb is
  `{"ok":false,...}` with a zero exit. Otherwise every client needs two parsers and a real error
  arrives as "exited 1".
- **A one-shot needs a SYNCHRONOUS runner from the host.** A statusbar-style async, cached `exec`
  answers `pending` first and looks like a flaky peer. A host that must not block — a mux — lends
  none and says so.
- **Ship `verbs()` from the first version.** One tool having it and another not is how a family
  stops being one, and it cannot be retrofitted quietly.

Encoding is a real decision, not a default: JSON is the debuggable interop baseline and loses byte
strings, the integer/float split and `nil`-in-table; a binary codec keeps them for roughly 200 lines
per language. Decide from what the subset actually carries, and say which you chose and why.
