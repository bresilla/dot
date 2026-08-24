local wing = require("wing")

-- This template is a logical unit, not just a pile of files. What it generates assumes the flake's
-- dev shell: `.env.lua` brings it up and `.make.lua` runs the toolchain it provides.
--
-- Mojo makes that dependence sharper than most: it is not in any distribution's package manager,
-- so "install it yourself" means fetching Modular's conda package by hand. The flake is the
-- supported route, and this hook says so before the first `make build` finds out.

wing.on.check(function(ctx)
  if wing.sys.has("nix") then
    return
  end
  wing.warn("nix is not installed, so the flake dev shell and .env.lua will not work here")

  if not wing.sys.has("mojo") then
    wing.warn("  and mojo is not on $PATH either, so `make build` has nothing to build with")
    wing.warn("  mojo comes from Modular's conda channel; the flake is what unpacks it")
  end
end)
