# ⚡ Quick Fix Guide - Array Formula Bugs

## तुरंत Fix करने के लिए (Copy-Paste Ready Solutions)

---

## Fix #1: MAKEARRAY Limit (✅ Already Fixed)
**File:** `lambda_functions.cpp` Line 126  
**Status:** DONE

---

## Fix #2: RANDARRAY - Add Size Limit
**File:** `array_functions.cpp` - RANDARRAY function

**Add after line with `if (numCols <= 0)`:**
```cpp
long long totalCells = (long long)numRows * numCols;
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Fix #3: SEQUENCE - Increase Limit
**File:** `array_functions.cpp` - SEQUENCE function

**Find line:**
```cpp
if (totalCells > 100000) return CellError{"#NUM!"};
```

**Replace with:**
```cpp
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Fix #4: SORTBY - Add Size Check
**File:** `array_functions.cpp` - SORTBY function

**Add after `const auto& mat = ...` line:**
```cpp
size_t totalCells = mat.size() * (mat.empty() ? 0 : mat[0].size());
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Fix #5: VSTACK - Add Size Check
**File:** `array_functions.cpp` - VSTACK function

**Add before final return:**
```cpp
size_t totalCells = res.matrix.size() * (res.matrix.empty() ? 0 : res.matrix[0].size());
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Fix #6: HSTACK - Add Size Check
**File:** `array_functions.cpp` - HSTACK function

**Add before final return:**
```cpp
size_t totalCells = res.matrix.size() * (res.matrix.empty() ? 0 : res.matrix[0].size());
if (totalCells > 1048576) return CellError{"#NUM!"};
```

---

## Fix #7: BYROW - Empty Array Check
**File:** `lambda_functions.cpp` - BYROW function

**Add after `const auto& mat = ...` line:**
```cpp
if (mat.empty()) return CellError{"#VALUE!"};
```

---

## Fix #8: BYCOL - Empty Array Check
**File:** `lambda_functions.cpp` - BYCOL function

**Add after `const auto& mat = ...` line:**
```cpp
if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};
```

---

## Fix #9: UNIQUE - Add Size Limit
**File:** `array_functions.cpp` - UNIQUE function

**Add after matrix transpose (if byCol) section:**
```cpp
if (mat.size() * (mat.empty() ? 0 : mat[0].size()) > 500000) {
    return CellError{"#NUM!"};
}
```

---

## Fix #10: Lambda Recursion Depth
**File:** `evaluator.cpp` and `evaluator.h`

**In evaluator.h, add class member:**
```cpp
int lambdaRecursionDepth = 0;
static const int MAX_LAMBDA_DEPTH = 1000;
```

**In evaluator.cpp - invokeLambda function, add at start:**
```cpp
if (++lambdaRecursionDepth > MAX_LAMBDA_DEPTH) {
    --lambdaRecursionDepth;
    return CellError{"#VALUE!"};
}
```

**Add before return:**
```cpp
--lambdaRecursionDepth;
```

---

## Testing Commands (After Fixes)

```bash
# Compile tests
cd test/cpp
g++ -std=c++17 large_array_formula_test.cpp -o test_large_array

# Run test
./test_large_array

# Expected: ✅ ALL TESTS PASSED
```

---

## Quick Verification Formulas

Test these formulas in app after fixes:

### Should Work (No Crash)
```
=MAKEARRAY(1000,1000,LAMBDA(r,c,r*c))
=SEQUENCE(1000,1000)
=RANDARRAY(1000,1000)
=SORTBY(SEQUENCE(1000,1000),SEQUENCE(1000,1000))
```

### Should Return #NUM! Error (Not Crash)
```
=MAKEARRAY(2000,2000,LAMBDA(r,c,1))
=SEQUENCE(2000,2000)
=RANDARRAY(10000,10000)
```

### Should Handle Gracefully
```
=BYROW({},LAMBDA(x,SUM(x)))
=FILTER({1,2,3},{0,0,0})
=UNIQUE({})
```

---

## Critical Files to Modify

1. ✅ `lambda_functions.cpp` (MAKEARRAY fixed, BYROW/BYCOL need fix)
2. ⚠️ `array_functions.cpp` (SEQUENCE, RANDARRAY, SORTBY, VSTACK/HSTACK, UNIQUE)
3. ⚠️ `evaluator.cpp` (recursion depth tracking)
4. ⚠️ `evaluator.h` (add recursion counter)

---

## Before/After Memory Usage

### Original Code
- MAKEARRAY: Max 100K cells
- SEQUENCE: Max 100K cells  
- RANDARRAY: **UNLIMITED** ❌
- SORTBY: **UNLIMITED** ❌
- Total: Unpredictable, crashes possible

### After Fixes
- MAKEARRAY: Max 1M cells ✅
- SEQUENCE: Max 1M cells ✅
- RANDARRAY: Max 1M cells ✅
- SORTBY: Max 1M cells ✅
- Total: ~100MB max memory usage ✅

---

## Performance Impact

- ✅ Fixes add minimal overhead (~5-10 lines per function)
- ✅ Size checks are O(1) operations
- ✅ No performance degradation for normal formulas
- ✅ Prevents catastrophic memory allocation

---

## Risk Assessment

### Low Risk Fixes (Do First)
- RANDARRAY size check
- SEQUENCE limit increase
- BYROW/BYCOL empty check
- VSTACK/HSTACK size check

### Medium Risk Fixes
- SORTBY size validation
- UNIQUE size limit
- Recursion depth tracking

### Not Recommended (Complex)
- Global memory tracker (needs architecture change)
- Chunked processing (major refactor)
- Circular dependency detection (needs dependency graph)

---

## Estimated Time

- **Low Risk Fixes:** 30 minutes
- **Medium Risk Fixes:** 1-2 hours
- **Testing:** 1 hour
- **Total:** 3-4 hours

---

## Checklist

- [ ] Fix RANDARRAY size limit
- [ ] Fix SEQUENCE limit
- [ ] Fix SORTBY size check
- [ ] Fix VSTACK size check
- [ ] Fix HSTACK size check
- [ ] Fix BYROW empty array
- [ ] Fix BYCOL empty array
- [ ] Fix UNIQUE size limit
- [ ] Add recursion depth tracking
- [ ] Test with large_array_formula_test
- [ ] Test edge cases manually
- [ ] Update documentation

---

**Priority:** HIGH  
**Impact:** Prevents app crashes  
**Difficulty:** EASY to MEDIUM  
**Status:** Ready to implement
