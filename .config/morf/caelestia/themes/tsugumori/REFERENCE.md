# Motion reference and current implementation

Reference: [Tsugumori](https://github.com/Aleph1-9012/Tsugumori),
commit `0b398e7fbc7633abbbdf27ea1e93d1c99e6d6866`.
Adapted code is covered by the adjacent `LICENSE-Tsugumori`.

- `widgets/Menu.qml`: covered entrance, 440 ms OutExpo; separate uncover,
  340 ms OutExpo. Exit covers over 420 ms with cubic Bézier
  `(0.76, 0, 0.24, 1)` and withdraws over 510 ms starting at 270 ms.
  `motion.lua` adapts travel to each shell edge and preserves interrupted poses.
- `components/controlcenter/ControlCenterView.qml`: subcontrols enter from
  `(-12, -8)`, 380 ms OutCubic after 280 ms plus an 80 ms stagger.
  The dashboard also adapts its selected-card branch motion: geometry travels
  over 480 ms OutCubic, surrounding cards fade over 240 ms, and withdrawal uses
  250 ms InCirc. Detail entry waits 280 ms before its 380 ms settle. Covered
  branch changes retain the shared page-cover animation. Calendar and media
  controls preserve their existing shell actions.
- `components/controlcenter/Frame.qml`: moving corner marks inform the shared
  interaction feedback. The hover underline was removed at the user's request.
- `widgets/lockscreen/PhaseArt.js` and `shaders/lines.vert`: deterministic
  hash, branching K strokes, progressive stroke lengths, and password-count
  glyph subdivision are ported to the Lua shader in `phase.lua`. The field is
  calculated on the GPU. Eleven uniform values update every 16 ms only during
  presentation or typing; the timer stops afterwards. No shader reads time.
- `widgets/lockscreen.qml` / `PhaseArt.componentState`: 1450 ms presentation,
  950 ms dismissal; staggered frame, folio, account and authentication reveal.

All colors use wallpaper-derived semantic roles. Fixed upstream red and its
branding are not required by these effects.

This is not a claim of full visual parity. The dashboard now has independent
overview-to-branch choreography, but several inherited detail pages still need
dedicated layouts. Weather has a responsive forecast register, and Battery
has a charge register and responsive instrument graphs. Both stack at compact
widths; the remaining fixed detail pages scroll their native geometry.
Intermediate-pose tests and Cage captures exercise the new transitions; they
do not establish exact motion parity with the reference.

Engine detail: reads of animated node values do not invalidate Lua bindings
each frame. Native channels therefore animate directly; auth opacity ramps
use sampled native keyframes. Only shader uniforms need the finite timer.

## Mara GAME additions

[Mara](https://github.com/bresilla/mara), inspected at
`3e8790a8bc5662dbe917875a789692e77ce32dde`, supplies the design reference
for `heading.lua`: `crates/core/src/style.rs` (`scramble_text`) and
`crates/core/src/pane/title.rs` (chromatic title ghosts and registration pips).
This is an independent Lua implementation of those visual ideas.

Titles decode left to right after their panel begins revealing. After the
normal 560 ms reveal delay, the first letter locks at 650 ms; an 80 ms stagger
caps decoding at another 1370 ms (1930 ms including the delay). The brief
workspace indicator uses the same component with a 160 ms lead and 20 ms
stagger, so it finishes before its short hold expires.
The light is slightly raised from the line-box center to align with the
visible uppercase letters beside each title, and gives two short pulses
occasionally while visible. Each title starts after a random 4–9 seconds and
chooses a fresh random 7–11 second pause between bursts, so titles do not blink
in unison. Hiding the panel or scrolling the title out of view stops its timer
and animation. A finite split-color flash accompanies the reveal.
Ghost colors use the wallpaper's secondary and tertiary roles, not fixed
red/cyan. UTF-8 characters stay intact. Hiding cancels the timer and motion;
reopening starts a fresh decode. The only text timer runs at 25 Hz during the
finite reveal. The occasional title light uses finite native animation, with
a slow timer between bursts and no redraw animation during the quiet pause;
the text and color ghosts remain still after decoding.

Mara's button motion catalogue is deliberately excluded: retain the existing
Tsugumori corner feedback and rolling button labels. The inspected "beeping"
effect is a visual blinking pip, not an audio implementation.

The workspace rail, frame registration corners and notification history
register are independent morf layouts using these shared motion and text
components. Material retains its own rounded frame, morphing workspace discs
and grouped history cards. The history controller owns actions and identity;
neither visual package owns notification expiry or server calls.

The moving light blade on drawer and page reveals uses the registration-edge
motif from [Tsugumori](https://github.com/Aleph1-9012/Tsugumori) and the brief
HUD accent flashes in [cyberpunk-ui](https://github.com/rintran720/cyberpunk-ui)
as visual references. It is drawn as a sibling above the clipped cover because
the renderer can hide children of an animated cover beneath its fill. A narrow
on-surface stroke leads a low-opacity wallpaper-secondary trail. Both are
finite native tracks and disappear when the reveal finishes or reverses.
