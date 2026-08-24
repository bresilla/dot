local wing = require("wing")

-- Vala compiles through C: valac emits C, and a C compiler turns that into a native binary. Meson
-- is what drives both, so it is the build system and there is no flavour to choose.
wing.template("vala", {
  description = "Vala CLI app with meson, .make.lua, flake.nix, tests, and release hooks",
  language = "vala",
  framework = "cli",
  tags = { "builtin", "vala", "cli" },
  nix_packages = [[
            pkgs.vala
            pkgs.meson
            pkgs.ninja
            pkgs.pkg-config
            pkgs.glib
            pkgs.gcc]],
})
