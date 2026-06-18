# 🚀 QUICK START - Build APK in 3 Steps

## Step 1: Extract & Setup
```bash
unzip webspace_app.zip
cd webspace_app
flutter pub get
```

## Step 2: Build APK
```bash
flutter build apk --release
```

## Step 3: Install & Run
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

✅ **Done!** Your app is ready.

---

## Detailed Guides

- **Full Build Instructions:** See `BUILD_INSTRUCTIONS.md`
- **App Documentation:** See `README.md`
- **Troubleshooting:** See `BUILD_INSTRUCTIONS.md` → Troubleshooting

---

## Requirements

- ✅ Flutter SDK installed
- ✅ Android SDK / Android Studio
- ✅ Java 8 or higher

Check with:
```bash
flutter doctor
```

All items should show ✓

---

## Common Issues

### `flutter: command not found`
→ Install Flutter: https://flutter.dev/docs/get-started/install

### `ANDROID_SDK_ROOT` not set
→ Set SDK path:
```bash
export ANDROID_SDK_ROOT=~/Android/Sdk
```

### Gradle build failed
→ Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## Output Location

APK file will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

File size: ~20-25 MB (release APK)

---

## What's Inside?

✅ WebView that loads URL from JSON
✅ Support Android 4.4+ (KitKat and above)
✅ Support Android Set Top Box (TV)
✅ Error handling with retry
✅ Production-ready code
✅ Clean architecture

---

**Questions?** Check README.md or BUILD_INSTRUCTIONS.md
