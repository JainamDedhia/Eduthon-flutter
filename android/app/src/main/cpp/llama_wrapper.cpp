// Simple wrapper to ensure llama library symbols are properly exported
// This file exists to create a shared library that links against llama
#include "llama.cpp/include/llama.h"

// Intentionally empty - the actual library linking happens via CMakeLists.txt
// This file just ensures the wrapper library gets created properly
extern "C" {
    // The llama symbols from llama.cpp are automatically exported
    // because we link against the llama library in CMakeLists.txt
}
