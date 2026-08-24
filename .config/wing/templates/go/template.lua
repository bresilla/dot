local wing = require("wing")

wing.template("go", {
  description = "Go CLI app with .make.lua, flake.nix, tests, and release hooks",
  language = "go",
  framework = "cli",
  tags = { "builtin", "go", "cli" },
  nix_packages = [[
            pkgs.go
            pkgs.gopls
            pkgs.gotools
            pkgs.go-tools
            pkgs.delve
            pkgs.golangci-lint
            pkgs.goreleaser]],
})
