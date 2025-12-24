cmake_minimum_required(VERSION 3.22)
project(llama)

# Set C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Use absolute paths since we're in android/app/src/main/cpp
set(LLAMA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../../llama.cpp")

# Get all C++ source files from llama.cpp/src
file(GLOB LLAMA_SOURCES
    "${LLAMA_ROOT}/src/*.cpp"
)

# Get all C++ source files from llama.cpp/common (utilities)
file(GLOB LLAMA_COMMON_SOURCES
    "${LLAMA_ROOT}/common/*.cpp"
)

message(STATUS "LLAMA_ROOT: ${LLAMA_ROOT}")
message(STATUS "Found ${CMAKE_CFG_INTDIR} sources: ${LLAMA_SOURCES}")
message(STATUS "Found common sources: ${LLAMA_COMMON_SOURCES}")

# Create the shared library
add_library(llama SHARED
    ${LLAMA_SOURCES}
    ${LLAMA_COMMON_SOURCES}
)

# Include directories
target_include_directories(llama PRIVATE
    ${LLAMA_ROOT}/include
    ${LLAMA_ROOT}/src
    ${LLAMA_ROOT}/common
)

# Add necessary flags for Android
target_compile_options(llama PRIVATE
    -fPIC
    -Wall
    -O3
)

# Link with common libraries
target_link_libraries(llama
    android
    log
)


