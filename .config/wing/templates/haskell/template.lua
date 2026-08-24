local wing = require("wing")

-- Cabal is Haskell's build system, so there is no build-system flavour to choose. GHC is the
-- compiler and cabal drives it.
wing.template("haskell", {
  description = "Haskell library and CLI with cabal, .make.lua, flake.nix, tests, and release hooks",
  language = "haskell",
  framework = "cli",
  tags = { "builtin", "haskell", "cli" },
  nix_packages = [[
            pkgs.ghc
            pkgs.cabal-install
            pkgs.ormolu
            pkgs.hlint]],
})
