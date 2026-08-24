local wing = require("wing")

wing.template("nim", {
  description = "Nim CLI app with nimble, .make.lua, flake.nix, tests, and release hooks",
  language = "nim",
  framework = "cli",
  tags = { "builtin", "nim", "cli" },
  nix_packages = [[
            pkgs.nim
            pkgs.nimble
            pkgs.nimlsp
            pkgs.nimlangserver]],
})
