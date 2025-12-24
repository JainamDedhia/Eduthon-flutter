cmake_minimum_required(VERSION 3.22)
project(llama_native)

# Llama.cpp requires C++20
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configure llama.cpp build options - DISABLE EVERYTHING EXTRA
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE) # Avoid architecture specific flags that might break cross-compile
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
set(LLAMA_STATIC OFF CACHE BOOL "" FORCE)

# Point to the root llama.cpp directory
set(LLAMA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../llama.cpp")

# Add llama.cpp as a subdirectory
add_subdirectory("${LLAMA_ROOT}" llama_build)


