# WebSpace App

A Flutter application that displays webview from remote JSON configuration. Supports Android (including older versions), iOS, and Android Set Top Box (TV).

## Features

- ✅ WebView from dynamic URL (loaded from GitHub JSON)
- ✅ Support Android 7.0 Nougat (API 24) and above
- ✅ WebView cache, local storage, and cookies are cleared automatically on every app launch (saved website list is kept)
- ✅ Landscape mode follows the device sensor and flips 180° like YouTube, even when system auto-rotate is locked (Android)
- ✅ Support for Android Set Top Box (TV with Remote)
- ✅ Error handling with retry mechanism
- ✅ Loading states
- ✅ Clean & production-ready code
- ✅ Minimal dependencies

## Requirements

- Flutter SDK: >= 3.47.0 (Dart >= 3.13.0)
- Android SDK: minSdkVersion 24 (Android 7.0), compile/target SDK 36
- Java 17 or higher
- Android build: AGP 9.1.1, Gradle 9.3.1, Kotlin 2.4.0 (highest versions supported by Flutter 3.47.8)

## Setup & Installation

### 1. Ensure Flutter is installed
```bash
flutter --version
```

If Flutter is not installed, follow: https://flutter.dev/docs/get-started/install

### 2. Extract & Navigate to Project
```bash
unzip webspace_app.zip
cd webspace_app
```

### 3. Get Dependencies
```bash
flutter pub get
```

### 4. Generate APK (Release)
```bash
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Alternative: Build APK (Debug)
```bash
flutter build apk --debug
```

### 5. Install on Device/Emulator
```bash
flutter install
```

Or manually install APK:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```
lib/
├── main.dart                      # Entry point
├── app.dart                       # App configuration
├── screens/
│   └── webview_screen.dart       # Main WebView screen
├── services/
│   └── url_loader_service.dart   # URL loading service
├── models/
│   └── webview_config.dart       # Data model
└── constants/
    └── app_constants.dart        # Application constants
```

## Configuration

### Change WebView URL Source

Edit `lib/constants/app_constants.dart`:

```dart
static const String jsonUrl =
    'https://your-url-here.com/config.json';
