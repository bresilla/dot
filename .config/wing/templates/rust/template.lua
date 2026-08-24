local wing = require("wing")

wing.template("rust", {
  description = "Rust library starter with Cargo, .make.lua, flake.nix, tests, and release hooks",
  language = "rust",
  framework = "library",
  tags = { "builtin", "rust", "library" },
  nix_packages = [[
            pkgs.rustc
            pkgs.cargo
            pkgs.rustfmt
            pkgs.clippy
            pkgs.rust-analyzer]],
})
