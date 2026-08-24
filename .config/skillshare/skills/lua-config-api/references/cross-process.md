# Exposing a Lua API to other processes

One tool holds a Lua API. Another process wants to call it. This is how the two halves are built,
and it is a different job from the five rules in part 1: those govern the API a tool offers *its own*
config file, this governs the surface it offers *other programs*.

The two coexist in one tool. The config API is large and local; the exposed surface is small and
remote, and the second is a deliberate subset of the first.

## Three layers, and only the bottom is per-language

A family of tools written in different languages can still share almost all of this, because only
one layer touches the host language.

### 1. A stream primitive — native, one per tool, small

```lua
local h = __stream.connect(path)
h:send(bytes)      h:recv()      h:close()
```

**This is a host native, not a VM feature.** It is registered the way every other entry in the tool's
Lua API is registered, so a VM with no C-module loading — a pure-Rust or pure-Zig one — needs no
change at all to gain it. Reach for "modify the VM" only if the VM cannot express a userdata handle;
it almost certainly can.

A tool that already has socket code for its own purposes usually has this layer written and merely
unexposed.

### 2. The client stub — plain Lua, written once, copied everywhere

Each tool ships a Lua file named after itself. It holds framing, encoding, `connect`, and the
exposed verbs. Nothing in it is language-specific, so siblings **copy it rather than port it**, and
one fix reaches every consumer.

```lua
local tool = require "tool"     -- a plain Lua file the tool ships
local sh = tool.connect()       -- no args: the env var, else the runtime directory
print(sh.env.get("PATH"))
```

`require` here loads a real file. It is **not** a proxy that mirrors the whole API — see the subset
rule below.

**Hand the library out over the API as well as on stdout.** `tool lua-api` prints it, which is
enough for a host that can shell out — and useless to one that cannot: a sandboxed VM with no
`io.popen` has no way to run it. So expose the source as a verb too (`tool.live.client()` locally, a
`client` call remotely). A sibling that speaks the framing can then fetch the right vocabulary using
the wrong one, in code, with nothing written to disk.

Do **not** add an `--install` flag that writes the file somewhere. Getting a file onto disk is the
caller's business and `tool lua-api > path` already does it; a flag that picks the path for them is
the tool inventing a convention nobody asked for, and it is a poor substitute for the verb above.

### 3. The server — dispatches to the functions that already exist

The server accepts a call by name and invokes **the same Lua function the local API uses**. It never
re-describes the data:

> A second encoder means two field lists, and they drift the moment either is edited. Calling the
> existing function means there is one definition of what a pane, an environment or a session is,
> and it is the one Lua already sees.

If a tool's exposed surface needs a field its Lua API does not have, add it to the Lua API.

## The exposed surface is a named, small subset

The single most important decision. Give it a name in the API — `tool.live`, `tool.remote` — so both
sides can point at it, and keep it short.

- **Never mirror the whole API.** Most of a config API is meaningless remotely (registrars, settings
  applied at load) or dangerous (anything that runs a command).
- **A small wrong vocabulary is worse than a large right one.** Choose verbs by asking what a
  *sibling* genuinely needs, not by listing what exists.
- **Prefer facts the peer cannot get another way.** A shell's live environment is exact where
  scraping `/proc/<pid>/environ` is not; a mux's pane list is exact where parsing CLI output is not.
  Those are the verbs worth exposing.

## The wire

**Framing: 4-byte big-endian length, then body.** Length-prefixed because a socket is a stream with
no message boundaries, and every reader otherwise invents its own delimiter.

```
-> {"call":"panes","arg":{"visible":true}}
<- {"ok":true,"n":1,"result":[ ... ]}
```

**`result` is a LIST of return values, and `n` says how many.** Not the value itself. A Lua function
can return several things and a wire that carries only one has thrown that away before anyone
notices — but the reason to fix it early is worse than expressiveness:

> Two tools in one family, one answering `{"result": value}` and the other `{"result": [value], "n": 1}`,
> **fail silently at each other.** A client that unpacks reads the second correctly and gets *nothing
> at all* from the first for any record, string or number — `session()` comes back empty rather than
> wrong. An empty answer looks like an empty session, so the bug is diagnosed as "the peer has no
> panes" for as long as it takes someone to run `socat` on the socket.

Pick one shape for the whole family before either server ships. Retrofitting it is a breaking change
to every consumer of the first one.

**A connection serves more than one request.** Closing after the reply is a tempting simplification
— it makes the server a page shorter — and it means a client that holds one connection open, which
is the obvious way to write one, dies on its *second* call with a broken pipe. Keep the connection
and let the existing bounds do the work: the connection cap and the idle timeout already exist, and
a client that wants one-shot simply closes.

