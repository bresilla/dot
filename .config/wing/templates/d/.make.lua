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

-- The name is fixed at generation time; the version comes from dub.json, the language's own
-- manifest and the file `veri` rewrites when `make release` cuts a version. One source, and it is not a file wing invented.
local NAME = "{{kebab_name}}"
local VERSION = ((oslo.fs.read("dub.json") or ""):match('"version"%s*:%s*"([^"]+)"')) or "0.0.0"
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

------------------------------------------------------------------------------ d

-- dub is the build system; these recipes only drive it. What this project depends on and how it is
-- configured lives in dub.json.
--
-- The compiler is a choice, not a flavour: ldc2, dmd and gdc all build the same dub project.
local COMPILER = os.getenv("DC") or "ldc2"

local function compiler(a)
  return a and a.compiler or COMPILER
end

local COMPILER_PARAM = { "--compiler", desc = "ldc2, dmd or gdc" }

make.recipe{
  name = "build",
  desc = "the binary: --compiler ldc2 | dmd | gdc",
  params = { COMPILER_PARAM },
  run = function(a)
    sh.dub("build", "--compiler=" .. compiler(a), "--build=release")
    report(NAME)
  end,
}
make.alias("b", "build")

make.recipe{
  name = "run",
  desc = "run it: bare words pass through, flags go in --args",
  params = { COMPILER_PARAM,
             { "--args", desc = "a quoted argument string, for arguments starting with a dash" } },
  run = function(a)
    local argv = { "run", "--compiler=" .. compiler(a), "--build=debug", "--" }
    for _, word in ipairs(a.rest or {}) do argv[#argv + 1] = word end
    if type(a.args) == "string" then
      for word in a.args:gmatch("%S+") do argv[#argv + 1] = word end
    end
    sh.dub(table.unpack(argv))
  end,
}
make.alias("r", "run")

make.recipe{
  name = "test",
  desc = "the unittests: --compiler ldc2 | dmd | gdc",
  params = { COMPILER_PARAM },
  run = function(a) sh.dub("test", "--compiler=" .. compiler(a)) end,
}
make.alias("t", "test")

make.recipe{
  name = "cover",
  desc = "the unittests, with coverage written to *.lst",
  params = { COMPILER_PARAM },
  run = function(a)
    sh.dub("test", "--compiler=" .. compiler(a), "--build=unittest-cov")
  end,
}

-- Sources this project owns, which is what the formatter and the linter are pointed at.
local function sources()
  local found = oslo.run{ "find", "source", "-type", "f", "-name", "*.d", capture = true }
  local files = {}
  for path in (found.out or ""):gmatch("[^\n]+") do files[#files + 1] = path end
  table.sort(files)
  return files
end

make.recipe{ name = "fmt", desc = "format the source",
             run = function() sh.dfmt("--inplace", table.unpack(sources())) end }

-- dfmt has no check mode, so each file is formatted in a copy and compared.
make.recipe{
  name = "fmt-check",
  desc = "fail if anything is unformatted",
  run = function()
    local unformatted = {}
    for _, path in ipairs(sources()) do
      local scratch = "/tmp/" .. NAME .. "-dfmt-" .. path:gsub("/", "-")
      sh.cp(path, scratch)
      sh.dfmt("--inplace", scratch)
      if not oslo.run{ "cmp", "-s", path, scratch }.ok then
        unformatted[#unformatted + 1] = path
      end
      sh.rm("-f", scratch)
    end
    assert(#unformatted == 0, "dfmt needed on: " .. table.concat(unformatted, " "))
  end,
}

make.recipe{ name = "check", desc = "lint the source",
             run = function() sh.dscanner("--styleCheck", "source") end }
make.alias("vet", "check")

make.recipe{
  name = "clean",
  desc = "remove every build output",
  run = function()
    sh.dub("clean")
    sh.rm("-rf", NAME, ".dub")
    for _, path in ipairs(oslo.fs.glob("*.lst")) do sh.rm("-f", path) end
  end,
}

make.recipe{ name = "compile", desc = "clean, then build", deps = { "clean", "build" } }
make.alias("c", "compile")

make.recipe{
  name = "install",
  desc = "put the binary in $PREFIX/bin",
  deps = { "build" },
  run = function()
    sh.install("-d", PREFIX .. "/bin")
    sh.install("-m", "0755", NAME, PREFIX .. "/bin/" .. NAME)
    print("installed -> " .. PREFIX .. "/bin/" .. NAME)
  end,
}

make.recipe{ name = "uninstall", desc = "take it back out of $PREFIX/bin",
             run = function() sh.rm("-f", PREFIX .. "/bin/" .. NAME) end }

make.recipe{ name = "verify", desc = "the whole local gate",
             deps = { "fmt-check", "check", "test" } }
make.alias("v", "verify")
