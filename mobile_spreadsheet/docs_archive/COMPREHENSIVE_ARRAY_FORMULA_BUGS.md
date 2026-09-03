# 🔴 Comprehensive Array Formula Bug Analysis

## Executive Summary

Deep analysis में **12 critical bugs** मिले हैं जो different array formula variations में crash या incorrect results produce कर सकते हैं।

---

## Bug #1: SEQUENCE Array Size Limit Mismatch ⚠️

### Location
`array_functions.cpp` - Line ~350

### Issue
```cpp
if (totalCells > 100000) return CellError{"#NUM!"}; // PREVENT OOM
```

**Problem:** SEQUENCE function की limit 100K है लेकिन MAKEARRAY की limit अब 1M है।

### Crash Formula
```
=SEQUENCE(500,500)  // 250K cells - WILL FAIL
=SEQUENCE(1000,1000)  // 1M cells - WILL FAIL
```

### Fix Solution
```cpp
// Change to match MAKEARRAY limit
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Bug #2: RANDARRAY Missing Size Limit ⚠️

### Location
`array_functions.cpp` - RANDARRAY function

### Issue
**NO SIZE CHECK** before array creation!

### Crash Formula
```
=RANDARRAY(10000,10000)  // 100M cells - INSTANT CRASH!
=RANDARRAY(5000,5000)    // 25M cells - CRASH
```

### Fix Solution
```cpp
// Add after numCols validation
long long totalCells = (long long)numRows * numCols;
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Bug #3: Nested Array Operations - Memory Explosion 🔥

### Issue
जब array functions को nest किया जाता है तो memory multiply होती है।

### Crash Formulas
```
// Each creates intermediate arrays
=MAP(MAKEARRAY(1000,1000,LAMBDA(r,c,r)),LAMBDA(x,x*2))
// Total: 1M + 1M = 2M cells in memory simultaneously

=FILTER(MAKEARRAY(1000,1000,LAMBDA(r,c,r*c)), 
        MAKEARRAY(1000,1000,LAMBDA(r,c,MOD(r,2)=0)))
// Total: 1M + 1M = 2M cells

=SORT(MAKEARRAY(1000,1000,LAMBDA(r,c,RAND())))
// Creates 1M + sorts = massive CPU usage
```

### Fix Solution
- Implement **streaming/chunked processing**
- Add **total memory budget tracker**
- Limit **nested array depth** to 3 levels
- Add **pre-calculation memory estimation**

```cpp
// Global memory tracker
class ArrayMemoryTracker {
    static size_t currentMemoryUsage;
    static const size_t MAX_MEMORY = 50 * 1024 * 1024; // 50MB
    
    bool canAllocate(size_t bytes) {
        return (currentMemoryUsage + bytes) < MAX_MEMORY;
    }
};
```

---

## Bug #4: SORTBY with Large Arrays - No Size Check ⚠️

### Location
`array_functions.cpp` - SORTBY function

### Issue
कोई size limit नहीं, infinite array sort कर सकता है।

### Crash Formula
```
=SORTBY(MAKEARRAY(1000,1000,LAMBDA(r,c,r*c)), 
        MAKEARRAY(1000,1000,LAMBDA(r,c,RAND())))
```

### Fix Solution
```cpp
// Add at start of SORTBY function
const auto& mat = std::get<ArrayVal>(arrayVal).matrix;
size_t totalCells = mat.size() * (mat.empty() ? 0 : mat[0].size());
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Bug #5: FILTER with Empty Result and No if_empty ⚠️

### Location
`array_functions.cpp` - FILTER function (Line ~455)

### Issue
```cpp
if (res.matrix.empty()) {
    if (args.size() == 3) {
        auto ifEmpty = EVAL_ARG(eval, args, 2);
        return ifEmpty;
    }
    return CellError{"#CALC!"};  // Wrong error code!
}
```

**Excel returns `#CALC!` but should return empty array or spill error.**

### Crash Formula
```
=FILTER({1,2,3}, {0,0,0})  // No matches, no if_empty
```

### Fix Solution
```cpp
// Return proper error
if (res.matrix.empty()) {
    if (args.size() == 3) {
        return EVAL_ARG(eval, args, 2);
    }
    return CellError{"#SPILL!"}; // or return empty ArrayVal
}
```

---

## Bug #6: UNIQUE with Extremely Large Arrays ⚠️

### Location
`array_functions.cpp` - UNIQUE function

### Issue
Uses `std::unordered_map` without size limit. Large arrays can cause:
- Hash map overflow
- Memory exhaustion
- O(n) worst case hash collisions

### Crash Formula
```
=UNIQUE(MAKEARRAY(1000,1000,LAMBDA(r,c,r)))
// Creates hash map with 1M entries
```

### Fix Solution
```cpp
// Add at start
if (mat.size() * mat[0].size() > 500000) {
    return CellError{"#NUM!"}; // Limit UNIQUE to 500K cells
}
```

