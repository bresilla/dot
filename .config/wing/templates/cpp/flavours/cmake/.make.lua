-- {{kebab_name}}'s tasks. This is not the build system -- {{builtin_flavour}} is. These recipes
-- only drive it, so anything about how this project compiles (standard, warnings, targets,
-- packages) belongs in the build file, and anything about how you drive it belongs here.
--
--   make            the recipes, with what each of them says it does
--   make config     configure the build tree: --toolchain clang | gcc
--   make build      the library
--   make test       the suite
--
-- At an oslo prompt in this directory `make` is enough; everywhere else it is `oslo make`.
-- CI has no oslo, so it calls the build system directly -- the same commands these recipes run.

local make = oslo.make

-- The name is fixed at generation time; the version comes from CMakeLists.txt, the language's own
-- manifest and the file `veri` rewrites when `make release` cuts a version. One source, and it is not a file wing invented.
local NAME = "{{kebab_name}}"
local VERSION = ((oslo.fs.read("CMakeLists.txt") or ""):match('project%(.-VERSION%s+([%d%.]+)')) or "0.0.0"
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

local TOOLCHAIN = os.getenv("TOOLCHAIN")

make.recipe{ name = "version", desc = "what this checkout calls itself",
             run = function() print(("%s v%s"):format(NAME, VERSION)) end }

local function need(tool, why)
  assert(oslo.run{ "sh", "-c", "command -v " .. tool, capture = true }.ok, why)
end

