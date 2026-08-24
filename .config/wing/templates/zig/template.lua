local wing = require("wing")

wing.template("zig", {
  description = "Zig CLI app with build.zig, .make.lua, flake.nix, and release hooks",
  language = "zig",
  framework = "cli",
  tags = { "builtin", "zig", "cli" },
  nix_packages = [[
            pkgs.zig
            pkgs.zls]],
})