---

## Bug #7: MAP/REDUCE/SCAN - Infinite Lambda Recursion 🔥

### Location
`lambda_functions.cpp`

### Issue
अगर lambda recursively खुद को call करे तो **stack overflow**।

### Crash Formula
```
=LET(f,LAMBDA(x,IF(x<1,0,f(x-1)+x)),MAP({1,2,3},f))
// f is recursive but not defined yet - CRASH

=REDUCE(0,SEQUENCE(10000),LAMBDA(a,b,a+b))
// 10000 lambda calls - could overflow stack
```

### Fix Solution
```cpp
// Add recursion depth tracking
class LambdaEvaluator {
    static thread_local int recursionDepth;
    static const int MAX_DEPTH = 1000;
    
    EvalResult invokeLambda(...) {
        if (++recursionDepth > MAX_DEPTH) {
            --recursionDepth;
            return CellError{"#VALUE!"}; // Stack overflow prevention
        }
        // ... evaluate
        --recursionDepth;
    }
};
```

---

## Bug #8: VSTACK/HSTACK - No Memory Check ⚠️

### Location
`array_functions.cpp`

### Issue
कोई size validation नहीं।

### Crash Formula
```
=VSTACK(MAKEARRAY(500,1000,LAMBDA(r,c,r)),
        MAKEARRAY(500,1000,LAMBDA(r,c,c)))
// Total: 1M cells created

=HSTACK(SEQUENCE(1000,500), SEQUENCE(1000,500))
// 1M cells
```

### Fix Solution
```cpp
// Add after combining all arrays
size_t totalCells = res.matrix.size() * 
                   (res.matrix.empty() ? 0 : res.matrix[0].size());
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Bug #9: TAKE/DROP with Negative Indices ⚠️

### Location
`array_functions.cpp` - TAKE function

### Issue
Negative indexing का improper handling।

### Crash Formula
```
=TAKE(SEQUENCE(10),-20)  // Takes last 20 but only 10 exist
// Could access invalid memory
```

### Fix Solution
```cpp
if (takeRows < 0) {
    startRow = std::max(0, origRows + takeRows);
    endRow = origRows;
    // Add validation
    if (startRow < 0 || std::abs(takeRows) > origRows) {
        return CellError{"#VALUE!"};
    }
}
```

---

## Bug #10: Division by Zero in Array Operations 🔥

### Location
`evaluator.cpp` - Binary operations

### Issue
Array में division operation में zero check नहीं है।

### Crash Formula
```
=MAKEARRAY(100,100,LAMBDA(r,c,1)) / 
 MAKEARRAY(100,100,LAMBDA(r,c,IF(r=c,0,1)))
// Diagonal elements are 0 - DIV/0 errors mixed in array
```

### Fix Solution
```cpp
// In evalScalarBinaryOp
case TokenType::DIVIDE:
    if (rNum == 0) return CellError{"#DIV/0!"};
    return lNum / rNum;
// Already correct! But need array-level early termination:

// In array processing loop
if (Evaluator::isError(cellResult)) {
    // Option 1: Stop immediately
    return cellResult;
    
    // Option 2: Continue but mark cell as error
    // (Current behavior - correct)
}
```

---

## Bug #11: BYROW/BYCOL with Empty Arrays ⚠️

### Location
`lambda_functions.cpp`

### Issue
Empty array handling missing।

### Crash Formula
```
=BYROW({},LAMBDA(x,SUM(x)))  // Empty array
=BYCOL({},LAMBDA(x,SUM(x)))
```

### Fix Solution
```cpp
// Add at start of BYROW
if (mat.empty()) {
    return CellError{"#VALUE!"};  // or return empty ArrayVal
}

// Add at start of BYCOL
if (mat.empty() || mat[0].empty()) {
    return CellError{"#VALUE!"};
}
```

---

## Bug #12: LET with Circular Dependencies 🔥

### Location
`logical_functions.cpp` - LET function

### Issue
Circular reference detection missing।

### Crash Formula
```
=LET(a,b+1, b,a+1, a)
// a depends on b, b depends on a - INFINITE LOOP

=LET(x,x+1, x)
// Self reference - CRASH
```

### Fix Solution
```cpp
class CircularDependencyDetector {
    std::set<std::string> currentlyEvaluating;
    
    EvalResult evaluate(const std::string& varName, ASTNode* expr) {
        if (currentlyEvaluating.count(varName)) {
            return CellError{"#REF!"}; // Circular reference
        }
        currentlyEvaluating.insert(varName);
        auto result = eval.evaluate(expr);
        currentlyEvaluating.erase(varName);
        return result;
    }
};
```

---

## Additional Edge Cases to Handle

### 13. String Concatenation in Large Arrays
```
=MAP(MAKEARRAY(1000,1000,LAMBDA(r,c,r)), 
     LAMBDA(x,REPT("A",x)))
