# Log Reference Guide

## Understanding Your App's Output

When you run your app, the console will show logs that help understand what's happening with the AI features.

## ✅ Expected Logs After Fix

### Scenario 1: Native Library NOT Available (Current)

When you try to generate a summary from a PDF:

```
I/flutter (12853): 🔄 Starting offline generation for: iesc108.pdf
I/flutter (12853): 📄 Extracting text from: /data/user/0/com.example.claudetest/app_flutter/personalFiles/iesc108.pdf
I/flutter (12853): 🔍 Reading PDF text...
I/flutter (12853): ✅ Successfully extracted 33654 characters
I/flutter (12853): 🧹 Cleaning text...
I/flutter (12853): 📚 Subject Analysis: Physics (Scores: {...})
I/flutter (12853): 📚 Detected Subject: Physics
I/flutter (12853): 📊 Estimated Text Complexity: Grade 7.5
I/flutter (12853): 🤖 [SummaryQuiz] Using local LLM model
I/flutter (12853): 🤖 [LLM] Using model for summary generation: /data/user/0/com.example.claudetest/app_flutter/summary.gguf
I/flutter (12853): 🌐 [LLM] Language: en
I/flutter (12853): ℹ️ [LLM] Android detected - using system libllama.so
I/flutter (12853): 🔄 [LLM] Initializing Llama with model: /data/user/0/com.example.claudetest/app_flutter/summary.gguf
I/flutter (12853): ❌ [LLM] Native library error: UnsupportedError: Failed to load dynamic library 'libllama.so'
I/flutter (12853): ⚠️ [SummaryQuiz] Native library unavailable, falling back to rule-based generation
I/flutter (12853): 📝 [SummaryQuiz] Using rule-based generation (Grade 5)
I/flutter (12853): 📊 Generating mind map...
I/flutter (12853): ✅ Summary, Quiz, and Mind Map saved
```

**What's happening:**
1. ✅ PDF text extracted successfully (33654 characters)
2. ✅ Subject detected (Physics)
3. ⚠️ Tried to use AI model but libllama.so not found
4. ✅ **Automatically fell back to rule-based generation**
5. ✅ **Summary generated successfully despite error!**
6. UI shows: Orange warning → "Local AI mode requires app rebuild. Using standard generation."

### Scenario 2: Native Library IS Available (After Fix)

After implementing Solution 1 or 2 from `NATIVE_LIBRARY_FIX.md`:

```
I/flutter (12853): 🔄 Starting offline generation for: iesc108.pdf
I/flutter (12853): 📄 Extracting text from: /data/user/0/com.example.claudetest/app_flutter/personalFiles/iesc108.pdf
I/flutter (12853): ✅ Successfully extracted 33654 characters
I/flutter (12853): 📚 Subject Analysis: Physics (Scores: {...})
I/flutter (12853): 📚 Detected Subject: Physics
I/flutter (12853): 🤖 [SummaryQuiz] Using local LLM model
I/flutter (12853): 🤖 [LLM] Using model for summary generation: /data/user/0/.../summary.gguf
I/flutter (12853): 🌐 [LLM] Language: en
I/flutter (12853): ℹ️ [LLM] Android detected - using system libllama.so
I/flutter (12853): 🔄 [LLM] Initializing Llama with model: /data/user/0/.../summary.gguf
I/flutter (12853): ✅ [LLM] Llama initialized successfully
I/flutter (12853): ✨ [LLM] Generation successful - tokens: 245
I/flutter (12853): 📊 Generating mind map...
I/flutter (12853): ✅ Summary, Quiz, and Mind Map saved
I/flutter (12853): ✅ Generated with Local AI Model!
```

**What's happening:**
1. ✅ PDF text extracted
2. ✅ Llama initialized successfully
3. ✅ AI model generated summary (245 tokens)
4. ✅ Quiz generated
5. UI shows: Green checkmark → "Generated with Local AI Model!"

## 🔍 Log Key Indicators

### Good Signs (✅)
```
✅ [LLM] Llama initialized successfully
✨ [LLM] Generation successful
✅ Summary, Quiz, and Mind Map saved
✅ Generated with Local AI Model!
```
→ Everything working perfectly

