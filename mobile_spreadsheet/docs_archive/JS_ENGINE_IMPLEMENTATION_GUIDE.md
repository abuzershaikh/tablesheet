# Complete JavaScript Engine Implementation Guide

## 🎯 **V8 ENGINE - STEP BY STEP IMPLEMENTATION**

### Prerequisites
- Android NDK r25b or newer
- CMake 3.18+
- V8 precompiled libraries for Android

## 📁 **STEP 1: Project Structure Setup**

Create these directories and files:

```
android/app/src/main/cpp/
├── js_engine/
│   ├── v8_engine.h
│   ├── v8_engine.cpp  
│   ├── js_bridge.h
│   ├── js_bridge.cpp
│   └── js_context_manager.cpp
├── js_api/
│   ├── spreadsheet_api.cpp     # Spreadsheet-specific JS APIs
│   ├── data_cleaning_api.cpp   # Data cleaning functions
│   └── math_api.cpp           # Advanced math functions
└── v8_libs/                   # V8 static libraries
    ├── arm64-v8a/
    ├── armeabi-v7a/
    └── x86_64/
```

## 🔧 **STEP 2: CMakeLists.txt Configuration**

```cmake
cmake_minimum_required(VERSION 3.18.1)
project("mobile_spreadsheet")

# Add V8 library path
set(V8_LIB_PATH ${CMAKE_SOURCE_DIR}/v8_libs/${ANDROID_ABI})

# Include V8 headers
include_directories(${CMAKE_SOURCE_DIR}/v8_include)

# Add JavaScript engine sources
file(GLOB JS_ENGINE_SOURCES
    "js_engine/*.cpp"
    "js_api/*.cpp"
)

add_library(native-lib SHARED
    native-lib.cpp
    evaluator.cpp
    parser.cpp
    grid_manager.cpp
    ${JS_ENGINE_SOURCES}
    # ... other sources
)

# Link V8 libraries
target_link_libraries(native-lib
    android
    log
    ${V8_LIB_PATH}/libv8_monolith.a
    # ... other libraries
)

# C++17 required for V8
set_target_properties(native-lib PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)
```

## 🏗️ **STEP 3: V8 Engine Core Implementation**

### v8_engine.h
```cpp
#pragma once
#include <v8.h>
#include <libplatform/libplatform.h>
#include <memory>
#include <string>
#include <functional>
#include <map>

class V8Engine {
public:
    static V8Engine& getInstance();
    
    bool initialize();
    void shutdown();
    
    // Script execution
    std::string executeScript(const std::string& script);
    std::string executeFunction(const std::string& funcName, const std::string& args);
    
    // Data binding
    void setGlobalArray(const std::string& name, const std::vector<std::vector<std::string>>& data);
    void setGlobalObject(const std::string& name, const std::string& jsonData);
    
    // Function registration
    void registerNativeFunction(const std::string& name, v8::FunctionCallback callback);
    
    // Error handling
    std::string getLastError() const { return lastError_; }
    
private:
    V8Engine() = default;
    ~V8Engine();
    
    // V8 objects
    std::unique_ptr<v8::Platform> platform_;
    v8::Isolate* isolate_ = nullptr;
    v8::Global<v8::Context> context_;
    
    // State
    bool initialized_ = false;
    std::string lastError_;
    
    // Helper methods
    v8::Local<v8::String> createV8String(const std::string& str);
    std::string v8StringToStd(v8::Local<v8::Value> value);
    void handleException(v8::TryCatch& tryCatch);
};
```

