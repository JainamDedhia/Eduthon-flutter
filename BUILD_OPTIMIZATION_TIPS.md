# Build Optimization Tips

## Memory Issues Fix

### 1. Increase Windows Paging File (Virtual Memory)
If you're getting "paging file too small" errors:

1. Open **System Properties**:
   - Press `Win + Pause` or right-click "This PC" → Properties
   - Click "Advanced system settings"
   - Under Performance, click "Settings"
   - Go to "Advanced" tab
   - Click "Change" under Virtual memory

2. **Recommended Settings**:
   - Uncheck "Automatically manage paging file size"
   - Select your system drive (usually C:)
   - Select "Custom size"
   - **Initial size**: 8192 MB (8 GB)
   - **Maximum size**: 16384 MB (16 GB)
   - Click "Set" then "OK"
   - **Restart your computer** for changes to take effect

### 2. Gradle Optimizations Applied
- Reduced memory from 8GB to 4GB (adjust if you have more RAM)
- Enabled G1 garbage collector for better memory management
- Enabled Gradle caching and parallel builds
- Increased network timeouts for artifact downloads

### 3. Build Commands

**Clean build (recommended after changes)**:
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter build apk --debug
```

**If build still fails, try with reduced memory**:
```bash
# Temporarily reduce memory further
# Edit android/gradle.properties and change -Xmx4G to -Xmx2G
```

### 4. Network Issues
If Gradle downloads are failing:
- Check your internet connection
- Try using a VPN if downloads are blocked
- Use Gradle offline mode (after first successful build):
  ```bash
  cd android
  ./gradlew build --offline
  ```

### 5. Heavy Plugins
The following plugins are memory-intensive:
- `google_mlkit_translation` (ML Kit)
- `speech_to_text`

Consider:
- Building in release mode (uses R8 which is more efficient)
- Disabling unused features during development
- Using `flutter build apk --split-per-abi` to build smaller APKs

### 6. Alternative: Build on CI/CD
If local builds continue to fail, consider:
- Using GitHub Actions
- Using Firebase App Distribution
- Using a cloud build service

## Kotlin Version Updated
- Updated from 1.8.22 to 2.1.0 (meets Flutter's future requirements)

## Critical: Increase Windows Paging File IMMEDIATELY

The JVM crash log shows: **"There is insufficient memory for the Java Runtime Environment to continue. Native memory allocation (malloc) failed"**

This is NOT a heap memory issue - it's a **native memory** issue caused by insufficient virtual memory (paging file).

### Steps to Fix (REQUIRED):

1. **Open System Properties**:
   - Press `Win + Pause` or right-click "This PC" → Properties
   - Click "Advanced system settings"
   - Under Performance, click "Settings"
   - Go to "Advanced" tab
   - Click "Change" under Virtual memory

2. **Set Paging File**:
   - Uncheck "Automatically manage paging file size"
   - Select your system drive (usually C:)
   - Select "Custom size"
   - **Initial size**: 16384 MB (16 GB) - MINIMUM
   - **Maximum size**: 32768 MB (32 GB) - RECOMMENDED
   - Click "Set" then "OK"
   - **RESTART YOUR COMPUTER** (required for changes to take effect)

3. **After Restart**:
   ```bash
   # Stop all Gradle daemons
   cd android
   ./gradlew --stop
   cd ..
   
   # Clean and rebuild
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

### Why This Happens:
- JVM needs native memory for: thread stacks, code cache, JIT compiler, metaspace
- With 15GB RAM but small paging file, Windows can't allocate enough virtual memory
- Even with 2GB heap, JVM needs additional native memory that exceeds available virtual memory

### Alternative: If You Can't Increase Paging File
- Use a machine with more RAM
- Build on a CI/CD service (GitHub Actions, etc.)
- Use WSL2 with more memory allocated

