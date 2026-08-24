local wing = require("wing")

-- Odin is its own compiler and build system, the way Zig and V are, so there is no build-system
-- flavour to choose.
wing.template("odin", {
  description = "Odin CLI app with .make.lua, flake.nix, tests, and release hooks",
  language = "odin",
  framework = "cli",
  tags = { "builtin", "odin", "cli" },
  -- `ols` is deliberately absent. It is the Odin language server, and it brings `odinfmt` with it,
  -- but it does not compile against the Odin this pin provides -- and a package that fails to build
  -- takes the whole dev shell down with it, not just the formatter. The recipes say what is missing
  -- when it is missing, which is better than a shell nobody can enter.
  nix_packages = "            pkgs.odin",
})
