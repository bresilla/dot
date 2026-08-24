local wing = require("wing")

-- The template that made flavours worth having. Each one is a different way to get a Python
-- environment, and each brings its own Nix packages and its own note about what `make setup` does.
-- This used to be a `case` in Nim reached by comparing the template's name to "python".
wing.template("python", {
  description = "Python app with a pure Nix default and optional uv, pixi, or micromamba environments",
  language = "python",
  framework = "cli",
  tags = { "builtin", "python", "cli" },
  default_flavour = "nix",

  nix_packages = [[
            (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
              build
              hatchling
              pytest
            ]))
            pkgs.ruff]],

  flavours = {
    {
      name = "nix",
      nix_packages = [[
            (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
              build
              hatchling
              pytest
            ]))
            pkgs.ruff]],
      environment = "Python and all development packages come directly from Nix. No virtual environment is created.",
    },
    {
      name = "uv",
      nix_packages = [[
            pkgs.python3
            pkgs.uv]],
      environment = "Python and uv come from Nix. Run `make setup` to create and sync the local `.venv` managed by uv.",
    },
    {
      name = "pixi",
      nix_packages = "            pkgs.pixi",
      environment = "Pixi comes from Nix. Run `make setup` to create and sync the local `.pixi` environment.",
    },
    {
      name = "micromamba",
      nix_packages = "            pkgs.micromamba",
      environment = "Micromamba comes from Nix. Run `make setup` to create and sync the local `.micromamba` environment.",
    },
  },
})
