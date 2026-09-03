# ML Model Integration Guide for Spreadsheet App

## ✅ RECOMMENDED: ONNX Runtime + TensorFlow Lite

### Why This Combination?
- **ONNX**: Best for tabular data (cell classification, pattern detection)
- **TFLite**: Best for sequences (formula suggestions, text analysis)
- **Combined size**: < 10 MB models
- **Both have excellent C++ support**

---

## 📦 INSTALLATION

### Step 1: Add Dependencies

```gradle
// android/app/build.gradle
android {
    defaultConfig {
        minSdkVersion 21
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }
}

dependencies {
    // TensorFlow Lite
    implementation 'org.tensorflow:tensorflow-lite:2.14.0'
    implementation 'org.tensorflow:tensorflow-lite-support:0.4.4'
}
```

### Step 2: Download ONNX Runtime

```bash
# Download ONNX Runtime Android AAR
cd android/app/libs
wget https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.17.0/onnxruntime-android-1.17.0.aar
```

### Step 3: Update CMakeLists.txt

```cmake
# android/app/src/main/cpp/CMakeLists.txt

cmake_minimum_required(VERSION 3.18.1)
project("mobile_spreadsheet")

# Add ONNX Runtime
add_library(onnxruntime SHARED IMPORTED)
set_target_properties(onnxruntime PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../libs/onnxruntime-android-1.17.0.aar)

# TensorFlow Lite headers (auto-included via Gradle)

# Your native lib
add_library(native-lib SHARED
    native-lib.cpp
    ffi_bridge.cpp
    onnx_predictor.cpp
    tflite_predictor.cpp
)

target_link_libraries(native-lib
    android
    log
    onnxruntime
    # TFLite linked automatically
)
```

---

## 🎯 COMPLETE C++ IMPLEMENTATION

### File 1: ONNX Predictor

```cpp
// android/app/src/main/cpp/onnx_predictor.h
#ifndef ONNX_PREDICTOR_H
#define ONNX_PREDICTOR_H

#include <onnxruntime/core/session/onnxruntime_cxx_api.h>
#include <vector>
#include <memory>
#include <android/log.h>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "ONNXPredictor", __VA_ARGS__)

class ONNXPredictor {
public:
    ONNXPredictor(const char* modelPath);
    std::vector<float> predict(const std::vector<float>& input);
    ~ONNXPredictor() = default;

private:
    std::unique_ptr<Ort::Env> env;
    std::unique_ptr<Ort::Session> session;
    Ort::SessionOptions sessionOptions;
};

#endif
```

### File 2: ONNX Predictor Implementation

```cpp
// android/app/src/main/cpp/onnx_predictor.cpp
#include "onnx_predictor.h"

ONNXPredictor::ONNXPredictor(const char* modelPath) {
    env = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "SpreadsheetML");
    
    sessionOptions.SetIntraOpNumThreads(4);
    sessionOptions.SetGraphOptimizationLevel(
        GraphOptimizationLevel::ORT_ENABLE_ALL
    );
    
    session = std::make_unique<Ort::Session>(
        *env,
        modelPath,
        sessionOptions
    );
    
    LOGI("ONNX model loaded: %s", modelPath);
}

std::vector<float> ONNXPredictor::predict(const std::vector<float>& input) {
    auto memoryInfo = Ort::MemoryInfo::CreateCpu(
        OrtArenaAllocator, OrtMemTypeDefault
    );