```

### Expected JSON Format

The JSON file should have this structure:

```json
[
  {
    "webview_url": "https://example.com",
    "website_name": "Example",
    "version": "1.0",
    "allowed": ["*.example.com", "accounts.google.com"]
  }
]
```

### Navigation Allowlist (`allowed`)

The WebView only opens the selected website, its subdomains (a leading
`www.` is ignored) and the hosts listed in that website's optional `allowed`
array. Everything else (ads, redirects, `intent:` links) is blocked. Old app
versions ignore the field, and a missing/invalid `allowed` never rejects the
configuration (invalid entries are skipped and logged as warnings).

| Pattern | Matches |
|---|---|
| `host.com` | exactly `host.com` |
| `*.host.com` | `host.com` and every subdomain |
| `host.com/path/` | exactly `host.com`, only paths starting with `/path/` |

No scheme, port, query or bare wildcards (`*`, `*.com`); at most 100 entries
per website. Custom websites get the same list through the
"Host yang diizinkan" field in the add/edit dialog.

Standard entries for Google sign-in and captchas (add only to websites that
need them):

```json
"accounts.google.com", "accounts.google.co.id", "accounts.youtube.com",
"gds.google.com", "challenges.cloudflare.com", "www.google.com/recaptcha/",
"recaptcha.net", "*.recaptcha.net", "*.hcaptcha.com"
```

Popups opened by the page (e.g. "Sign in with Google") are shown in a dialog
when their URL is allowlisted; others are refused. Only one popup at a time.

> **Google sign-in caveat:** Google blocks OAuth in embedded WebViews. While
> on a Google account host the WebView sends its User-Agent without the
> WebView markers. This works around Google policy and may stop working at
> any time.

Existing installs re-sync the remote list once in the background after the
update so `allowed` takes effect without pressing "Sync Online".

### Customize Timeout

Edit `lib/constants/app_constants.dart`:

```dart
static const int requestTimeoutSeconds = 10;  // Change this value
```

## Build for Different Targets

### Build APK (Android Phone)
```bash
flutter build apk --release
```

### Build for Android Set Top Box (TV)
Same as above. The app automatically handles landscape orientation for TV displays.

For ARMv7 (32-bit) set-top boxes, build a per-ABI APK (≈16 MB instead of ≈52 MB,
only `armeabi-v7a` native libraries):
```bash
flutter build apk --release --split-per-abi --target-platform android-arm
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
```

**Low-end profile:** on 32-bit ARM processes, Android low-RAM devices, or
devices with less than 2 GB RAM, dialogs skip the backdrop blur, shadows use
a small blur, and the loading pulse plays once. Other devices look unchanged.
Fonts (Poppins) are bundled in `assets/google_fonts/` and never downloaded at
runtime.

### Build for iOS
```bash
flutter build ios --release
```

## Troubleshooting

### Issue: "Flutter SDK not found"
**Solution:** Make sure Flutter SDK is properly installed and added to PATH.

```bash
export PATH="$PATH:$(flutter bin directory path)"
```

### Issue: "Gradle build failed"
**Solution:** Clean and try again
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Issue: "WebView not loading"
**Solution:** 
- Check internet connection
- Verify JSON URL is accessible
- Check Firebase/GitHub URL permissions

### Issue: "App crashes on older Android"
**Solution:** This app supports Android API 24+ (Android 7.0). If issues persist:
- Check logcat: `adb logcat | grep flutter`
- Ensure min SDK is `flutter.minSdkVersion` (24) in `android/app/build.gradle`

## Dependencies

- **flutter_inappwebview**: 6.2.0-beta.3 - WebView with popup (multi-window) support. The stable 6.1.5 does not build with AGP 9 (`proguard-android.txt` is no longer supported); move to the next stable release once available.
- **http**: 1.6.0 - HTTP client for fetching configuration
- **sqflite**: 2.4.5 - Local SQLite storage for the website list
- **google_fonts**: 9.0.0 - Poppins typography
- **material_ui**: 1.8.0 - Material Design widgets (decoupled from the Flutter SDK; import `package:material_ui/material_ui.dart` instead of `package:flutter/material.dart`)
- **flutter_animate**: 4.5.2 - UI animations
- **intl**: 0.20.3 - Date formatting in error logs
- **path**: 1.9.1 - Database path handling
- **flutter_lints**: 6.0.0 - Linting rules
- **sqflite_common_ffi** (dev): 2.4.5 - SQLite in unit tests (schema migration)

## Performance

- Minimal app size (~15-20 MB)
- Fast startup time
- Optimized for low-end devices
- Efficient network usage

## Security

- ✅ URL validation
- ✅ HTTPS only support
- ✅ No hardcoded secrets
- ✅ Input sanitization
- ✅ Safe error messages

## Code Quality

Follows clean code principles:
- Clear naming conventions
- Single responsibility principle
- Comprehensive error handling
- No magic numbers
- Consistent code style

## Building Release APK for Distribution

```bash
# Clean previous builds
flutter clean

# Get latest dependencies
flutter pub get

# Build release APK
flutter build apk --release

# APK location
# build/app/outputs/flutter-apk/app-release.apk
```

## Testing the App

### Test on Android Emulator
```bash
# Start emulator
emulator -avd emulator_name

# Run app
flutter run
```

### Test on Physical Device
```bash
# Enable USB debugging on device
# Connect via USB

flutter run
```

## Support

For issues or questions:
1. Check Flutter documentation: https://flutter.dev/docs
2. Check WebView documentation: https://pub.dev/packages/flutter_inappwebview
3. Review app logs: `flutter logs`

## License

This project is provided as-is for personal and commercial use.

## Version History

- **v1.0.0** - Initial release
  - WebView support
  - Dynamic URL loading from JSON
  - Error handling
  - Support for Android 4.4+
