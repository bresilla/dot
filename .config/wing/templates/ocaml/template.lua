local wing = require("wing")

-- dune is OCaml's build system, so there is no build-system flavour to choose. ocamlformat is
-- driven through dune's own @fmt alias rather than invoked directly.
wing.template("ocaml", {
  description = "OCaml library and CLI with dune, .make.lua, flake.nix, tests, and release hooks",
  language = "ocaml",
  framework = "cli",
  tags = { "builtin", "ocaml", "cli" },
  nix_packages = [[
            pkgs.ocaml
            pkgs.dune_3
            pkgs.ocamlformat
            pkgs.ocamlPackages.ocaml-lsp]],
})
