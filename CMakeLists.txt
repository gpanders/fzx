cmake_minimum_required(VERSION 3.25)
project(fzx VERSION 0.1.0 LANGUAGES CXX)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Using default build type - RelWithDebInfo")
  set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Release" "RelWithDebInfo" "MinSizeRel" "Debug")
endif()

option(BUILD_TESTS "Build tests" OFF)
option(BUILD_BENCHMARKS "Build benchmarks" OFF)

option(ENABLE_LTO "Enable link time optimizations" ON)
option(ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
option(ENABLE_UBSAN "Enable undefined behavior sanitizer" OFF)
option(ENABLE_ASAN "Enable address sanitizer" OFF)
option(ENABLE_TSAN "Enable thread sanitizer" OFF)
if(ENABLE_ASAN AND ENABLE_TSAN)
  message(FATAL_ERROR "ASAN and TSAN are not compatible")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(ENABLE_LTO)
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO ON)
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_MINSIZEREL ON)
endif()

if(ENABLE_CLANG_TIDY)
  find_program(CLANG_TIDY clang-tidy)
  if(CLANG_TIDY)
    set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY}")
  endif()
endif()

find_package(Threads REQUIRED)
find_package(fmt REQUIRED) # TODO: remove fmt dependency
find_package(Lua 5.1 EXACT REQUIRED)
if(BUILD_TESTS)
  find_package(Catch2 3 REQUIRED)
endif()
if(BUILD_BENCHMARKS)
  find_package(benchmark REQUIRED)
endif()

if(ENABLE_UBSAN OR ENABLE_ASAN OR ENABLE_TSAN)
  add_compile_options(-fno-omit-frame-pointer -fno-optimize-sibling-calls)
endif()
if(ENABLE_UBSAN)
  add_compile_options(-fsanitize=undefined)
  add_link_options(-fsanitize=undefined)
endif()
if(ENABLE_ASAN)
  add_compile_options(-fsanitize=address)
  add_link_options(-fsanitize=address)
endif()
if(ENABLE_TSAN)
  add_compile_options(-fsanitize=thread)
  add_link_options(-fsanitize=thread)
endif()

add_compile_options(-Wall -Wextra -march=native)
set(compile_options
  -Werror=unused-result
  -Werror=uninitialized
  -Werror=maybe-uninitialized
  -Werror=strict-aliasing
  -Werror=pointer-arith
  -Werror=vla)
include(CheckCXXCompilerFlag)
foreach(option ${compile_options})
  string(TOUPPER "HAS${option}" option_name)
  string(REGEX REPLACE "[=-]" "_" option_name "${option_name}")
  check_cxx_compiler_flag("${option}" ${option_name})
  if(${option_name})
    add_compile_options($<$<CONFIG:Debug>:${option}>)
  endif()
endforeach()

# Disable DEBUG_ASSERT and enable ASSUME in release builds
add_compile_definitions($<$<CONFIG:Release,RelWithDebInfo,MinSizeRel>:FZX_OPTIMIZE>)

file(GLOB_RECURSE LIB_FILES CONFIGURE_DEPENDS RELATIVE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/fzx/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/fzx/*.hpp")
file(GLOB_RECURSE TERM_FILES CONFIGURE_DEPENDS RELATIVE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/fzx/term/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/fzx/term/*.hpp")
file(GLOB_RECURSE NVIM_FILES CONFIGURE_DEPENDS RELATIVE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/fzx/nvim/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/fzx/nvim/*.hpp")
list(REMOVE_ITEM LIB_FILES "${TERM_FILES}")
list(REMOVE_ITEM LIB_FILES "${NVIM_FILES}")

add_library(libfzx STATIC "${LIB_FILES}")
set_property(TARGET libfzx PROPERTY OUTPUT_NAME fzx)
set_property(TARGET libfzx PROPERTY POSITION_INDEPENDENT_CODE ON)
target_include_directories(libfzx PUBLIC src)
target_link_libraries(libfzx PUBLIC Threads::Threads fmt::fmt)

add_executable(fzx "${TERM_FILES}")
target_link_libraries(fzx PRIVATE libfzx)

add_library(fzxnvim SHARED "${NVIM_FILES}")
set_property(TARGET fzxnvim PROPERTY OUTPUT_NAME fzx)
set_property(TARGET fzxnvim PROPERTY PREFIX "")
target_link_libraries(fzxnvim PRIVATE libfzx)
target_include_directories(fzxnvim PRIVATE src "${LUA_INCLUDE_DIR}")

if(BUILD_TESTS)
  file(GLOB_RECURSE TEST_FILES CONFIGURE_DEPENDS RELATIVE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/test/*.hpp")
  add_executable(test "${TEST_FILES}")
  target_link_libraries(test PRIVATE libfzx Catch2::Catch2)
endif()

if(BUILD_BENCHMARKS)
  file(GLOB_RECURSE BENCHMARK_FILES CONFIGURE_DEPENDS RELATIVE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/benchmark/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/benchmark/*.hpp")
  add_executable(benchmark "${BENCHMARK_FILES}")
  target_link_libraries(benchmark PRIVATE libfzx benchmark::benchmark)
endif()
