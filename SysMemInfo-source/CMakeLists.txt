cmake_minimum_required(VERSION 3.21)
project(SysMemInfo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(RED4EXT_HEADER_ONLY ON CACHE BOOL "" FORCE)
add_subdirectory(deps/RED4ext.SDK)

add_library(SysMemInfo SHARED src/Main.cpp)
target_link_libraries(SysMemInfo PRIVATE RED4ext::SDK psapi)
target_compile_definitions(SysMemInfo PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
