# The build system. What this project is made of lives here; how you drive it lives in .make.lua.
cmake_minimum_required(VERSION 3.20)
project({{kebab_name}} VERSION 0.1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library({{snake_name}} src/{{snake_name}}.c)
target_include_directories({{snake_name}} PUBLIC include)
target_compile_options({{snake_name}} PRIVATE -Wall -Wextra -Wpedantic)

option({{NAME}}_ENABLE_TESTS "Build the tests" ON)
if({{NAME}}_ENABLE_TESTS)
  enable_testing()
  add_executable(basic_test test/basic_test.c)
  target_link_libraries(basic_test PRIVATE {{snake_name}})
  add_test(NAME basic_test COMMAND basic_test)
endif()
