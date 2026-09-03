# Mobile Spreadsheet

A powerful Flutter-based spreadsheet application for Android with native C++ NDK support.

## Project Details

- **Package ID**: `com.tablenotes.sheets.excelsheet.spreadsheet`
- **Platform**: Android Only
- **Language**: Kotlin
- **Native Support**: C++ NDK Enabled

## Features

✅ Android Native Support  
✅ C++ NDK Integration for High Performance  
✅ Material Design 3 UI  
✅ Optimized for Spreadsheet Operations  

## NDK Configuration

This project includes C++ NDK support with:
- CMake build system
- Native library (`native_lib`)
- Example JNI functions
- Support for all major Android ABIs (armeabi-v7a, arm64-v8a, x86, x86_64)

## Native Functions

The project includes example native C++ functions:
- `stringFromJNI()` - Returns a test message from native code
- `calculateSum()` - Performs calculations using native C++ code

## Build Instructions

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio with NDK installed
- CMake 3.22.1 or higher

### Build Commands

```bash
# Get dependencies
cd mobile_spreadsheet
flutter pub get

# Build for Android
flutter build apk

# Build for specific ABI
flutter build apk --target-platform android-arm64

# Build release APK
flutter build apk --release

# Run on connected device
flutter run
```

## Project Structure

```
mobile_spreadsheet/
├── android/
│   └── app/
│       ├── src/main/
│       │   ├── cpp/                    # C++ Native code
│       │   │   ├── CMakeLists.txt     # CMake configuration
│       │   │   └── native-lib.cpp     # Native C++ implementation
│       │   ├── kotlin/                 # Kotlin code
│       │   │   └── com/tablenotes/sheets/excelsheet/spreadsheet/
│       │   │       └── MainActivity.kt
│       │   └── AndroidManifest.xml
│       └── build.gradle.kts            # Gradle build file with NDK config
├── lib/
│   └── main.dart                       # Flutter UI
└── pubspec.yaml
```

## Native Library Usage

The native library is automatically loaded in `MainActivity.kt`. You can add more native functions by:

1. Adding function declarations in `native-lib.cpp`
2. Declaring external functions in `MainActivity.kt`
3. Calling the functions from Kotlin or Flutter code

## Development

To modify or extend the native C++ code:

1. Edit files in `android/app/src/main/cpp/`
2. Update `CMakeLists.txt` if adding new source files
3. Rebuild the project

## License

All rights reserved - Mobile Spreadsheet Project

---

**Created with Flutter and C++ NDK**
