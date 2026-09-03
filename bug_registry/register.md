# Bug Registry & Fix Documentation Index

This directory serves as the official **Bug Registry** for the Mobile Spreadsheet project. It catalogs all major bugs identified, root cause analyses, exact file locations, fix implementations, and links to detailed individual report files.

---

## Master Bug Index

| Bug ID | Bug Name | Primary File Location | Description & Root Cause | Summary of Fix | Detailed Report |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BUG-01** | Formula Tokenizer Abort on Missing Leading `=` | `android/app/src/main/cpp/parser.cpp` | `Tokenizer::tokenize()` aborted formula parsing when the leading `=` was already stripped by `setCellFormula()` or `dfsEvaluate()`, turning valid formulas into plain text string tokens. | Removed the premature `else` string wrapper in `Tokenizer::tokenize()`, ensuring formulas are correctly tokenized regardless of leading `=`. | [BUG-01 Report](file:///d:/abuzer%20projects/Table%20sheets%20project/bug_registry/bugs/bug_01_formula_tokenizer/README.md) |
| **BUG-02** | Unnormalized Cell References in Grid Lookup | `android/app/src/main/cpp/grid_manager.cpp` | Lowercase (`a1`) or absolute (`$A$1`) cell references in formulas failed to match standard uppercase grid keys (`A1`), causing evaluations to return `0.0`. | Added automatic coordinate normalization via `Evaluator::parseCellCoordinates()` at the entry of `dfsEvaluate()`. | [BUG-02 Report](file:///d:/abuzer%20projects/Table%20sheets%20project/bug_registry/bugs/bug_02_coordinate_normalization/README.md) |
| **BUG-03** | Null Pointer Guard & Environment Cleanup in Evaluator | `android/app/src/main/cpp/evaluator.cpp` | Lambda and `FunctionNode` execution risked dereferencing null environment pointers or polluting local environments during stack cleanup. | Added explicit `it->second != nullptr` guards and replaced nullptr assignments with `erase()` during scope unwinding. | [BUG-03 Report](file:///d:/abuzer%20projects/Table%20sheets%20project/bug_registry/bugs/bug_03_evaluator_nullptr_guard/README.md) |
| **BUG-04** | Unescaped String Values & Quadratic Spill JSON | `android/app/src/main/cpp/grid_manager.cpp` | String results in `formatEvalResult()` were not JSON-escaped, causing syntax errors in Dart `jsonDecode()`. ArrayVal spill serialization suffered from $O(N^2)$ string concats. | Added `escapeJson()` for string cell results and refactored ArrayVal spill JSON serialization to use `std::ostringstream`. | [BUG-04 Report](file:///d:/abuzer%20projects/Table%20sheets%20project/bug_registry/bugs/bug_04_json_string_escaping/README.md) |
| **BUG-05** | `g_namedRanges` Mutex & FFI Exception Barriers | `android/app/src/main/cpp/ffi_bridge.cpp` | Global `g_namedRanges` lacked thread safety under concurrent calls, and unhandled C++ exceptions in FFI exports could crash the Android process. | Introduced `g_namedRangesMutex` with `std::lock_guard` protection and added top-level `try-catch` barriers to FFI exports. | [BUG-05 Report](file:///d:/abuzer%20projects/Table%20sheets%20project/bug_registry/bugs/bug_05_g_named_ranges_mutex/README.md) |

---

## Directory Structure

```
bug_registry/
├── register.md (Master Index)
└── bugs/
    ├── bug_01_formula_tokenizer/
    │   └── README.md
    ├── bug_02_coordinate_normalization/
    │   └── README.md
    ├── bug_03_evaluator_nullptr_guard/
    │   └── README.md
    ├── bug_04_json_string_escaping/
    │   └── README.md
    └── bug_05_g_named_ranges_mutex/
        └── README.md
```
