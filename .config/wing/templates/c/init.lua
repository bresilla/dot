local wing = require("wing")

-- This template is a logical unit, not just a pile of files. What it generates assumes the flake's
-- dev shell: `.env.lua` brings it up and `.make.lua` runs the toolchain it provides.
--
-- So the check is not "is nix here" on its own. If nix is here, the flake supplies everything and
-- there is nothing to say. If it is not, the generated project still works -- but only if the
-- toolchain happens to be on $PATH, and that is worth knowing now rather than at the first
-- `make build`.
--
-- Note what this deliberately does NOT do: leave flake.nix out. `.env.lua` calls nix_develop(), so
-- a project without the flake is a project with a broken directory environment. The files are a
-- set, and warning is the honest answer where dropping one would not be.

-- The build system is the flavour, so what to look for depends on which one was asked for.
local function build_tool(flavour)
  if flavour == "cmake" then
    return "cmake"
  end
  return "xmake"
end

wing.on.check(function(ctx)
  if wing.sys.has("nix") then
    return
  end
  wing.warn("nix is not installed, so the flake dev shell and .env.lua will not work here")

  local missing = {}
  for _, tool in ipairs({ build_tool(ctx.flavour), "clang" }) do
    if not wing.sys.has(tool) then
      missing[#missing + 1] = tool
    end
  end
  -- The static build wants a musl toolchain the flake exports; without nix there is none.
  wing.warn("  `make build` links against musl from the flake, which is not available here")
  if #missing > 0 then
    wing.warn("  and these are not on $PATH either: " .. table.concat(missing, ", "))
  end
end)
