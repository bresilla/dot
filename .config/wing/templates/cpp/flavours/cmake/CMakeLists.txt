cmake_minimum_required(VERSION 3.15)

if(DEFINED COMPILER AND NOT "${COMPILER}" STREQUAL "")
    if("${COMPILER}" STREQUAL "gcc")
        set(CMAKE_CXX_COMPILER g++)
    elseif("${COMPILER}" STREQUAL "clang")
        set(CMAKE_CXX_COMPILER clang++)
    endif()
endif()

project({{kebab_name}} VERSION 0.1.0 LANGUAGES CXX)
string(REPLACE "-" "_" PROJECT_TARGET "${PROJECT_NAME}")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(${PROJECT_TARGET} STATIC
    src/{{snake_name}}/{{snake_name}}.cpp
)
target_include_directories(${PROJECT_TARGET} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_compile_options(${PROJECT_TARGET} PRIVATE -Wall -Wextra -Wpedantic)
add_library(${PROJECT_TARGET}::${PROJECT_TARGET} ALIAS ${PROJECT_TARGET})

option(${PROJECT_TARGET}_BUILD_EXAMPLES "Build examples" ON)
option(${PROJECT_TARGET}_ENABLE_TESTS "Enable tests" ON)

if(${PROJECT_TARGET}_ENABLE_TESTS)
    enable_testing()
    add_executable(${PROJECT_TARGET}_test test/basic_test.cpp)
    target_link_libraries(${PROJECT_TARGET}_test PRIVATE ${PROJECT_TARGET})
    add_test(NAME ${PROJECT_TARGET}_test COMMAND ${PROJECT_TARGET}_test)
endif()

install(DIRECTORY include/ DESTINATION include)
install(TARGETS ${PROJECT_TARGET} EXPORT ${PROJECT_TARGET}Targets)
