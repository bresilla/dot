local wing = require("wing")

-- Two build systems, one set of sources. The flavour decides which build file the project gets and
-- which tools the dev shell brings; the sources in base/ do not know or care which one built them.
--
-- Zig is deliberately not a flavour here. It can compile C and C++, but its build system assumes
-- zig-as-compiler, and driving a host gcc or clang toolchain is not something it does -- which is
-- the whole point of offering a choice of compiler. Zig stays the build system for Zig.
wing.template("cpp", {
  description = "C++ library starter with xmake or CMake, flake.nix, tests, and release hooks",
  language = "cpp",
  framework = "library",
  tags = { "builtin", "cpp", "library" },
  default_flavour = "xmake",

  flavours = {
    {
      name = "xmake",
      nix_packages = [[
            pkgs.xmake
            pkgs.gcc
            pkgs.clang-tools
            pkgs.gdb]],
      environment = "xmake drives the build, clang by default. `make static` links a musl binary that needs nothing on the target machine.",
    },
    {
      name = "cmake",
      nix_packages = [[
            pkgs.cmake
            pkgs.ninja
            pkgs.gcc
            pkgs.clang-tools
            pkgs.gdb]],
      environment = "CMake drives the build, clang by default and Ninja when present. `make static` links a musl binary that needs nothing on the target machine.",
    },
  },
})