### v8_engine.cpp
```cpp
#include "v8_engine.h"
#include <android/log.h>
#include <sstream>

#define LOG_TAG "V8Engine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

V8Engine& V8Engine::getInstance() {
    static V8Engine instance;
    return instance;
}

bool V8Engine::initialize() {
    if (initialized_) return true;
    
    try {
        // Initialize V8 platform
        v8::V8::InitializeICUDefaultLocation("");
        v8::V8::InitializeExternalStartupData("");
        platform_ = v8::platform::NewDefaultPlatform();
        v8::V8::InitializePlatform(platform_.get());
        v8::V8::Initialize();
        
        // Create isolate
        v8::Isolate::CreateParams create_params;
        create_params.array_buffer_allocator = v8::ArrayBuffer::Allocator::NewDefaultAllocator();
        isolate_ = v8::Isolate::New(create_params);
        
        {
            v8::Isolate::Scope isolate_scope(isolate_);
            v8::HandleScope handle_scope(isolate_);
            
            // Create context
            v8::Local<v8::Context> context = v8::Context::New(isolate_);
            context_.Reset(isolate_, context);
            
            v8::Context::Scope context_scope(context);
            
            // Setup global functions
            setupGlobalFunctions();
        }
        
        initialized_ = true;
        LOGI("V8 Engine initialized successfully");
        return true;
        
    } catch (const std::exception& e) {
        lastError_ = std::string("V8 initialization failed: ") + e.what();
        LOGE("%s", lastError_.c_str());
        return false;
    }
}

std::string V8Engine::executeScript(const std::string& script) {
    if (!initialized_) {
        lastError_ = "Engine not initialized";
        return "";
    }
    
    v8::Isolate::Scope isolate_scope(isolate_);
    v8::HandleScope handle_scope(isolate_);
    
    v8::Local<v8::Context> context = context_.Get(isolate_);
    v8::Context::Scope context_scope(context);
    
    v8::TryCatch try_catch(isolate_);
    
    // Compile script
    v8::Local<v8::String> source = createV8String(script);
    v8::Local<v8::Script> compiled_script;
    
    if (!v8::Script::Compile(context, source).ToLocal(&compiled_script)) {
        handleException(try_catch);
        return "";
    }
    
    // Execute script
    v8::Local<v8::Value> result;
    if (!compiled_script->Run(context).ToLocal(&result)) {
        handleException(try_catch);
        return "";
    }
    
    return v8StringToStd(result);
}

void V8Engine::setGlobalArray(const std::string& name, const std::vector<std::vector<std::string>>& data) {
    if (!initialized_) return;
    
    v8::Isolate::Scope isolate_scope(isolate_);
    v8::HandleScope handle_scope(isolate_);
    
    v8::Local<v8::Context> context = context_.Get(isolate_);
    v8::Context::Scope context_scope(context);
    
    // Create 2D array
    v8::Local<v8::Array> jsArray = v8::Array::New(isolate_, data.size());
    
    for (size_t i = 0; i < data.size(); ++i) {
        v8::Local<v8::Array> jsRow = v8::Array::New(isolate_, data[i].size());
        
        for (size_t j = 0; j < data[i].size(); ++j) {
            v8::Local<v8::String> cellValue = createV8String(data[i][j]);
            jsRow->Set(context, j, cellValue);
        }
        
        jsArray->Set(context, i, jsRow);
    }
    
    // Set as global variable
    v8::Local<v8::String> globalName = createV8String(name);
    context->Global()->Set(context, globalName, jsArray);
}

// ... implement other methods
```

## 📱 **STEP 4: Spreadsheet-Specific JavaScript APIs**

### spreadsheet_api.cpp
```cpp
#include "v8_engine.h"
#include "../evaluator.h"

// Native function: Get cell value
void GetCellValue(const v8::FunctionCallbackInfo<v8::Value>& args) {
    v8::Isolate* isolate = args.GetIsolate();
    v8::Local<v8::Context> context = isolate->GetCurrentContext();
    
    if (args.Length() < 2) {
        isolate->ThrowException(v8::Exception::TypeError(
            v8::String::NewFromUtf8(isolate, "Wrong number of arguments").ToLocalChecked()));
        return;
    }
    
    // Get row and column from JavaScript
    int row = args[0]->Int32Value(context).FromJust();
    int col = args[1]->Int32Value(context).FromJust();
    
    // TODO: Get cell value from your spreadsheet data
    std::string cellValue = getCellValueFromSpreadsheet(row, col);
    
    args.GetReturnValue().Set(
        v8::String::NewFromUtf8(isolate, cellValue.c_str()).ToLocalChecked());
}

// Native function: Set cell value  
void SetCellValue(const v8::FunctionCallbackInfo<v8::Value>& args) {
    v8::Isolate* isolate = args.GetIsolate();
    v8::Local<v8::Context> context = isolate->GetCurrentContext();
    
    if (args.Length() < 3) {
        isolate->ThrowException(v8::Exception::TypeError(
            v8::String::NewFromUtf8(isolate, "Wrong number of arguments").ToLocalChecked()));
        return;
    }
    
    int row = args[0]->Int32Value(context).FromJust();
    int col = args[1]->Int32Value(context).FromJust();
    v8::String::Utf8Value value(isolate, args[2]);
    
    // TODO: Set cell value in your spreadsheet
    setCellValueInSpreadsheet(row, col, *value);
    
    args.GetReturnValue().Set(v8::Boolean::New(isolate, true));
}

// Setup all spreadsheet APIs
void setupSpreadsheetAPIs() {
    V8Engine& engine = V8Engine::getInstance();
    
    engine.registerNativeFunction("getCellValue", GetCellValue);
    engine.registerNativeFunction("setCellValue", SetCellValue);
    engine.registerNativeFunction("getSelectedRange", GetSelectedRange);
    engine.registerNativeFunction("addChart", AddChart);
    engine.registerNativeFunction("exportData", ExportData);
}
```

