# BUG-03: Null Pointer Guard & Environment Cleanup in Evaluator

## Bug Overview

- **Bug ID**: `BUG-03`
- **Bug Name**: Null Pointer Guard & Environment Cleanup in Evaluator
- **File Location**: [`android/app/src/main/cpp/evaluator.cpp`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/android/app/src/main/cpp/evaluator.cpp)
- **Component**: C++ Evaluator (`FunctionNode` & `LambdaVal` execution)
- **Severity**: High (Potential null pointer dereference crashes during lambda evaluation)

---

## Detailed Description & Root Cause

1. **Unchecked Map Value Dereference**: In `Evaluator::visit(FunctionNode& node)`, `localEnvironment.find(node.name)` looked up local variables. If `it->second` contained a `nullptr`, calling `std::holds_alternative<LambdaVal>(*(it->second))` resulted in a segmentation fault.
2. **Local Environment Pollution**: During variable scope cleanup in `invokeLambda` and `LET` function evaluation, restoring variable states assigned `localEnvironment[name] = nullptr` for newly created scope variables rather than erasing them, leaving dead keys mapped to null pointers.

---

## How It Was Fixed

1. Added `it->second != nullptr` check before dereferencing `*(it->second)` in `Evaluator::visit(FunctionNode&)`.
2. Replaced `localEnvironment[name] = nullptr` with `localEnvironment.erase(name)` during environment unwinding.

### Code Fix Highlights:

```cpp
// 1. Null Guard in FunctionNode Visit
auto it = localEnvironment.find(node.name);
if (it != localEnvironment.end() && it->second != nullptr && std::holds_alternative<LambdaVal>(*(it->second))) {
    // ... safe lambda invocation ...
}

// 2. Scope Unwinding Cleanup
for (auto itPushed = pushedNames.rbegin(); itPushed != pushedNames.rend(); ++itPushed) {
    if (itPushed->existed) {
        localEnvironment[itPushed->name] = itPushed->oldVal;
    } else {
        localEnvironment.erase(itPushed->name); // Replaced assignment of nullptr
    }
}
```

---

## Verification

Nested lambdas, `MAP`, `REDUCE`, `SCAN`, and `LET` functions now execute with zero segmentation faults or environment pollution.
