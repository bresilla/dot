# Plugins: config somebody else wrote

A plugin is a **fragment of config that arrived on its own**. It runs in the tool's own Lua, against
the same API `init.lua` uses, and it registers rather than returns — [rule 4](five-rules.md#4-a-table-is-an-argument-never-a-fragment-somebody-has-to-merge)
calls this the *discovered* form: the host scans, so the merge exists once in the host instead of in
every config that wants somebody else's tab.

**Follow neovim.** It is the most-used embedded-Lua config in existence, its plugin model has been
attacked by twenty years of real plugins, and a person arriving at your tool has probably already
learned it. Deviating buys nothing and costs everyone the transfer. This file is that model, reduced
to the parts a smaller tool needs.

A family of tools shares one convention. Two siblings that each invent a layout stop being a family:
learning one teaches you nothing about the other, and a plugin cannot move between them even when the
API would allow it.

## A search path, not a directory

The mistake is to pick *one* folder and scan it. neovim has an ordered **list** of roots, and every
root has the same internal layout:

```
runtimepath = /etc/xdg/nvim               system
              ~/.config/nvim              yours
              <each installed package>    added as it is found
              /usr/share/nvim/runtime     the tool's own
              …/after                     always last
```

`:h load-plugins` describes startup as, in order: source `plugin/**/*.lua` in every root; then add
each package under `pack/*/start/*` to the path and source theirs; then, finally, the roots ending in
`after`.

What the list buys, and a single directory does not:

- **The tool ships its own runtime the same way a user ships config.** No special case for built-ins.
- **A package is just another root.** Installing is "put a directory here and it joins the path" —
  no registry, no manifest, no install step in the tool.
- **Order is a feature.** Later roots override earlier; `after/` exists precisely to run last.

Adopt the shape even if the tool starts with two entries. A path with one element is still a path,
and growing one later is a config break.

## What is in a root

```
<root>/
    plugin/*.lua      sourced at startup, alphabetically, subdirectories included
    lua/*.lua         modules for `require`, never auto-run
    after/plugin/     sourced after everything else
```

**`plugin/` runs, `lua/` is required.** This split is the single most useful thing to copy. A file
under `plugin/` is a statement the tool executes for you; a file under `lua/` is a library that does
nothing until something requires it. Tools that auto-run *everything* leave plugin authors no place
to put a helper, and every helper then has to defend itself against being executed twice.

**Alphabetical within a directory, path order between them.** Directory order is filesystem order,
which differs between machines and after a reinstall. neovim sorts; so should you.

**`after/` is the override seam.** A user who wants to undo something a plugin did needs a place that
runs later, and "edit the plugin" is not one.

## Packages: a directory that ships plugins

```
pack/<any>/start/<plugin>/plugin/thing.lua     loaded at startup
pack/<any>/opt/<plugin>/plugin/thing.lua       loaded on demand
```

`start/` is auto-loaded; `opt/` waits for an explicit request (`:packadd`). The `<any>` level lets a
person group packages — by source, by purpose — without the tool caring.

The lesson worth taking even if you skip the nesting: **a plugin is a directory laid out exactly like
a config root.** Not a special format, not a manifest — the same shape, somewhere else on the path.
That is why a neovim plugin can be developed by symlinking it into your config and moved into a
package later without editing it.

## Loading

```
discover  → every root on the path, in order
files     → <root>/plugin/**/*.lua, alphabetically per directory
run       → as source, never bytecode
failure   → report and carry on
after     → the `after` roots, last
```

**Load as source (`.text`), never bytecode.** Lua has no bytecode verifier, so a compiled chunk walks
past every source-level sandbox the host set up. This matters more here than for `init.lua`, because
a plugin is the file most likely to have come from elsewhere.

**A raise is reported and the rest still load** — deliberately unlike `init.lua`, where a raise
should be fatal. The user's own file failing means carrying on would silently apply settings they did
not ask for. A plugin failing is one of several, and taking the tool down with it is worse than doing
without it.

**Load once.** First load and reload usually route through the same function; running a plugin twice
doubles every binding it registered, and the second registration looks exactly like a plugin whose
handler fires twice.

**Offer the escape hatch.** neovim has `--noplugin`, `--clean` and `'loadplugins'`, because the first
question when a tool misbehaves is "is it me or a plugin?" A tool with no way to start without
plugins makes that question unanswerable.

## What a plugin may assume

It gets the API the config gets. It is a fragment of config, so the registrars are simply there:

```lua
-- <root>/plugin/keycast.lua
local tool = require("tool")

local on = false
tool.key({ tool.key.ctrl, tool.key.alt, tool.key.k }, function() on = not on end)

tool.on.key_pressed(function(ev)
  if not on then return end
  ...
end)
```

It **returns nothing**, exactly as `init.lua` returns nothing (rule 3). A plugin that returns a table
for the host to merge is the failure rule 4 describes, one directory further away.

Modern neovim adds a second, *managed* layer on top — `lua/plugins/*.lua` returning specs that
lazy.nvim discovers and merges, `return { "author/repo", opts = {...} }`. That is rule 4's
*discovered* form and it is fine, but note where it lives: in `lua/`, required by a manager, not
auto-sourced. Do not blur the two. `plugin/` runs; specs are data somebody reads.

## Trust follows who wrote it, not what it does

neovim has no approval step at all: what is on your runtimepath runs. That is the right default, and
the reason is worth stating — the person put it there. A prompt would ask them to confirm a decision
they already made by copying the directory.

If a tool does add a gate, gate on **provenance**, never on capability. Gating on capability produces
a prompt for the plugin the tool itself ships while saying nothing useful about the one someone
downloaded.

| where it came from | what to do |
|---|---|
| on the path because the tool put it there | **run it** — it shipped with the binary beside it |
| on the path because the user put it there | **run it** — that was the decision |
| fetched by a manager, on the user's instruction | **run it**; the manager is where a review belongs |

Anyone who can alter a first-party plugin can already alter the tool's binary, so a second yes buys
nothing and costs something real: a plugin sitting installed and inert until somebody notices.

### If you keep a content hash anyway

Approval bound to a hash is revoked by *any* edit, including the author's own. During development
that means: install, edit, and the plugin is silently off again.

- **Say it out loud.** An installed-but-unapproved plugin must appear in the listing as
  `CHANGED — run <tool> plugin allow`, never as absent. Silence reads as "the feature is broken", and
  the person debugs the plugin instead of the approval.
- **Approve what you ship, at install.** Otherwise every release of the tool disables its own plugins.

## Review checklist

- Is it a **path** of roots, or one hardcoded directory?
- Do the tool's own runtime files sit on that path like everyone else's, or are they special-cased?
- Is there a `plugin/` (auto-run) and `lua/` (required) split, so a plugin can ship a helper?
- Is there an `after/` seam for overriding what a plugin did?
- Is load order sorted within a directory and by path order between directories?
- Is the entry loaded as source rather than bytecode?
- Does one plugin raising still leave the others loaded?
- Can the loader run twice — a reload — without doubling every registration?
- Is there a documented way to start with plugins disabled?
- Does a plugin the tool itself ships demand manual approval? It should not.
- Is there a second plugin mechanism for the same concept? Two systems, one idea, is the failure this
  convention exists to prevent.