## 🎮 **STEP 5: Flutter Service Integration**

### js_engine_service.dart
```dart
import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/services.dart';

class JSEngineService {
  static const MethodChannel _channel = MethodChannel('js_engine');
  
  // Initialize JavaScript engine
  Future<bool> initialize() async {
    try {
      return await _channel.invokeMethod('initialize');
    } catch (e) {
      print('JS Engine initialization failed: $e');
      return false;
    }
  }
  
  // Execute JavaScript code
  Future<String> executeScript(String script) async {
    try {
      return await _channel.invokeMethod('executeScript', script);
    } catch (e) {
      print('Script execution failed: $e');
      return '';
    }
  }
  
  // Load spreadsheet data into JS context
  Future<void> loadSpreadsheetData(List<List<String>> data) async {
    try {
      await _channel.invokeMethod('setSpreadsheetData', {
        'data': data,
        'rows': data.length,
        'cols': data.isNotEmpty ? data[0].length : 0
      });
    } catch (e) {
      print('Failed to load spreadsheet data: $e');
    }
  }
  
  // Execute advanced formula
  Future<Map<String, dynamic>> executeAdvancedFormula(String formula, Map<String, dynamic> params) async {
    try {
      final result = await _channel.invokeMethod('executeFormula', {
        'formula': formula,
        'params': jsonEncode(params)
      });
      return jsonDecode(result);
    } catch (e) {
      print('Advanced formula execution failed: $e');
      return {'error': e.toString()};
    }
  }
  
  // Data cleaning operations
  Future<List<List<String>>> cleanData(List<List<String>> data, String cleaningScript) async {
    try {
      await loadSpreadsheetData(data);
      final result = await executeScript('''
        $cleaningScript
        
        // Return cleaned data
        JSON.stringify(cleanData(spreadsheetData));
      ''');
      
      final decoded = jsonDecode(result) as List;
      return decoded.map((row) => (row as List).map((cell) => cell.toString()).toList()).toList();
    } catch (e) {
      print('Data cleaning failed: $e');
      return data; // Return original data on error
    }
  }
  
  // Advanced statistics
  Future<Map<String, double>> calculateAdvancedStats(List<double> data) async {
    try {
      final script = '''
        const data = ${jsonEncode(data)};
        
        function calculateStats(arr) {
          const sorted = arr.slice().sort((a, b) => a - b);
          const n = arr.length;
          const sum = arr.reduce((a, b) => a + b, 0);
          const mean = sum / n;
          
          return {
            mean: mean,
            median: n % 2 === 0 ? (sorted[n/2-1] + sorted[n/2]) / 2 : sorted[Math.floor(n/2)],
            mode: findMode(arr),
            standardDeviation: Math.sqrt(arr.reduce((sq, n) => sq + Math.pow(n - mean, 2), 0) / n),
            variance: arr.reduce((sq, n) => sq + Math.pow(n - mean, 2), 0) / n,
            min: Math.min(...arr),
            max: Math.max(...arr),
            range: Math.max(...arr) - Math.min(...arr)
          };
        }
        
        function findMode(arr) {
          const frequency = {};
          let maxCount = 0;
          let mode = null;
          
          arr.forEach(num => {
            frequency[num] = (frequency[num] || 0) + 1;
            if (frequency[num] > maxCount) {
              maxCount = frequency[num];
              mode = num;
            }
          });
          
          return mode;
        }
        
        JSON.stringify(calculateStats(data));
      ''';
      
      final result = await executeScript(script);
      final decoded = jsonDecode(result) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      print('Statistics calculation failed: $e');
      return {};
    }
  }
}
```

## 🔌 **STEP 6: Native Bridge Implementation**

