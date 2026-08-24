local wing = require("wing")

-- Crystal compiles to a native binary through LLVM; the Ruby-shaped syntax is not an interpreter.
-- `crystal` is the compiler and the build tool, and `shards` resolves dependencies, so there is no
-- build-system flavour to choose.
wing.template("crystal", {
  description = "Crystal CLI app with shards, .make.lua, flake.nix, specs, and release hooks",
  language = "crystal",
  framework = "cli",
  tags = { "builtin", "crystal", "cli" },
  nix_packages = [[
            pkgs.crystal
            pkgs.shards]],
})
