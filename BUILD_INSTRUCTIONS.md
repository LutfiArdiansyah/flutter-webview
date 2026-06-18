# Build Instructions - Step by Step

## Prerequisites Check

Before building, ensure you have:

1. **Flutter SDK** installed
   ```bash
   flutter --version
   ```
   Should show: Flutter X.X.X

2. **Android SDK** installed (for building APK)
   ```bash
   flutter doctor
   ```
   Check that Android toolchain shows ✓

3. **Java Development Kit (JDK)** installed
   ```bash
   java -version
   ```
   Should show Java 8 or higher

## Quick Start (Recommended)

### Step 1: Extract Project
```bash
unzip anime_webview_app.zip
cd anime_webview_app
```

### Step 2: Get Dependencies
```bash
flutter pub get
```

### Step 3: Build APK (Release)
```bash
flutter build apk --release
```

**✅ SUCCESS:** APK file created at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Step 4: Install APK

**Option A: Using ADB (Android Debug Bridge)**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Option B: Using Flutter**
```bash
flutter install
```

**Option C: Manual Installation**
1. Download the APK to your phone
2. Open file manager
3. Tap the APK file
4. Tap "Install"

---

## Detailed Build Process

### Full Build with Detailed Logging

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Analyze code (optional)
flutter analyze

# Build APK with verbose output
flutter build apk --release -v
```

### Build APK (Debug Version)

For testing on emulator or device:

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Build Multiple APKs (Split by ABI)

For smaller file sizes:

```bash
flutter build apk --release --split-per-abi
```

Output:
- `app-armeabi-v7a-release.apk` (ARM 32-bit)
- `app-arm64-v8a-release.apk` (ARM 64-bit)
- `app-x86_64-release.apk` (x86 64-bit)

---

## Troubleshooting Build Issues

### Issue 1: "Android SDK not found"
```bash
# Solution: Set ANDROID_SDK_ROOT
export ANDROID_SDK_ROOT=~/Android/Sdk
# Or on Windows:
set ANDROID_SDK_ROOT=C:\Users\YourUsername\AppData\Local\Android\sdk
```

### Issue 2: "Gradle build failed"
```bash
# Clean and rebuild
flutter clean
rm -rf build/
flutter pub get
flutter build apk --release
```

### Issue 3: "FAILURE: Build failed with an exception"
```bash
# Check gradle wrapper
cd android
./gradlew clean
cd ..
flutter build apk --release -v
```

### Issue 4: "Unable to locate Android SDK"
```bash
# Create local.properties file
cd android
echo "sdk.dir=/path/to/android/sdk" > local.properties
cd ..
flutter build apk --release
```

### Issue 5: "Android App Bundle" instead of APK
Make sure you're using:
```bash
flutter build apk  # This builds APK
# NOT:
flutter build appbundle  # This builds for Google Play
```

---

## Testing the APK

### On Android Emulator

1. Start emulator:
   ```bash
   emulator -avd emulator_name
   ```

2. Install APK:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

3. Launch app:
   ```bash
   adb shell am start -n com.example.anime_webview/.MainActivity
   ```

### On Physical Android Device

1. Enable Developer Mode:
   - Go to Settings → About Phone
   - Tap Build Number 7 times
   - Back to Settings → Developer Options
   - Enable USB Debugging

2. Connect via USB:
   ```bash
   adb devices
   ```
   Device should appear in list

3. Install APK:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

### On Android Set Top Box (TV)

1. Connect Set Top Box via USB

2. Install APK:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. Launch app from TV home screen

---

## Checking APK Details

### APK Size
```bash
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

### APK Contents
```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | head -20
```

### APK Info (requires aapt)
```bash
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
```

---

## Common Build Configurations

### For Low-End Devices (Optimize Size)

Build with split ABIs:
```bash
flutter build apk --release --split-per-abi
```

Then use the `armeabi-v7a` APK for older/lower-end devices.

### For High-End Devices (Full Support)

Build universal APK:
```bash
flutter build apk --release
```

### For Android 4.4 Devices

Already configured in `android/app/build.gradle`:
```gradle
minSdkVersion 20  // Android 4.4 (KitKat)
```

No additional configuration needed.

---

## Getting Logs from Built APK

### While Running

```bash
# View logs
flutter logs

# Or with filtered output
adb logcat | grep flutter
```

### Crash Analysis

```bash
adb logcat > app_logs.txt
```

Then search for "Exception" or "Error" in the file.

---

## Signing APK for Release

If you need to sign the APK with a custom key:

1. Create keystore:
   ```bash
   keytool -genkey -v -keystore ~/key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias key
   ```

2. Update `android/key.properties`:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=key
   storeFile=../key.jks
   ```

3. Build signed APK:
   ```bash
   flutter build apk --release
   ```

---

## Uploading to Google Play

To publish on Google Play Store:

1. Create app bundle:
   ```bash
   flutter build appbundle --release
   ```

2. Go to Google Play Console
3. Create new app
4. Upload `build/app/outputs/bundle/release/app-release.aab`

---

## Verification Checklist

After building, verify:

- [ ] APK file exists: `build/app/outputs/flutter-apk/app-release.apk`
- [ ] APK size is reasonable (< 100 MB)
- [ ] APK installs without errors
- [ ] App launches and loads webview
- [ ] WebView displays content correctly
- [ ] Retry button works on error
- [ ] No crashes in logcat

---

## Need More Help?

1. **Flutter Documentation:** https://flutter.dev/docs/deployment/android
2. **WebView Plugin:** https://pub.dev/packages/webview_flutter
3. **Android Documentation:** https://developer.android.com/

---

**Last Updated:** 2024
**Created For:** Anime WebView App v1.0.0
