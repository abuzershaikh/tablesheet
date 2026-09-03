# 04 - C++ NDK & Vulkan Compute Acceleration Architecture

## 1. High-Performance Execution Layer
When dealing with large spreadsheets containing thousands of rows (e.g. 1000 rows × 26 columns = 26,000 cells), evaluating formulas sequentially in single-threaded Dart can cause lag.

To solve this:
1. **C++ NDK Engine (`spreadsheet_compute.cpp`)**:
   - Parses mathematical expressions natively in C++ for maximum throughput.
   - Evaluates ranges (`SUM`, `AVERAGE`, `PRODUCT`, `STDDEV`, `MEDIAN`) via compiled SIMD vector instructions.
2. **Vulkan GPU Compute Acceleration (`vulkan_renderer.cpp` / Compute Shaders)**:
   - When Vulkan GPU support is available on the Android device, bulk array operations (e.g., multiplying Column A * Column B for 10,000 rows simultaneously) are offloaded to Vulkan Compute Shaders.
   - Executes parallel GPU threads across thousands of data points concurrently with 0 CPU lag.

```
                    +------------------------------------+
                    |  Formula Evaluation Dispatcher     |
                    +------------------------------------+
                                      |
                 +--------------------+--------------------+
                 |                                         |
                 v                                         v
    [ Single/Small Range Formula ]           [ Bulk Column / Matrix Calc ]
    Dart / C++ NDK (CPU Engine)              Vulkan GPU Compute Shader
    e.g. A1*B1, CONCAT(A1,B1)                e.g. A1:A10000 * B1:B10000
```

## 2. Native C++ Binding via FFI & JNI
- **Dart FFI**: Direct low-overhead call from Dart into compiled `libnative_lib.so`.
- **JNI Bridge (`jni_bridge.cpp`)**: Android native bridge for GPU buffer management.
