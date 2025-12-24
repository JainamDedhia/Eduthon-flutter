# Native Library Issue: libllama.so Not Found

## Problem
The app crashes with the error:
```
Failed to load dynamic library 'libllama.so': dlopen failed: library "libllama.so" not found
```

This occurs when trying to use the Llama model for AI summaries and quizzes on Android.

## Root Cause
The `llama_cpp_dart` Flutter package requires native C++ libraries (`libllama.so` on Android) to run the Llama language model. These native libraries must be:
1. Compiled for Android ARM architecture
2. Bundled into the APK/AAB during the build process

Currently, these libraries are **not included** in your Android build configuration.

## Solutions

### Solution 1: Use Pre-compiled Native Libraries (RECOMMENDED)
The `llama_cpp_dart` package should provide pre-compiled binaries. Ensure they're included:

**Steps:**
1. Update your `pubspec.yaml` to ensure you have the latest `llama_cpp_dart`:
   ```yaml
   llama_cpp_dart: ^0.1.2
   ```

2. Run `flutter pub get` to fetch dependencies
3. Check if native libraries exist:
   ```bash
   find . -name "libllama.so" -o -name "*.so"
   ```

4. If not found, the package doesn't include pre-built Android binaries. Proceed to Solution 2.

### Solution 2: Compile Native Libraries with NDK

**Requirements:**
- Android NDK installed (25.2.9519653 or later recommended)
- CMake (usually comes with Android Studio)
- Sufficient disk space (~5-10 GB)

**Steps:**

#### 2a. Update Android Build Configuration

Edit `android/app/build.gradle.kts`:

```kotlin
android {
    // ... existing config ...
    
    ndkVersion = "28.2.13676358"  // Ensure this is set
    
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    
    defaultConfig {
        // ... existing config ...
        
        externalNativeBuild {
            cmake {
                cppFlags("-std=c++20")
                cFlags("-O3")
                abiFilters("arm64-v8a")  // Minimum required for most modern devices
                // Optional: add more ABIs for broader device support
                // abiFilters("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            }
        }
    }
}
```

#### 2b. Create CMakeLists.txt

Create `android/app/src/main/cpp/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.22)
project(llama_native)

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add llama.cpp as a subdirectory
# You'll need to get the source from: https://github.com/ggerganov/llama.cpp
add_subdirectory(llama.cpp)

# Export the library
add_library(llama SHARED $<TARGET_OBJECTS:llama>)
target_link_libraries(llama llama_common)
```

#### 2c. Get llama.cpp Source

```bash
cd android/app/src/main/cpp
git clone https://github.com/ggerganov/llama.cpp.git
```

#### 2d. Rebuild the APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Solution 3: Use Alternative Pure-Dart Solution (QUICK FIX)

If you don't want to deal with native libraries, use an HTTP-based approach:

**Modify `llm_summary_service.dart`:**

```dart
// Fallback to API-based approach when native library fails
static Future<String> generateSummaryWithLLM({
  required String text,
  required String language,
}) async {
  try {
    // Try native first
    return await _tryNativeGeneration(text, language);
  } catch (e) {
    if (e.toString().contains('libllama.so')) {
      print('⚠️ [LLM] Native library unavailable, using API fallback');
      return await _generateViaAPI(text, language);
    }
    rethrow;
  }
}

static Future<String> _generateViaAPI(String text, String language) async {
  // Use your server API instead of local inference
  // This requires your backend to have an LLM endpoint
  return "Generated via API"; // Implement your API call here
}
```

### Solution 4: Disable LLM and Use Server-only Mode

If offline LLM isn't critical, modify the UI to skip LLM generation when unavailable:

**Edit your screen that shows the error:**

```dart
try {
  summary = await LLMSummaryService.generateSummaryWithLLM(
    text: extractedText,
    language: currentLanguage,
  );
} on Exception catch (e) {
  if (e.toString().contains('libllama.so')) {
    print('ℹ️ Local LLM unavailable, showing error to user');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Local AI mode requires app rebuild. Please use online mode.'),
        backgroundColor: Colors.red,
      ),
    );
    return; // Don't crash, just show message
  }
  rethrow;
}
```

## Testing the Fix

After applying a solution:

1. **Clean build:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Test on device/emulator:**
   ```bash
   flutter run --verbose
   ```

3. **Check logs for:**
   ```
   ✅ [LLM] Llama initialized successfully
   ✨ [LLM] Generation successful - tokens: XXX
   ```

4. **Or you should see helpful error messages:**
   ```
   ❌ [LLM] Native library error
   📱 On Android, this error occurs because libllama.so is not bundled
   🔧 To fix: See NATIVE_LIBRARY_FIX.md
   ```

## Troubleshooting

### "libllama.so not found" persists after rebuild
- Verify NDK is installed: `flutter doctor -v`
- Check `android/app/build.gradle.kts` has correct NDK version
- Try: `flutter clean && flutter pub clean && flutter pub get`
- Rebuild: `flutter build apk --verbose`

### Build fails with CMake errors
- Ensure CMakeLists.txt points to correct llama.cpp path
- Check llama.cpp source is in `android/app/src/main/cpp/llama.cpp`
- Review build output for specific CMake errors

### App still crashes on old devices
- You may have set too few ABI filters
- Add support for more architectures in `abiFilters`
- Rebuild APK

### APK size increased significantly
- This is expected (native libraries add ~100-300 MB to APK)
- Consider using App Bundle format (AAB) for Play Store distribution
- The system will only install the required ABI

## References
- [llama.cpp Build Instructions](https://github.com/ggerganov/llama.cpp#android)
- [Android NDK Documentation](https://developer.android.com/ndk)
- [Flutter NDK Integration](https://docs.flutter.dev/development/add-tos-app/android/faq#how-do-i-build-with-native-code)
- [llama_cpp_dart Package](https://pub.dev/packages/llama_cpp_dart)

## Quick Reference: Expected Log Output

### ✅ Success
```
🤖 [LLM] Using model for summary generation: /data/user/0/com.example.claudetest/app_flutter/summary.gguf
🌐 [LLM] Language: en
ℹ️ [LLM] Android detected - using system libllama.so
🔄 [LLM] Initializing Llama with model: ...
✅ [LLM] Llama initialized successfully
✨ [LLM] Generation successful - tokens: 245
```

### ❌ Failure (Current)
```
⚠️ [LLM] Inference failed: LlamaException: Failed to initialize Llama (Invalid argument(s): Failed to load dynamic library 'libllama.so': dlopen failed: library "libllama.so" not found)
❌ [LLM] Native library error
📱 On Android, this error occurs because libllama.so is not bundled in the APK
🔧 To fix: See NATIVE_LIBRARY_FIX.md
```

---

**Last Updated:** December 24, 2025
**Status:** Active Issue Requiring Solution 1, 2, or 3
