local wing = require("wing")

-- V is its own compiler and build system, the way Zig is, so there is no build-system flavour to
-- choose. `.make.lua` drives `v` and nothing else.
wing.template("v", {
  description = "V CLI app with v.mod, .make.lua, flake.nix, tests, and release hooks",
  language = "v",
  framework = "cli",
  tags = { "builtin", "v", "cli" },
  nix_packages = "            pkgs.vlang",
})
