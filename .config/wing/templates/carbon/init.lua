local wing = require("wing")

-- This template is a logical unit, not just a pile of files. What it generates assumes the flake's
-- dev shell: `.env.lua` brings it up and `.make.lua` runs the toolchain it provides.
--
-- Carbon leans on that harder than the other templates do. There is no released compiler to
-- install from a package manager -- upstream publishes prebuilt nightlies and nothing else -- so
-- without nix the generated project has no way to get a toolchain at all. Saying so at generation
-- time is the whole value of this hook.

wing.on.check(function(ctx)
  if wing.sys.has("nix") then
    return
  end
  wing.warn("nix is not installed, so the flake dev shell and .env.lua will not work here")

  if not wing.sys.has("carbon") then
    wing.warn("  and carbon is not on $PATH either, so `make build` has nothing to build with")
    wing.warn("  carbon ships as a prebuilt nightly tarball; the flake is what unpacks one")
  end
end)
