# What the caelestia port needs from the engine

Found while porting phase 1 (the frame, the bar, the launcher and the
dashboard). Each entry says what is missing, the API that would cover it,
and why Lua cannot do it well. Work already under way elsewhere is marked
**in progress** and only left as a TODO in the port.

Nothing open: every entry found so far is in the engine (below).

Phase 2 (the other dashboard tabs, the launcher's pickers, the session
menu, the bar's popouts, notifications and the OSD) found the entries
below, all now in the engine too; the popouts shut on `contains_pointer`
like the dashboard.

## Engine fixes made in this branch

- A node's hover including its descendants: every node has a read-only
  `contains_pointer`, true while the pointer is inside its box whatever is
  on top (docs/UI.md, "Hover and press"). The dashboard shuts on
  `panel.contains_pointer` going false instead of a hand-kept list of its
  areas.
- Opacity of one layer in a field: `opacity` on an `SdfShape` fades that
  layer, seam and all, without fading the rest of the field (docs/UI.md,
  "Fields"). A drawer's background, a layer of the frame's field, now fades
  in with its contents as the reference's does.
- Headless runs (`morf check`/`render`/`test`) stretched a layer anchored at
  both ends of an axis to the screen even when it asked for a size; a
  compositor keeps the asked size, centred. The port's wallpaper layer,
  missing `height = 0`, was whole headless and a 32 px band on Hyprland.
  Headless now does what layer shell does (`crates/morf-cli`).
- `morf render --surface screen` (and `test.snapshot(..., { surface =
  "screen" })`) composed surfaces in declaration order, so a background
  layer declared after the shell's own surface covered it. They are now
  stacked by layer-shell layer (background, bottom, top, overlay), keeping
  declaration order within a layer (`crates/morf-cli`).
- An axis other than `wght` reached only the rasteriser, so Google Sans
  Flex's `opsz` could not widen small labels. Every axis is now shaped
  (the vendored cosmic-text takes the axes), optical sizing is automatic
  from the size in pixels as in CSS, and `kit.text` sets `opsz` to the size
  in points (and `ROND` 25), as the reference's font builder does. The
  Alacritty description, at the port's 15 px, measures 366 px where it
  measured 333; at the reference's own `body.small` (12 pt, 16 px) it is
  386 against the reference's 390.
- Key names: handlers are handed the key's X name as a fifth argument
  (`on_key_pressed(keysym, text, modifiers, repeat, name)`), and
  `morf.keys.Down` is its keysym; the port compares names and its keysym
  table is gone (crates/morf-lua `keys`).
- A module's budget: `require` loads on a budget of its own (20 million
  instructions, `MORF_LIMITS=module=N`), a loading's not a handler's, and
  the budgets are listed in docs/UI.md ("How much Lua may run at once").
- Bindings after construction: a function assigned to a node's property
  is a binding, as in the constructor, and replaces any it had
  (docs/UI.md, "Bindings").
- A theme-wide colour transition: `morf.theme(tokens, { transition = {
  duration, easing } })` eases every colour written to it in OkLab, frame by
  frame; the port's scheme, variant and mode changes cross-fade in 400 ms.

## Phase 3: the sidebar and the utilities

Nothing open. The idle inhibitor reads back: `morf.idle.inhibited()` is
what the shell last asked for, and `morf.capabilities.idle_inhibit` says
whether the compositor can hold one (docs/IO.md, "Idle").
