-- The build system. What this project is made of lives here; how you drive it lives in .make.lua.
set_project("{{kebab_name}}")
set_version("0.1.0")
set_xmakever("2.8.5")

set_languages("c17")
set_warnings("all", "extra", "pedantic")
set_config("builddir", "build")

-- The toolchain is chosen at configure time, not pinned here: `make config --toolchain clang`.
target("{{snake_name}}")
    set_kind("static")
    add_files("src/**.c")
    add_includedirs("include", {public = true})

target("basic_test")
    set_kind("binary")
    set_default(false)
    add_files("test/basic_test.c")
    add_deps("{{snake_name}}")
    add_tests("basic")