### Warning Signs (⚠️)
```
⚠️ [LLM] Inference failed
⚠️ [SummaryQuiz] Native library unavailable
⚠️ [SummaryQuiz] Using rule-based generation
```
→ Features degraded but app working

### Error Signs (❌) - Before Fix
```
❌ [LLM] Error: Exception: LLM Inference Failed: LlamaException
❌ Offline generation failed: Exception
```
→ App would crash (FIXED NOW ✅)

### Error Signs (❌) - After Fix
```
❌ [LLM] Native library error
```
→ Shows error but **app continues** with fallback ✅

## 🎯 Common Log Patterns

### Pattern 1: Missing Model File
```
⚠️ [LLM] Inference failed: Exception: Model not found. Please download it first.
```
**Fix:** Download models in app settings

### Pattern 2: Native Library Issues (Current Situation)
```
❌ [LLM] Native library error: UnsupportedError: Failed to load dynamic library 'libllama.so': dlopen failed: library "libllama.so" not found
```
**Status:** ✅ HANDLED - Falls back to rule-based generation
**Fix:** Follow Solution 1 or 2 in `NATIVE_LIBRARY_FIX.md`

### Pattern 3: Empty Response
```
⚠️ [LLM] Inference failed: Exception: LLM generated empty response
```
**Likely Cause:** Model timeout or corrupted file
**Fix:** Re-download model or restart app

### Pattern 4: Invalid JSON from Quiz
```
⚠️ [LLM] Quiz inference failed: Exception: Invalid JSON from LLM Quiz
```
**Cause:** Model returned malformed JSON
**Status:** Falls back to rule-based quiz generation

## 📱 Where to Find Logs

### Android Device (Connected via ADB)
```bash
# Real-time logs
adb logcat | grep -i flutter

# All logs including errors
adb logcat | grep -E "(E/|W/|I/flutter)"

# Save to file
adb logcat > logfile.txt
```

### Android Emulator
Same commands as above, or use Android Studio's Logcat panel

### iOS
Use Xcode console or `flutter run -v` for verbose output

### Windows/macOS
Console output appears directly in the terminal

## 🚨 If You See CRASH (Before Fix Applied)

If logs show:
```
E/flutter (12853): [ERROR:flutter/runtime/dart_vm_initializer.cc:41] Unhandled exception:
E/flutter (12853): LlamaException: Failed to initialize Llama...
```

This means the old code was being used. **Update to the latest version** (the fix should prevent this).

## ✨ Performance Indicators

### Token Generation Speed
```
✨ [LLM] Generation successful - tokens: 245
```
- 245 tokens ≈ ~10-15 seconds on mid-range Android device
- 500+ tokens ≈ ~30-40 seconds
- Slower than server API but completely offline

### Memory Usage
Not directly shown in logs, but if you see:
```
D/Llama-Native: Initializing with 2GB context
```
→ App allocated ~2GB RAM for model
→ May cause slowdown on low-RAM devices

## 🔧 Debug Commands

### Enable Verbose Logging
```bash
flutter run -v
```
Shows all internal Flutter operations plus your logs

### Check Device Logs Real-time
```bash
flutter logs
```
Filters only your app's output

### Full Device Status
```bash
flutter doctor -v
```
Shows all tools and dependencies

## 📊 Log Timeline Example

Here's a typical good run:

```
[0ms] 🔄 Starting offline generation for: Math_Chapter_3.pdf
[100ms] 📄 Extracting text from: /data/user/0/.../Math_Chapter_3.pdf
[200ms] 🔍 Reading PDF text...
[800ms] ✅ Successfully extracted 15000 characters
[850ms] 🧹 Cleaning text...
[900ms] 📚 Subject Analysis: Mathematics (Scores: {...})
[950ms] 📚 Detected Subject: Mathematics
[1000ms] 🤖 [SummaryQuiz] Using local LLM model
[1100ms] 🤖 [LLM] Using model for summary generation: ...
[1150ms] ✅ [LLM] Llama initialized successfully
[3000ms] ✨ [LLM] Generation successful - tokens: 200
[3100ms] 📊 Generating mind map...
[3300ms] ✅ Summary, Quiz, and Mind Map saved
[3350ms] ✅ Generated with Local AI Model!
```

Total time: ~3.3 seconds for complete offline processing

---

**Last Updated:** December 24, 2025
**Status:** Updated with fix implementation details
