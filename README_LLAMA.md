# LLM Setup Instructions

## ⚠️ Important: Native Libraries Required

This project uses `llama.cpp` for offline inference. To make it work, you need the native libraries for your platform.

### Windows
- **Done**: `llama.dll` has been added to `windows/runner/` and configured to copy automatically.
- It should work out of the box on Windows.

### Android
- **Action Required**: You must compile or obtain `libllama.so` for Android (arm64-v8a).
- The `llama_cpp_dart` package does not bundle these binaries.
- **Steps**:
  1. Follow instructions at [llama.cpp Android Docs](https://github.com/ggerganov/llama.cpp/blob/master/docs/android.md) or [llama_cpp_dart](https://github.com/netdur/llama_cpp_dart).
  2. Place the compiled `libllama.so` in `android/app/src/main/jniLibs/arm64-v8a/`.
  3. Rebuild the app: `flutter run`.

If the library is missing, the app will safely fall back to **Rule-Based Generation**.
