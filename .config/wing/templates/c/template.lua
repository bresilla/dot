local wing = require("wing")

-- The same two build systems the C++ template offers, over C sources. gcc and clang are the
-- compilers; the flavour is the build system, and `make config --toolchain clang` is the compiler.
--
-- Zig is deliberately not a flavour. It compiles C perfectly well, but its build system assumes
-- zig-as-compiler and does not drive a host gcc or clang -- which is exactly the choice this
-- template exists to give. Zig stays the build system for Zig.
wing.template("c", {
  description = "C library starter with xmake or CMake, flake.nix, tests, and release hooks",
  language = "c",
  framework = "library",
  tags = { "builtin", "c", "library" },
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
