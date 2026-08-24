-- {{kebab_name}}'s build, as recipes. This replaced the Makefile; there is no other.
--
--   make            the recipes, with what each of them says it does
--   make build      the binary
--   make test       the suite
--   make verify     the whole local gate
--
-- At an oslo prompt in this directory `make` is enough; everywhere else it is `oslo make`.
-- CI has no oslo, so it calls the language's own tool -- nothing here is on the release path.

local make = oslo.make

-- Odin has no manifest file to keep a version in, so the version is the latest git tag --
-- which is exactly what `make release` creates. Before the first release there is nothing to
-- report, and "0.0.0" says so rather than inventing a number.
local NAME = "{{kebab_name}}"
local VERSION = (function()
  local tag = oslo.run{ "git", "describe", "--tags", "--abbrev=0", capture = true }
  if not tag.ok then return "0.0.0" end
  return (tag.out or ""):match("^%s*v?([^%s]+)") or "0.0.0"
end)()
local PREFIX = os.getenv("PREFIX") or (os.getenv("HOME") .. "/.local")

------------------------------------------------------------------ what was built

local function dim(text)
  return oslo.ui.style(text, { dim = true })
end

local function line(label, value)
  print(dim(oslo.ui.pad(label, 8)) .. value)
end

-- `1524720` -> `1,524,720`. A number this long is read in groups or not at all.
local function grouped(n)
  local text = tostring(math.floor(n))
  local out = text:sub(-3)
  local at = #text - 3
  while at > 0 do
    out = text:sub(math.max(1, at - 2), at) .. "," .. out
    at = at - 3
  end
  return out
end

-- Asked of the ELF, not assumed. `ldd` is not enough on its own: it prints "statically linked" for
-- a binary that still carries an INTERP and will not start.
local function linkage(path)
  local segments = oslo.run{ "readelf", "-l", path, capture = true }
  if not segments.ok then return nil end
  local dynamic = oslo.run{ "readelf", "-d", path, capture = true }
  if (segments.out or ""):find("program interpreter") or (dynamic.out or ""):find("NEEDED") then
    return "dynamic"
  end
  return "static"
end

-- What was built, how big it is, and whether it needs anything on the target machine. Silent when
-- the artifact is not there, so a recipe that builds nothing does not pretend it did.
local function report(path)
  local stat = oslo.fs.stat(path)
  if not stat then return end
  local megabytes = ("%.2f MB"):format(stat.size / 1048576)

  print("")
  print(oslo.ui.title(("%s %s   %s"):format(NAME, VERSION, megabytes)))
  line("binary", path)
  -- Bytes beside megabytes: `1.45 MB` cannot be subtracted from last week's `1.42 MB` to get one.
  line("size", megabytes .. dim("   " .. grouped(stat.size) .. " bytes"))

  local kind = linkage(path)
  if kind == "static" then
    line("linking", oslo.ui.style("✓ static", { fg = "green" }) ..
                    dim("   no runtime dependencies"))
  elseif kind == "dynamic" then
    line("linking", oslo.ui.style("dynamic", { fg = "yellow" }) ..
                    dim("   needs a matching libc on the target machine"))
  end
  print("")
end

-- The same, for artifacts whose exact path the build system decides. Walked with find rather than
-- globbed: oslo's `**` matches a single directory level, and build trees nest deeper than that.
local function report_found(root, pattern)
  local found = oslo.run{ "find", root, "-type", "f", "-name", pattern, capture = true }
  for path in (found.out or ""):gmatch("[^\n]+") do
    report(path)
    return
  end
end


make.recipe{ name = "version", desc = "what this checkout calls itself",
             run = function() print(("%s v%s"):format(NAME, VERSION)) end }

local function need(tool, why)
  assert(oslo.run{ "sh", "-c", "command -v " .. tool, capture = true }.ok, why)
end

make.recipe{
  name = "release",
  desc = "cut a version: --type patch | minor | major | M.m.p",
  params = { { "--type", desc = "patch | minor | major | M.m.p" } },
  run = function(a)
    need("git-rel", "git-rel is not installed; install it first")
    assert(type(a.type) == "string",
           "which release? make release --type patch|minor|major|M.m.p")
    sh.git("rel", a.type)
  end,
}

make.recipe{
  name = "changelog",
  desc = "regenerate CHANGELOG.md",
  run = function()
    need("git-cliff", "git-cliff is not installed; install it first")
    sh.git("cliff", "-o", "CHANGELOG.md")
  end,
}

------------------------------------------------------------------ configuration

-- A project that carries its own configuration keeps it in `config/`, and this is what installs it:
-- `config/*` lands in `~/.config/{{kebab_name}}/*`. Nothing to install is not a failure -- most
-- projects have no config/ at all, and this says so and stops.
local function project_root()
  -- Asked of git rather than assumed from the working directory, so `make configs` installs this
  -- project's configuration from anywhere in the tree. Outside a repository there is nothing to
  -- ask, and where the command was run is the best answer available.
  local top = oslo.run{ "git", "rev-parse", "--show-toplevel", capture = true }
  local path = top.ok and (top.out or ""):match("^%s*(.-)%s*$") or ""
  if path ~= "" then return path end
  return oslo.sys.pwd()
end