**One protocol, several transports.** The same frames travel over a unix socket, over the
stdin/stdout of a spawned process, or over one exec per request. Never build the second or third as
a separate protocol — it is the same codec on different file descriptors, and the section below is
about nothing else.

## A tool with no daemon

Most tools in a family are not servers. They run, do a thing, and exit. A sibling still wants to ask
them questions, and the answer is not "give it a daemon".

**The rule that decides whether spawning is even legal:**

> **Spawning works when the tool's state lives outside the process. It fails when the state *is* the
> process.**

A tool whose truth is on disk — a host list, a project registry, a config — reads the same truth on
every exec, so a fresh process is as good as a live one. A tool whose truth is the running thing
itself — sessions, panes, open connections — gives you a fresh process that knows about *none* of
it, which is worse than an error because it succeeds.

State the answer for each tool once, in its own docs, and let the client check it rather than
leaving every caller to rediscover it.

### Two verbs, because a lifetime is not an implementation detail

Do not paper over the difference with one uniform `connect()`. The two are different things and the
call site should say which one it wanted:

```lua
-- a channel you hold: can drop, can subscribe, must be closed
local sh = tool.connect()
sh.thing(); sh:close()

-- one question, one answer, nothing held
local all = tool.fetch("things")
local one = tool.fetch("thing", "name")
```

`fetch(verb, ...)` is `Session:call` without the session: acquire, one frame, one reply, done.

**The verb describes what the caller wants, not what the tool is.** That is the whole reason this
split is worth having:

- `fetch` may use a **socket** when one exists — ask without holding.
- A tool that later grows a daemon supports both, and no existing call site changes.
- `session().live` stops mattering for most callers, because the verb already said.

Name it `fetch` rather than `read`: in a family that has access kinds, `read` already means "may
look at structure" and the collision is immediate. If writes ever travel this way, `once(verb, ...)`
is the name that stays honest — `fetch("add_thing", {…})` does not.

### The one-shot contract, spelled out

`fetch` tries two things in order, and a tool that has no daemon only needs the second.

**1. A socket, if one is listening.** Connect, one call, close. Nothing held.

**2. The tool's own one-shot mode.** The request is **argv** and the reply is **stdout**:

```
<exec> <args…> <verb> <json-arg>…      ->  {"ok":true,"n":1,"result":[ … ]}   on stdout
                                       ->  {"ok":false,"error":"no such call: x"}
```

Argv rather than a frame on stdin, deliberately: one question needs no framing, and writing to a
child's stdin needs a primitive many hosts do not lend, while running a command and reading its
output is one almost all of them do. Framing earns its place only for the persistent session.

Three rules, and the first is the one that fragments a family if you get it wrong:

- **stdout carries the WIRE shape, `n` and all** — not whatever the human-facing CLI prints. If the
  CLI unwraps for scripts (most should), then the one-shot mode is a *different* entry point, or the
  same one behind a flag. Two shapes and every client needs two parsers.
- **A refused verb is a reply, not a failure.** `{"ok":false,"error":…}` and a zero exit, so the
  caller sees *the tool's* error rather than a transport error. "no such call: nope" tells you what
  to fix; "exited 1" does not.
- **Nothing but the reply on stdout.** Logs, warnings and progress go to stderr.

### The descriptor

```
$XDG_RUNTIME_DIR/<tool>/<tool>.tool
{"exec": "/absolute/path/to/tool", "args": ["api"], "stateless": true}
```

Under the **tool's own name**, not under the asker's: a descriptor has to be findable by whoever is
asking, not only by its author. Written on every run, so a rebuilt or moved binary heals its own
entry. `exec` is absolute — the point of the file is that the client never resolves a name through
`$PATH` (see *Discovery and identity*).

### The host must lend a SYNCHRONOUS runner

`run(cmd, opts) -> { ok, code, stdout, stderr }`, answered before it returns.

**A statusbar-style `exec` is the wrong primitive and will look like it works.** That kind is
asynchronous and cached: it answers `pending` first and the real result later, which is right for
painting a prompt and useless for a request that must be answered now. A `fetch` built on one
returns an empty first answer and a populated second, which reads as the peer being flaky.

**A host that must not block is entitled to lend nothing here**, and should. A terminal multiplexer
is the clear case: a spawn inside its frontend loop suspends every pane for as long as the child
takes. Then `fetch` over a spawn is simply unavailable in that host — say so in the error, because
"cannot spawn from in here, ask from a host that can block" is actionable and a timeout is not.
Sockets still work there, which is the transport that host actually needs.

Lend `fs.read` beside `fs.ls` while you are there: the descriptor is a file the client has to read,
and plain Lua cannot.

### Implementing this in a new tool

1. Give the tool a **Lua surface worth asking** — `things()`, `thing(id)` — that the CLI calls too,
   so there is one implementation and not two. Transport last.