-- Sources this project owns, which is what clang-format is pointed at. The formatter is not the
-- build system's job in either flavour, so it lives here in both.
local function sources()
  local found = oslo.run{ "find", "src", "include", "test", "-type", "f",
                          "(", "-name", "*.c", "-o", "-name", "*.h",
                          "-o", "-name", "*.cpp", "-o", "-name", "*.hpp", ")",
                          capture = true }
  local files = {}
  for path in (found.out or ""):gmatch("[^\n]+") do files[#files + 1] = path end
  table.sort(files)
  return files
end

make.recipe{ name = "fmt", desc = "format the sources",
             run = function() sh["clang-format"]("-i", table.unpack(sources())) end }

make.recipe{ name = "fmt-check", desc = "fail if anything is unformatted",
             run = function()
               sh["clang-format"]("--dry-run", "--Werror", table.unpack(sources()))
             end }

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

------------------------------------------------------------------- toolchain

-- musl and static by default: what you build here is what you can copy to another machine. A
-- binary linked against the host libc stops working the moment that libc differs.
--
-- The default compiler differs by language and it is not a preference. musl-clang is the host
-- clang pointed at musl, and it carries no C++ standard library -- fine for C, and it dies on the
-- first `#include <string>`. The gcc that nixpkgs builds against musl has one. So C defaults to
-- clang, C++ defaults to gcc, and both are static.
--
-- Both toolchains arrive from the flake as paths rather than packages: musl headers on the default
-- search path make an ordinary build compile against musl and link against glibc, which succeeds
-- without a word and crashes at startup.
local DEFAULT_TOOLCHAIN = "gcc"

local function musl_root(name, why)
  local root = os.getenv(name) or ""
  assert(root ~= "", why .. " -- " .. name .. " comes from the dev shell: nix develop")
  return root
end

-- Returns cc, cxx, and whether the result will be static.
local function toolchain(a)
  local chain = a and a.toolchain or os.getenv("TOOLCHAIN") or DEFAULT_TOOLCHAIN
  if a and a.dynamic then
    -- The fast inner loop: the host toolchain, linked the ordinary way.
    if chain == "gcc" then return "gcc", "g++", false end
    return "clang", "clang++", false
  end
  if chain == "clang" then
    assert(not true,
           "musl-clang has no C++ standard library, so a static clang build cannot work here.\n" ..
           "Use `--toolchain gcc` for the static build, or `--dynamic` to iterate with clang.")
    local root = musl_root("MUSL_CLANG", "the static clang build needs musl")
    return root .. "/bin/musl-clang", root .. "/bin/musl-clang", true
  end
  local root = musl_root("MUSL_CC", "the static build needs a musl gcc")
  return root .. "/bin/gcc", root .. "/bin/g++", true
end

-- Asked of the ELF, not assumed. "static" quietly coming out dynamic is only ever noticed by
-- whoever the binary fails for. `ldd` is not enough: it prints "statically linked" for a binary
-- that still carries an INTERP and will not start.
local function assert_static(path)
  local segments = oslo.run{ "readelf", "-l", path, capture = true }
  local dynamic = oslo.run{ "readelf", "-d", path, capture = true }
  assert(segments.ok, path .. " was not produced, or readelf could not read it")
  assert(not (segments.out or ""):find("program interpreter"),
         path .. " requests a dynamic loader; it is not static")
  assert(not (dynamic.out or ""):find("NEEDED"),
         path .. " has NEEDED entries; it is not static")
end

local function check_binaries(root)
  local found = oslo.run{ "find", root, "-type", "f", "-name", "*_test", capture = true }
  local checked = 0
  for path in (found.out or ""):gmatch("[^\n]+") do
    assert_static(path)
    report(path)
    checked = checked + 1
  end
  assert(checked > 0, "no binary was produced, so nothing was checked")
end

local TOOLCHAIN_PARAMS = {
  { "--toolchain", desc = "clang or gcc; " .. DEFAULT_TOOLCHAIN .. " by default" },
  { "--dynamic", desc = "link against the host libc instead, for a faster inner loop" },
}

---------------------------------------------------------------------------- cmake

-- CMake is the build system; these recipes only drive it. Standard, warnings, targets and tests
-- live in CMakeLists.txt.
local BUILD_DIR = os.getenv("BUILD_DIR") or "build"

make.recipe{
  name = "config",
  desc = "configure the build tree: musl and static unless --dynamic",
  params = TOOLCHAIN_PARAMS,
  run = function(a)
    local cc, cxx, static = toolchain(a)
    local argv = { "-S", ".", "-B", BUILD_DIR,
                   "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
                   "-DCMAKE_C_COMPILER=" .. cc,
                   "-DCMAKE_CXX_COMPILER=" .. cxx }
    if static then
      argv[#argv + 1] = "-DCMAKE_BUILD_TYPE=Release"
      argv[#argv + 1] = "-DCMAKE_EXE_LINKER_FLAGS=-static"
    end
    -- Ninja when it is here, so an incremental build is not a full one.
    if oslo.run{ "sh", "-c", "command -v ninja", capture = true }.ok then
      argv[#argv + 1] = "-GNinja"
    end
    sh.cmake(table.unpack(argv))
  end,
}

local function configured(a)
  if not oslo.fs.stat(BUILD_DIR) then make.run("config") end
end

make.recipe{
  name = "build",
  desc = "the library and its tests, static against musl",
  params = TOOLCHAIN_PARAMS,
  run = function(a)
    configured(a)
    sh.cmake("--build", BUILD_DIR, "--parallel")
    local _, _, static = toolchain(a)
    if static then check_binaries(BUILD_DIR) end
  end,
}
make.alias("b", "build")

make.recipe{
  name = "test",
  desc = "the suite",
  run = function()
    configured()
    sh.cmake("--build", BUILD_DIR, "--parallel")
    sh.ctest("--test-dir", BUILD_DIR, "--output-on-failure")
  end,
}
make.alias("t", "test")

make.recipe{ name = "install", desc = "install into $PREFIX", deps = { "build" },
             run = function() sh.cmake("--install", BUILD_DIR, "--prefix", PREFIX) end }

make.recipe{ name = "clean", desc = "remove the build tree",
             run = function() sh.rm("-rf", BUILD_DIR) end }

make.recipe{ name = "compile", desc = "clean, then build", deps = { "clean", "build" } }
make.alias("c", "compile")

make.recipe{ name = "verify", desc = "the whole local gate", deps = { "fmt-check", "test" } }
make.alias("v", "verify")