make.recipe{
  name = "configs",
  desc = "install config/ into $XDG_CONFIG_HOME/{{kebab_name}}",
  params = { { "--dest", desc = "somewhere other than the config directory" } },
  run = function(a)
    local top = project_root()
    local source = top .. "/config"
    if not oslo.fs.stat(source .. "/") then
      print("no config/ in " .. top .. "; nothing to install")
      return
    end
    assert(oslo.run{ "sh", "-c", "command -v rsync", capture = true }.ok,
           "rsync is not installed; install it first")

    local dest = a.dest
    if not dest then
      local config = os.getenv("XDG_CONFIG_HOME")
      if not config or config == "" then config = os.getenv("HOME") .. "/.config" end
      dest = config .. "/" .. NAME
    end
    sh.mkdir("-p", dest)

    -- One entry at a time, each mirrored with --delete, rather than one --delete over the whole
    -- tree: the destination is also where the user keeps their own edits, and a tree-wide mirror
    -- would take those with it.
    local synced = 0
    for _, path in ipairs(oslo.fs.glob(source .. "/*")) do
      local name = oslo.path.name(path)
      if oslo.fs.stat(path .. "/") then
        sh.mkdir("-p", dest .. "/" .. name)
        sh.rsync("-a", "--delete", path .. "/", dest .. "/" .. name .. "/")
      else
        sh.rsync("-a", path, dest .. "/" .. name)
      end
      synced = synced + 1
    end
    print(("%d entr%s -> %s"):format(synced, synced == 1 and "y" or "ies", dest))
  end,
}

-------------------------------------------------------------------------- odin

-- `odin` is the compiler and the build system; these recipes only drive it.
local SRC = "src"
local BIN = "target/" .. NAME

make.recipe{
  name = "build",
  desc = "the binary",
  run = function()
    sh.mkdir("-p", "target")
    sh.odin("build", SRC, "-out:" .. BIN, "-o:speed")
    report(BIN)
  end,
}
make.alias("b", "build")

make.recipe{
  name = "dev",
  desc = "the fast inner loop: an unoptimised build",
  run = function()
    sh.mkdir("-p", "target")
    sh.odin("build", SRC, "-out:" .. BIN)
  end,
}

make.recipe{
  name = "run",
  desc = "run it: bare words pass through, flags go in --args",
  deps = { "dev" },
  params = { { "--args", desc = "a quoted argument string, for arguments starting with a dash" } },
  run = function(a)
    local argv = {}
    for _, word in ipairs(a.rest or {}) do argv[#argv + 1] = word end
    if type(a.args) == "string" then
      for word in a.args:gmatch("%S+") do argv[#argv + 1] = word end
    end
    sh["./" .. BIN](table.unpack(argv))
  end,
}
make.alias("r", "run")

make.recipe{ name = "test", desc = "the suite",
             run = function() sh.odin("test", SRC) end }
make.alias("t", "test")

make.recipe{ name = "check", desc = "type-check without producing a binary",
             run = function() sh.odin("check", SRC) end }
make.alias("vet", "check")

-- odinfmt ships with ols rather than with odin, and ols is not in the dev shell: it does not build
-- against the Odin the flake pins. So formatting is reported as unavailable rather than asserted --
-- a gate that cannot run is not a gate that failed, and failing `verify` over a missing optional
-- tool teaches people to skip `verify`.
local function have_odinfmt()
  if oslo.run{ "sh", "-c", "command -v odinfmt", capture = true }.ok then
    return true
  end
  print("odinfmt is not installed (it comes with ols); skipping")
  return false
end

make.recipe{ name = "fmt", desc = "format the sources",
             run = function() if have_odinfmt() then sh.odinfmt(SRC, "-w") end end }

-- odinfmt has no check mode, so the sources are formatted in a copy and compared.
make.recipe{
  name = "fmt-check",
  desc = "fail if anything is unformatted",
  run = function()
    if not have_odinfmt() then return end
    local scratch = "/tmp/" .. NAME .. "-odinfmt"
    sh.rm("-rf", scratch)
    sh.cp("-r", SRC, scratch)
    sh.odinfmt(scratch, "-w")
    local same = oslo.run{ "diff", "-r", SRC, scratch }
    sh.rm("-rf", scratch)
    assert(same.ok, "odinfmt needed: run `make fmt`")
  end,
}

make.recipe{ name = "clean", desc = "remove every build output",
             run = function() sh.rm("-rf", "target") end }

make.recipe{ name = "compile", desc = "clean, then build", deps = { "clean", "build" } }
make.alias("c", "compile")

make.recipe{
  name = "install",
  desc = "put the binary in $PREFIX/bin",
  deps = { "build" },
  run = function()
    sh.install("-d", PREFIX .. "/bin")
    sh.install("-m", "0755", BIN, PREFIX .. "/bin/" .. NAME)
    print("installed -> " .. PREFIX .. "/bin/" .. NAME)
  end,
}

make.recipe{ name = "uninstall", desc = "take it back out of $PREFIX/bin",
             run = function() sh.rm("-f", PREFIX .. "/bin/" .. NAME) end }

make.recipe{ name = "verify", desc = "the whole local gate",
             deps = { "fmt-check", "check", "test" } }
make.alias("v", "verify")
