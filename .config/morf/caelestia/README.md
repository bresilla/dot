# Caelestia

Run the example with `morf examples/shells/caelestia/shell/init.lua`.
The top, bottom, left and right panel triggers wait for a 600 ms hover
before opening, including at the outermost pixel. Leaving early cancels
the pending opening. IPC also opens them:

```sh
morf ipc call capture toggle
morf ipc call bottom open
morf ipc call assistant open
morf ipc call tasks open
morf ipc call calendar open
morf ipc call close
```

The bottom edge opens a large workspace with **Assistant** and **Drop**
tabs. Material's maximum size is 1696 × 751, with the same proportional
reduction on smaller screens (20% narrower and 40% shorter than the previous
panel). Tsugumori keeps that desktop footprint and uses the available width
on compact screens, with vertically scrollable pages.
Assistant awaits a provider; Drop is a placeholder for the future
[termworks/drop](https://github.com/termworks/drop) messaging and file-sharing
integration. Open it directly with `morf ipc call bottom open drop`.
Click outside the workspace to close it from either tab. When opened by
hovering the bottom edge, it also closes after the pointer leaves it.
Add future pages in `shell/bottom_model.lua` and register their builders in
each visual theme. Assistant, Drop and the workspace container have separate
Material and Tsugumori layouts.

**Lule** lives in the top dashboard, in a 992 × 588 panel. The wallpaper
gets 60% of the top row, with a narrower color pane beside it and a control
strip below; all color swatches and Apply stay visible. **Wallpaper folder**
shows the collection used by Images, Shuffle, the arrows, and Random & apply.
Edit that field and press **Use folder** (or Enter) to save a different folder;
`~/` paths work. This remembers `lule.folder` in the shell's `caelestia.json`
settings across restarts and monitors. Invalid folders leave the collection
unchanged. Initially it uses `LULE_W`, then the current wallpaper's folder.
This is the panel's collection setting; standalone Lule still uses its own
`lule.wallpaper` config / `LULE_W` environment setting.
Use Images, Shuffle or the arrows to preview an image.
The folder is rescanned when opening the tab or Images, shuffling, using the
arrows, or choosing Random & apply, so added and removed images are picked up
automatically. Use folder is only needed to change the collection's directory.
Choose dark/light and a palette method, then press
**Apply wallpaper & colors**. **Random & apply** chooses another image and
applies it immediately using the selected appearance and palette method.
Images and Shuffle remain preview actions.
The swatches show the currently applied ANSI palette and special colors;
click a swatch to copy its hex value. Open directly with `morf ipc call lule open`
or click the top dashboard’s Lule tab. With no arguments, `morf ipc call lule`
still reports the terminal/accent diagnostics.

The tab runs `lule create --image=… --theme=… --palette=… -- set` through
`lib.lule.generate`, preserving Lule's config, templates and desktop hooks.
Current Lule uses `~/.config/lule/init.lua` (or `LULE_C`); a separate legacy
`lule_colors` script is not run a second time. The bundled tab icon is Lule's
original SVG geometry: outlined when inactive, filled with the accent when
selected. Its license is in `shell/assets/`.

Previews resize on an image worker only while the Lule page is visible.
They overwrite one small scratch JPEG per output and clear on closing;
opening the shell does not decode an entire wallpaper collection.

Capture is a separate, compact bottom popup. Open it with PrintScreen,
the **Screenshot / Record** button in quick settings, or `capture toggle`
over IPC. It never opens from hovering the bottom edge. Choose region,
focused window or screen, an optional delay, then Screenshot or Record.
There is no capture history or gallery. Click outside to close it. Reopen
it to stop a recording or cancel a pending countdown. Stop signals only the recorder it started.

Bind PrintScreen in the compositor (Hyprland Lua config):

```lua
bind_exec("Print", ctx.home .. "/.local/bin/morf ipc call capture open")
```

Custom recording commands must stay in the foreground (use `exec` in a
shell wrapper) so the shell can track and stop them. The default tools are
`grim`, `slurp`, `wl-copy`, `hyprctl`, `jq`, and `gpu-screen-recorder`;
commands and the destination folder are set in `shell/config.lua`.

After changing the example, `oslo make apply --example caelestia` updates
the installed configuration (with backups); restart the shell afterward.
`oslo make install` updates the engine/library, not the installed example.

The left panel has **Tasks** and **Calendar** tabs. Tasks uses the installed
`task` executable and the user's normal Taskwarrior configuration, including
`TASKRC` and `TASKDATA`. Its reusable client is `library/lib/taskwarrior.lua`.
No second task database or sync service is created. Tasks refresh when the
panel opens, every ten seconds while open, and after a successful change.

Click a task to edit its description, project, priority, scheduled date and
time, deadline, waiting date, tags, recurrence, recurrence end, or dependencies.
Dates accept Taskwarrior expressions such as `tomorrow`, or an ISO date/time
such as `2026-10-01T09:00`. A repeating task needs a due date. Editing one
occurrence does not propagate changes to its siblings. The editor also
offers start/stop, completion, and deletion with a second click to confirm.

Calendar shows a month and tasks scheduled or due on the selected day, in
local time. “Plan a task” preselects that day. Work-mail meetings are not
connected yet; the calendar explicitly shows that state.

Performance and battery graphs collect the latest 60 samples while their
tabs are closed. Old samples are overwritten in memory; restarting the
shell resets them. No history files are written.
Reloading the configuration also starts a new history. CPU history spans
two minutes; memory and battery span three minutes. After a restart or
reload, the graphs fill from the right as samples arrive.

`morf ipc call dashboard-history` reports sampling counters and errors without
waking idle sources. Pass an output name (for example `dashboard-history DP-6`)
to inspect that monitor. The counters should increase with the drawer closed.

## Visual themes (in progress)

The shell, lock and greeter select a visual package with
`CAELESTIA_STYLE=material` or `CAELESTIA_STYLE=tsugumori`. Without that override,
selection comes from `theme` in `$XDG_CONFIG_HOME/morf/caelestia/appearance.json`
(or the file named by `CAELESTIA_APPEARANCE`); Material is the default.
Changing the selection currently requires restarting the preview. Wallpaper
and Lule colors remain independent of that selection.

Both themes use the same content builders in `themes/layouts/`: sections,
control order, navigation and information grouping stay the same. Useful
section titles are shared additions too. Tsugumori supplies typography,
framed controls, subtle wallpaper-accent borders, title decoding, hover
feedback and covered transitions. Its approved edge pills remain a visual
override. Every tab has its icon at the right end, including Lule's custom SVG.

Shell services and authentication remain outside the visual components.
Preview mode disables task changes and real authentication actions. The
conversion and broad verification are still in progress; see
[THEMING.md](THEMING.md). Develop and review in the isolated sandbox before
installing.

## Checks

```sh
morf test --no-dbus library/tests/lule_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/lule_spec.lua
morf test --no-dbus library/tests/taskwarrior_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/hover_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/panels_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/history_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/heading_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/panel_headings_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/planner_typography_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/planner_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/side_panel_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/bar_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/keyboard_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/auth_keyboard_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/auth_desktop_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/network_typography_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/history_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/frame_rail_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/bottom_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/settings_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/sound_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/connectivity_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/power_bar_theme_spec.lua
morf test --no-dbus examples/shells/caelestia/tests/net_pages_theme_spec.lua
```

The library tests use a real Taskwarrior installation with a temporary
configuration and database, or skip the CLI test if it is unavailable.
Panel tests stub external commands and never change the user's tasks or
record the desktop.

Keyring prompts use morf when the optional `morf-keyring` helper is installed
on PATH. See [the bridge build and test instructions](../../../tools/keyring/README.md).
The bridge keeps GNOME Keyring as the secret store and displays unlock,
new-password and confirmation dialogs using the current theme. It starts on
the primary output, waits for existing GNOME prompts to finish, and leaves
GNOME's original prompter available when the shell is stopped. Inspect its
status with `morf ipc call keyring`.

The **Shell theme** controls at the bottom of Lule switch between Material and
Tsugumori without restarting the process. Open drawers use an accent wipe while
the shell replaces its visual components. The selected theme is saved in
`$XDG_CONFIG_HOME/morf/caelestia/appearance.json` (`CAELESTIA_APPEARANCE` overrides
that path); `CAELESTIA_STYLE` remains a startup override for previews.

The switch retains open drawers, selected tabs, Taskwarrior editor drafts,
Lule selections, notification history, and bounded performance/battery samples
in memory. These snapshots are released after the switch and never written to
disk. Finish an active authentication prompt, capture, task operation, or Lule
apply before switching. IPC also supports `morf ipc call appearance material`
and `morf ipc call appearance tsugumori`; calling `appearance` alone reports the
current theme and transition status.