### jni_bridge.cpp (additions)
```cpp
#include <jni.h>
#include "js_engine/v8_engine.h"

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_initializeJSEngine(
        JNIEnv *env, jobject thiz) {
    return V8Engine::getInstance().initialize();
}

JNIEXPORT jstring JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_executeJSScript(
        JNIEnv *env, jobject thiz, jstring script) {
    const char* scriptStr = env->GetStringUTFChars(script, nullptr);
    std::string result = V8Engine::getInstance().executeScript(scriptStr);
    env->ReleaseStringUTFChars(script, scriptStr);
    return env->NewStringUTF(result.c_str());
}

JNIEXPORT void JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_setSpreadsheetData(
        JNIEnv *env, jobject thiz, jobjectArray data) {
    // Convert Java 2D array to C++ vector
    std::vector<std::vector<std::string>> cppData;
    
    int rows = env->GetArrayLength(data);
    for (int i = 0; i < rows; i++) {
        jobjectArray row = (jobjectArray) env->GetObjectArrayElement(data, i);
        int cols = env->GetArrayLength(row);
        
        std::vector<std::string> cppRow;
        for (int j = 0; j < cols; j++) {
            jstring cell = (jstring) env->GetObjectArrayElement(row, j);
            const char* cellStr = env->GetStringUTFChars(cell, nullptr);
            cppRow.push_back(cellStr);
            env->ReleaseStringUTFChars(cell, cellStr);
        }
        cppData.push_back(cppRow);
    }
    
    V8Engine::getInstance().setGlobalArray("spreadsheetData", cppData);
}

} // extern "C"
```

## 🎯 **STEP 7: Advanced JavaScript Functions Library**

Create pre-built JavaScript functions for common spreadsheet operations:

### js_library.js (embedded as string)
```javascript
// Advanced Excel-compatible functions
function XLOOKUP(lookup_value, lookup_array, return_array, if_not_found = "#N/A") {
    for (let i = 0; i < lookup_array.length; i++) {
        if (lookup_array[i] === lookup_value) {
            return return_array[i] || if_not_found;
        }
    }
    return if_not_found;
}

function FILTER(array, criteria_function) {
    return array.filter(criteria_function);
}

function UNIQUE(array) {
    return [...new Set(array.flat())];
}

function SORT(array, column = 0, ascending = true) {
    return array.slice().sort((a, b) => {
        const aVal = a[column];
        const bVal = b[column];
        return ascending ? 
            (aVal > bVal ? 1 : aVal < bVal ? -1 : 0) :
            (aVal < bVal ? 1 : aVal > bVal ? -1 : 0);
    });
}

// Data cleaning functions
function cleanNullValues(data, replacement = "") {
    return data.map(row => 
        row.map(cell => 
            cell === null || cell === undefined || cell === "" ? replacement : cell
        )
    );
}

function normalizeText(data) {
    return data.map(row =>
        row.map(cell =>
            typeof cell === 'string' ? 
                cell.trim().toLowerCase().replace(/\s+/g, ' ') : 
                cell
        )
    );
}

function detectAndConvertTypes(data) {
    return data.map(row =>
        row.map(cell => {
            if (typeof cell !== 'string') return cell;
            
            // Try number conversion
            const num = parseFloat(cell);
            if (!isNaN(num) && isFinite(num)) return num;
            
            // Try date conversion
            const date = new Date(cell);
            if (!isNaN(date.getTime())) return date.toISOString().split('T')[0];
            
            // Try boolean conversion
            if (cell.toLowerCase() === 'true') return true;
            if (cell.toLowerCase() === 'false') return false;
            
            return cell;
        })
    );
}

// Statistical functions
function REGRESSION(x_values, y_values) {
    const n = x_values.length;
    const sum_x = x_values.reduce((a, b) => a + b, 0);
    const sum_y = y_values.reduce((a, b) => a + b, 0);
    const sum_xy = x_values.reduce((sum, x, i) => sum + x * y_values[i], 0);
    const sum_xx = x_values.reduce((sum, x) => sum + x * x, 0);
    
    const slope = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x);
    const intercept = (sum_y - slope * sum_x) / n;
    
    return { slope, intercept };
}

// Chart generation helpers
function generateLineChartData(data, x_col = 0, y_col = 1) {
    return {
        type: 'line',
        data: {
            labels: data.map(row => row[x_col]),
            datasets: [{
                label: 'Data Series',
                data: data.map(row => row[y_col]),
                borderColor: 'rgb(75, 192, 192)',
                tension: 0.1
            }]
        }
    };
}
```

## ✅ **Implementation Benefits**

### 1. **Unlimited Data Processing**
- Any JavaScript library can be integrated
- Custom algorithms for specific business needs
- Real-time data transformation

### 2. **Advanced Analytics**
- Machine learning algorithms in JavaScript
- Statistical analysis beyond basic Excel functions
- Predictive modeling capabilities

### 3. **Custom Automation**
- Workflow automation scripts
- Batch processing operations
- Scheduled data updates

### 4. **Extensibility**
- Plugin system for third-party scripts
- Community-contributed functions
- Easy integration with web APIs

यह implementation आपको **Excel से भी ज्यादा powerful** spreadsheet app बनाने में मदद करेगी!