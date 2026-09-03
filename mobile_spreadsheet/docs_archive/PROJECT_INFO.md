# Mobile Spreadsheet - Project Information

## 📱 Project Details

| Property | Value |
|----------|-------|
| **Project Name** | Mobile Spreadsheet |
| **Package ID** | com.tablenotes.sheets.excelsheet.spreadsheet |
| **Platform** | Android Only |
| **Programming Language** | Kotlin + Dart (Flutter) |
| **Native Support** | C++ NDK Enabled |
| **Build System** | Gradle + CMake |
| **Flutter Version** | Latest Stable |

## 🎯 Key Features

✅ **Android Native**: Built specifically for Android platform  
✅ **C++ NDK Integration**: High-performance native code execution  
✅ **Modern UI**: Material Design 3 with Flutter  
✅ **Optimized Build**: Multi-ABI support for all Android devices  
✅ **Professional Structure**: Industry-standard project organization  

## 🏗️ NDK Configuration

### Supported ABIs
- `armeabi-v7a` - ARM 32-bit
- `arm64-v8a` - ARM 64-bit
- `x86` - Intel 32-bit
- `x86_64` - Intel 64-bit

### C++ Features
- **Standard**: C++17
- **STL**: c++_shared
- **Build Tool**: CMake 3.22.1

### Native Library
- **Library Name**: `native_lib`
- **Location**: `android/app/src/main/cpp/`
- **Entry Point**: `native-lib.cpp`

## 📂 Project Structure

```
mobile_spreadsheet/
│
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── cpp/                              # C++ Native Code
│   │   │   │   ├── CMakeLists.txt               # CMake Build Config
│   │   │   │   └── native-lib.cpp               # Native Implementation
│   │   │   │
│   │   │   ├── kotlin/                           # Kotlin Source
│   │   │   │   └── com/tablenotes/sheets/excelsheet/spreadsheet/
│   │   │   │       └── MainActivity.kt          # Main Activity with JNI
│   │   │   │
│   │   │   └── AndroidManifest.xml              # App Manifest
│   │   │
│   │   └── build.gradle.kts                     # App-level Gradle (NDK Config)
│   │
│   ├── gradle/                                   # Gradle Wrapper
│   ├── build.gradle.kts                         # Project-level Gradle
│   └── settings.gradle.kts                      # Gradle Settings
│
├── lib/
│   └── main.dart                                # Flutter UI Entry Point
│
├── pubspec.yaml                                 # Flutter Dependencies
├── README.md                                    # Documentation
└── PROJECT_INFO.md                              # This File
```

## 🚀 Build Commands

### Development Build
```bash
cd mobile_spreadsheet
flutter pub get
flutter run
```

### Release APK
```bash
flutter build apk --release
```

### Specific ABI Build
```bash
flutter build apk --target-platform android-arm64
```

### Debug Build with Logs
```bash
flutter run -v
```

## 🔧 Native Functions (Example)

### In C++ (`native-lib.cpp`)
```cpp
extern "C" JNIEXPORT jstring JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_stringFromJNI(
    JNIEnv* env, jobject) {
    return env->NewStringUTF("Hello from C++!");
}
```

### In Kotlin (`MainActivity.kt`)
```kotlin
companion object {
    init {
        System.loadLibrary("native_lib")
    }
}

private external fun stringFromJNI(): String
```

## 📊 Performance Benefits

Using C++ NDK provides:
- ⚡ **Faster Calculations**: Native code execution speed
- 🎮 **Better Performance**: Reduced overhead for complex operations
- 🔒 **Enhanced Security**: Code obfuscation through native compilation
- 📦 **Cross-Platform Libraries**: Use existing C++ libraries

## 🛠️ Development Tips

1. **Native Code Changes**: After modifying C++ files, do a clean rebuild
   ```bash
   flutter clean
   flutter build apk
   ```

2. **Debugging Native Code**: Use Android Studio's native debugger
   - Set breakpoints in C++ code
   - Use logcat for native logs

3. **Adding New Native Functions**:
   - Add function in `native-lib.cpp`
   - Declare external function in `MainActivity.kt`
   - Rebuild the project

4. **Testing Native Library**:
   - Check logs in MainActivity onCreate()
   - Native library loads automatically on app start

## 📝 Next Steps

1. ✅ Project Setup Complete
2. 🔄 Implement spreadsheet functionality
3. 🎨 Design custom UI components
4. 🧪 Add unit tests
5. 📦 Optimize native code
6. 🚀 Deploy to Play Store

## 🐛 Troubleshooting

### NDK Not Found Error
```bash
# Install NDK via Android Studio
# SDK Manager > SDK Tools > NDK (Side by side)
```

### CMake Version Issue
```bash
# Update CMakeLists.txt version if needed
cmake_minimum_required(VERSION 3.18.1)
```

### Build Failed
```bash
flutter clean
flutter pub get
flutter build apk
```

## 📞 Support

For issues or questions:
- Check Flutter documentation: https://flutter.dev
- Android NDK Guide: https://developer.android.com/ndk
- CMake Documentation: https://cmake.org/documentation/

---

**Project Created**: July 24, 2026  
**Status**: ✅ Ready for Development  
**Version**: 1.0.0