2. Add the one-shot entry point above, printing the wire shape.
3. Write the descriptor on every run.
4. Copy a sibling's client stub. Do not port it; `fetch` and `connect` are already in it.
5. Ship `verbs()` in the same change.

### Three transports under one `call`

```lua
function M.connect(where)
  local d = descriptor(where)
  if d.socket then return session(socket_transport(d.socket)) end
  if d.serve  then return session(stdio_transport(spawn(d)))  end  -- one process, many calls
  return session(exec_transport(d))                                -- one exec per call
end
```

Nothing above `Session:call` changes. The one-exec transport is the degenerate case — it writes the
frame to a fresh process's stdin and reads the reply from its stdout — and it is the one to reach
for first, because it has no lifecycle at all.

### Do not return a snapshot instead of a handle

The tempting shortcut for a daemon-less tool is to dump the whole store once and let the caller
index a table. Resist it:

| | snapshot | calls |
|---|---|---|
| one item | free | a request |
| **writes** | **impossible — it is a copy** | work |
| staleness | frozen at acquire | per call |
| cost | the whole store to answer one question | pays per question |

Make the snapshot a **verb** (`dump()`), not the mechanism. It costs one line and writes keep
working; the moment a snapshot is the mechanism, the first write forces a second mechanism beside
it.

### Naming the serve mode

Call it `tool serve --stdio`. Do **not** call it anything that reads as "here is Lua, run it" — a
subcommand that evaluates code handed to it on stdin is remote code execution with a friendly name,
and it is the same rule as keeping `run`-shaped verbs out of the surface.

### What actually breaks

Three operational details, each of which presents as a protocol bug and is not one:

- **Flush after every single reply.** This is what makes a persistent process usable interactively;
  without it the client blocks forever on a reply sitting in the child's stdio buffer.
- **Keep stderr silent, or drain it on its own thread.** The classic deadlock is the parent reading
  stdout while the child blocks writing to a full stderr pipe. Nothing about it looks like framing.
- **A failed request is a reply, not an exit.** `{"ok":false,...}` and keep serving. Reserve the
  process's exit status for failing to start at all.

## Discovery and identity

Support all three ways to name a peer; once `connect` exists they cost almost nothing:

| form | for |
|---|---|
| `connect()` | an env var the tool exports — a process it started inherits this free |
| `connect("<session-id>")` | a specific session, when several are running |
| `connect{path = "…"}` | explicit, for tests and odd layouts |

Bind at `$XDG_RUNTIME_DIR/<family>/<tool>/<session>.sock`, mode `0700` on the directory. A stale
socket is one that fails to connect; unlink and rebind rather than refusing to start.

**Discovery stays implicit; the spawn target must not be a guess.** Resolving a bare name through
`$PATH` and exec'ing whatever answers is a different risk class from opening a socket something
already chose to create — and it fires on the *failure* path, when nothing was listening, which is
exactly when nobody is watching. Have each spawnable tool drop a descriptor beside the sockets, and
scan the one directory for both:

```
$XDG_RUNTIME_DIR/<family>/<tool>/<session>.sock     a live peer      -> connect
$XDG_RUNTIME_DIR/<family>/<tool>.tool               a spawnable tool -> exec
```
```json
{"exec": "/absolute/path/to/tool", "args": ["serve", "--stdio"], "stateless": true}
```

The client then spawns **an absolute path the tool wrote about itself**, never a name it resolved.
Same principle as the sockets: authority belongs to whoever made the door. Three things follow free:

- A tool whose state *is* the process simply never writes one, so "do not spawn this" stops being a
  rule someone must remember and becomes a fact the client can check.
- Written on every run, it is self-healing — a rebuilt or moved binary fixes its own descriptor, and
  there is no install step to forget.
- Naming a tool is intent; `connect()` with no argument is not. Spawn on the named form, never on
  the bare one.

**Ship `verbs()` in every tool in the family, from the first version.** A call that returns the
names the peer will answer costs nothing and is impossible to retrofit quietly: the moment one tool
has it and another does not, a client written against the first gets `no such call: verbs` from the
second, and the family stops being one. Where a surface is gated by access kinds, return what *this
caller's door* may reach rather than the whole list.

Have the client stub still spell its surface out as a literal table rather than deriving it from
`verbs()` — a surface you have to run something to learn is one nobody audits. `verbs()` is for
discovery at runtime, not for building the client.

Name the exposed verbs plural-for-all and singular-for-one — `things()` / `thing(id)` — and keep
that shape across every tool. It is a small thing that decides whether the family reads as one.

