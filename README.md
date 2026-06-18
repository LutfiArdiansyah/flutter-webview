# Anime WebView App

A Flutter application that displays webview from remote JSON configuration. Supports Android (including older versions), iOS, and Android Set Top Box (TV).

## Features

- ✅ WebView from dynamic URL (loaded from GitHub JSON)
- ✅ Support Android 4.4 KitKat (API 20) and above
- ✅ Support for Android Set Top Box (TV with Remote)
- ✅ Error handling with retry mechanism
- ✅ Loading states
- ✅ Clean & production-ready code
- ✅ Minimal dependencies

## Requirements

- Flutter SDK: >= 3.0.0
- Android SDK: minSdkVersion 20 (Android 4.4 KitKat)
- Java 8 or higher

## Setup & Installation

### 1. Ensure Flutter is installed
```bash
flutter --version
```

If Flutter is not installed, follow: https://flutter.dev/docs/get-started/install

### 2. Extract & Navigate to Project
```bash
unzip anime_webview_app.zip
cd anime_webview_app
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
{
  "webview_url": "https://example.com",
  "version": "1.0"
}
```

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

### Issue: "App crashes on Android 4.4"
**Solution:** This app is tested to support Android API 20+. If issues persist:
- Check logcat: `adb logcat | grep flutter`
- Ensure min SDK is set to 20 in `android/app/build.gradle`

## Dependencies

- **webview_flutter**: 4.4.0 - Official Flutter WebView
- **http**: 1.1.0 - HTTP client for fetching configuration
- **flutter_lints**: 3.0.0 - Linting rules

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
2. Check WebView documentation: https://pub.dev/packages/webview_flutter
3. Review app logs: `flutter logs`

## License

This project is provided as-is for personal and commercial use.

## Version History

- **v1.0.0** - Initial release
  - WebView support
  - Dynamic URL loading from JSON
  - Error handling
  - Support for Android 4.4+
