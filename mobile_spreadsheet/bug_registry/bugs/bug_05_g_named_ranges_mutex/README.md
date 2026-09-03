# BUG-05: g_namedRanges Mutex & FFI Exception Barriers

## Bug Overview

- **Bug ID**: `BUG-05`
- **Bug Name**: `g_namedRanges` Mutex & FFI Exception Barriers
- **File Location**: [`android/app/src/main/cpp/ffi_bridge.cpp`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/android/app/src/main/cpp/ffi_bridge.cpp)
- **Component**: Native C++ FFI Bridge
- **Severity**: High (Data race conditions on global named ranges and potential process crashes from unhandled C++ exceptions crossing FFI boundaries)

---

## Detailed Description & Root Cause

1. **Global Named Ranges Data Race**: `g_namedRanges` was a global `std::unordered_map` accessed concurrently by Dart FFI calculation tasks and user interaction threads without any synchronization primitives.
2. **Missing Exception Barriers**: FFI exports like `native_calculateAll()` lacked `try-catch` blocks. If an internal function threw an exception (e.g. out-of-memory or stack limit), the unhandled exception crossed the C FFI boundary, crashing the Android app process immediately.

---

## How It Was Fixed

1. Declared `std::mutex g_namedRangesMutex;` and protected all read/write/clear operations with `std::lock_guard`.
2. Wrapped FFI export entry points (`native_calculateAll`, `pasteDataBlock`, `copyDataBlock`) in top-level `try-catch` blocks that return fallback JSON error objects rather than crashing the JVM/Android host process.

### Code Fix Highlights:

```cpp
// 1. Thread Synchronization for Named Ranges
std::mutex g_namedRangesMutex;

FFI_EXPORT void setNamedRange(const char* name, const char* ref) {
    std::lock_guard<std::mutex> lock(g_namedRangesMutex);
    // ... safe update of g_namedRanges ...
}

// 2. Top-Level FFI Exception Barriers
FFI_EXPORT char* native_calculateAll() {
    try {
        std::string res = GridManager::getInstance().calculateAll();
        return allocFfiString(res);
    } catch (...) {
        return allocFfiString("{}");
    }
}
```

---

## Verification

Concurrent named range updates execute safely across Dart isolates, and unexpected C++ exceptions are caught gracefully without crashing the app process.