**Lend a directory lister as well as the stream primitive.** Plain Lua cannot read a directory, and
`io.popen` works only where the host permits it — a safe-mode VM removes `io` entirely, so a stub
that shells out to `ls` reports "nothing is running" on exactly the hosts this exists for. Add
`tool.fs.ls` beside `tool.stream`, and have the stub ask **whichever host it is running inside**
rather than the one that shipped it — A's stub, loaded into B, must call `B.fs.ls`. Looking only at
`_G.<own name>` is the same bug as shelling out, one layer up. Scan every family member's socket
directory too — the stub does not know which tool it will be pointed at.

**Take peer identity from the kernel, never from the peer.** `SO_PEERCRED` on a connected unix
socket yields the connecting pid and uid. A pid the peer wrote into a file or a message is a claim;
this is a fact.

**A name is not a filename.** The socket is named when it binds; whatever it names can be renamed
afterwards and the file does not follow, so `<tool>@one.sock` can be the session that now calls
itself `two`. A caller who reads a live name and builds a path from it finds nothing. Match against what
each candidate *answers to* — connect and ask — and report its own socket path in the session record
so the round-trip is possible at all.

**Refuse a connection to the caller's own instance.** From inside the host's event loop it can never
be answered: the process is busy running the caller. It presents as a hang and ends in a socket
timeout, which says nothing about the cause. Publish the host's own socket path into its Lua and
have `connect` fail with a sentence instead.

## The server is opt-in and lazily bound

Most processes are never talked to. Binding a socket in every one of them costs a file, an fd and a
line of teardown for nothing.

Bind on demand: an explicit call, a config setting, a keybinding. A tool that nobody asks about
should have no socket at all, and that property is what makes the feature safe to ship on by
default in the *client* direction while the server stays quiet.

## Bound everything

A control socket serves occasional requests, not traffic. Every one of these needs a number:

- maximum concurrent connections;
- maximum request size — arguments are small filter tables;
- maximum response size — the ceiling that stops a pathological query allocating without end;
- connection timeout, so a half-finished request does not sit forever;
- encode depth, because a Lua table can be cyclic.

**A stalled reader must never block the host's main loop.** In a terminal mux or a shell, a blocking
accept or read on this socket suspends the thing the user is actually using. Accepts and reads are
non-blocking; a request that has not finished arriving is left for the next iteration rather than
waited on.

Also bound `connect()` on the client side: a blocking connect to a unix socket whose listen backlog
is full parks in the kernel with no timeout of its own.

## Security

**A socket that runs commands is remote code execution on the user's session.** Say that plainly in
the design, because every later decision is made in its shadow.

- Refuse a connecting uid that is not the owner's, using the credentials from `SO_PEERCRED`.
- Gate per call, not per connection: a table of which verbs a caller may reach.
- **Keep `run`-shaped verbs out of the first cut.** Add one later behind an explicit opt-in, if at
  all. A surface that only answers questions is a much smaller thing to get right.

## Encoding: state the tradeoff, do not pick blindly

**JSON** is the interop baseline. Every language has it, and a socket speaking it can be debugged
with `socat` and read by a human. It loses:

- byte strings that are not valid UTF-8;
- the integer/float distinction;
- `nil` as a table value;
- cycles.

**A binary value codec** keeps all of that and is perhaps 200 lines per language. It is worth it
when the tool's own value type has bytes or an integer/float split that the exposed verbs actually
carry — and not worth it when the subset is strings and flat records.

Decide from what the subset carries. If a family already has a working JSON server, keep JSON as the
baseline and negotiate anything richer on connect rather than breaking what runs.

## Events are a separate layer, and a later one

**Functions cannot cross a socket.** `tool.on.something(function() ... end)` needs the peer to store
an opaque handle and push a message back when it fires. That turns a request/response exchange into
a long-lived bidirectional connection, and it brings the reentrancy problem with it: an event can
arrive while the client is inside a call, and both sides need a rule for what happens then.

That is most of the work and all of the risk. Ship calls first. A call-only surface answers nearly
every question a sibling actually has, and it can be built, reviewed and trusted in isolation.

## What the host implements

- The stream native, exposed to the tool's own Lua like any other API entry.
- A server that binds on demand, dispatches by name into the existing Lua functions, and enforces
  the bounds and the access gate above.
- The client stub, as a plain Lua file the tool ships and siblings copy.
- Both codecs' depth and size caps, applied in *both* directions — a hostile request and a cyclic
  result are the same class of problem.

## Reviewing one of these

- Does the exposed surface restate anything the local API already describes?
- Is the subset named, and is it short enough that its whole vocabulary fits on one screen?
- Does every bound above have a number, and is the main loop provably not blocked by a slow peer?
- Is peer identity taken from the kernel or from something the peer said?
- Does a verb execute anything the caller supplies, and was that a deliberate decision?
- Is the client stub plain Lua, or has it grown a dependency that stops siblings copying it?
