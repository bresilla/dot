local wing = require("wing")

-- dub is D's build system, so there is no build-system flavour to choose. The compiler is: ldc2,
-- dmd and gdc all build the same dub project, and `make build --compiler dmd` switches it, the way
-- `--toolchain` does for C and C++.
wing.template("d", {
  description = "D CLI app with dub, .make.lua, flake.nix, tests, and release hooks",
  language = "d",
  framework = "cli",
  tags = { "builtin", "d", "cli" },
  nix_packages = [[
            pkgs.dub
            pkgs.ldc
            pkgs.dformat
            pkgs.dscanner]],
})
