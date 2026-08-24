local wing = require("wing")

-- c3c is the compiler and the build tool both, reading project.json, so there is no build-system
-- flavour to choose. C3 compiles through LLVM to a native binary.
wing.template("c3", {
  description = "C3 CLI app with project.json, .make.lua, flake.nix, tests, and release hooks",
  language = "c3",
  framework = "cli",
  tags = { "builtin", "c3", "cli" },
  nix_packages = "            pkgs.c3c",
})