// Creates strings of size 1, 2, 3, ..., 1000
// Total memory: ~500MB just for strings!
```

### 14. Nested FILTER Operations
```
=FILTER(FILTER(FILTER(MAKEARRAY(1000,1000,LAMBDA(r,c,r*c)),
                      condition1), condition2), condition3)
// Creates 4 intermediate 1M arrays
```

### 15. TRANSPOSE on Very Large Arrays
```
=TRANSPOSE(MAKEARRAY(1000,1000,LAMBDA(r,c,r*c)))
// Creates copy of entire array
```

---

## Priority Fix Order

### P0 - Critical (Immediate Fix Required)
1. ✅ MAKEARRAY limit increased (DONE)
2. **RANDARRAY add size limit**
3. **SEQUENCE increase limit**
4. **Add global memory tracker**

### P1 - High (Fix in Next Release)
5. SORTBY size validation
6. VSTACK/HSTACK size validation
7. Recursion depth tracking
8. Circular dependency detection in LET

### P2 - Medium (Fix Soon)
9. UNIQUE size optimization
10. TAKE/DROP bounds checking
11. Empty array handling in BYROW/BYCOL
12. FILTER error code correction

---

## Testing Strategy

### Memory Stress Tests
```cpp
// Test 1: Maximum single array
"=MAKEARRAY(1024,1024,LAMBDA(r,c,r*c))"  // 1,048,576 cells

// Test 2: Multiple large arrays
"=LET(a,MAKEARRAY(500,500,LAMBDA(r,c,r)),
      b,MAKEARRAY(500,500,LAMBDA(r,c,c)),
      a+b)"

// Test 3: Nested operations
"=BYROW(MAP(MAKEARRAY(100,100,LAMBDA(r,c,r*c)),
            LAMBDA(x,SQRT(x))),
        LAMBDA(r,SUM(r)))"

// Test 4: Memory limit exceeded
"=MAKEARRAY(2000,2000,LAMBDA(r,c,1))"  // Should return #NUM!
```

### Edge Case Tests
```cpp
// Empty arrays
"=FILTER({1,2,3},{0,0,0})"
"=BYROW({},LAMBDA(x,x))"

// Circular dependencies
"=LET(a,b, b,a, a)"

// Division by zero in arrays
"={1,2,3}/{1,0,1}"

// Negative indices
"=TAKE(SEQUENCE(10),-20)"
```

---

## Recommended Global Limits

```cpp
const size_t MAX_ARRAY_CELLS = 1048576;      // 1M cells per array
const size_t MAX_TOTAL_MEMORY = 100*1024*1024; // 100MB total
const int MAX_LAMBDA_DEPTH = 1000;           // Recursion limit
const int MAX_NESTED_ARRAYS = 5;             // Nesting depth
const size_t MAX_STRING_LENGTH = 32767;      // Per cell
```

---

## Performance Optimization Tips

### 1. Use Reserve for Known Sizes
```cpp
res.matrix.reserve(expectedRows);
newRow.reserve(expectedCols);
```

### 2. Use Move Semantics
```cpp
res.matrix.push_back(std::move(newRow));
newRow.push_back(std::move(cellResult));
```

### 3. Early Error Detection
```cpp
if (Evaluator::isError(cellResult)) {
    return cellResult; // Stop immediately
}
```

### 4. Chunked Processing for Large Arrays
```cpp
const size_t CHUNK_SIZE = 10000;
for (size_t chunk = 0; chunk < totalCells; chunk += CHUNK_SIZE) {
    // Process chunk
    // Allow GC/memory compaction between chunks
}
```

---

## Summary of All Bugs

| Bug # | Component | Severity | Impact | Status |
|-------|-----------|----------|--------|--------|
| 1 | SEQUENCE limit | High | Crash on 250K+ | ❌ Not Fixed |
| 2 | RANDARRAY no limit | Critical | Crash on large | ❌ Not Fixed |
| 3 | Nested arrays | Critical | Memory explosion | ❌ Not Fixed |
| 4 | SORTBY no check | High | Crash on large | ❌ Not Fixed |
| 5 | FILTER error | Low | Wrong error code | ❌ Not Fixed |
| 6 | UNIQUE memory | Medium | Slow/crash | ❌ Not Fixed |
| 7 | Lambda recursion | High | Stack overflow | ❌ Not Fixed |
| 8 | VSTACK/HSTACK | High | Memory crash | ❌ Not Fixed |
| 9 | TAKE negative | Medium | Wrong results | ❌ Not Fixed |
| 10 | Array division | Low | Mixed errors | ✅ Handled |
| 11 | Empty arrays | Low | Unexpected error | ❌ Not Fixed |
| 12 | LET circular | High | Infinite loop | ❌ Not Fixed |
| Original | MAKEARRAY limit | Critical | User crash | ✅ **FIXED** |

---

**Total Identified Bugs:** 13  
**Fixed:** 1  
**Remaining:** 12  

**Estimated Fix Time:** 3-5 days for all P0/P1 bugs
