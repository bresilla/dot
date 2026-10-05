# Shared content layouts

Both visual themes use these builders. Preserve the same sections, grouping,
control order, navigation and available actions when switching themes.
Useful titles belong here so both themes receive them.

The selected `kit` supplies typography, shapes, surfaces and interaction
feedback; `theme.motion` supplies transitions. These are styling hooks, not
permission to add or rearrange content. The shared tab container keeps page
selection separate from the page revealed beneath a transition.

Lock and greeter follow the same rule. Their controllers own authentication;
the shared layouts place the controls, and the Tsugumori adapter decorates the
constructors. The approved frame and edge-marker skins remain separate.

`tests/shared_layout_spec.lua` checks common builder selection, section
geometry across both themes, trailing tab icons, and authentication geometry.
