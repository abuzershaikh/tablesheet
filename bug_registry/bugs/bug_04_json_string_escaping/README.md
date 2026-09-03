# BUG-04: Unescaped String Values & Quadratic Spill JSON

## Bug Overview

- **Bug ID**: `BUG-04`
- **Bug Name**: Unescaped String Values & Quadratic Spill JSON
- **File Location**: [`android/app/src/main/cpp/grid_manager.cpp`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/android/app/src/main/cpp/grid_manager.cpp)
- **Component**: Grid Manager JSON Serialization (`formatEvalResult`)
- **Severity**: Medium-High (JSON parse errors on string values containing quotes or newlines, and performance degradation on large spill arrays)

---

## Detailed Description & Root Cause

1. **Unescaped Quotes/Special Characters**: When `formatEvalResult()` formatted a string cell result, it directly wrapped the string in double quotes without escaping quotes or newlines. If a formula returned text like `"Hello "World""`, invalid JSON was generated, throwing a `FormatException` in Dart's `jsonDecode()`.
2. **Quadratic String Allocations**: `ArrayVal` (spill array) JSON formatting performed repeated `+` string concatenations in a nested loop, creating $O(N^2)$ transient string copies for large arrays (e.g. 100,000 spilled cells).

---

## How It Was Fixed

1. Wrapped string cell results in `escapeJson()` before surrounding with double quotes.
2. Refactored `ArrayVal` matrix formatting to stream directly into a single `std::ostringstream`.

### Code Fix Highlights:

```cpp
// 1. Escaped JSON String Format
} else if (std::holds_alternative<std::string>(result)) {
    resStr = "\"" + escapeJson(std::get<std::string>(result)) + "\"";
}

// 2. Stream-based Spill Array Serialization
} else if (std::holds_alternative<ArrayVal>(result)) {
    const auto& mat = std::get<ArrayVal>(result).matrix;
    std::ostringstream ss;
    ss << "{\"type\":\"spill\",\"data\":[";
    for (size_t r = 0; r < mat.size(); r++) {
        ss << "[";
        for (size_t c = 0; c < mat[r].size(); c++) {
            ss << formatEvalResult(mat[r][c], "");
            if (c < mat[r].size() - 1) ss << ",";
        }
        ss << "]";
        if (r < mat.size() - 1) ss << ",";
    }
    ss << "]}";
    return ss.str();
}
```

---

## Verification

String cells containing quotes, backslashes, and newlines decode without JSON syntax errors in Dart. Large spill arrays serialize linearly with zero memory spikes.
