# BUG-02: Unnormalized Cell References in Grid Lookup

## Bug Overview

- **Bug ID**: `BUG-02`
- **Bug Name**: Unnormalized Cell References in Grid Lookup
- **File Location**: [`android/app/src/main/cpp/grid_manager.cpp`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/android/app/src/main/cpp/grid_manager.cpp)
- **Component**: Native C++ Grid Manager (`dfsEvaluate`)
- **Severity**: High (Caused formulas referencing lowercase or absolute cell coordinates to return `0.0`)

---

## Detailed Description & Root Cause

The C++ `GridManager` stores cell nodes in an `std::unordered_map<std::string, CellNode> grid`, where keys are formatted as uppercase cell references without dollar signs (e.g., `"A1"`, `"B10"`).

When `dfsEvaluate(cellRef, iterationDepth)` was called, it directly searched `grid.find(cellRef)` without normalizing `cellRef`.

### Why it failed:
1. If a user entered `=a1+b1` (lowercase) or `=$A$1+$B$1` (absolute reference), `CellReferenceNode` passed `"a1"` or `"$A$1"` into `dfsEvaluate()`.
2. `grid.find("a1")` or `grid.find("$A$1")` returned `grid.end()`.
3. Unfound cell references defaulted to `0.0`, resulting in incorrect formula sums or zero outputs.

---

## How It Was Fixed

Added automatic coordinate normalization at the start of `GridManager::dfsEvaluate()`. The function uses `Evaluator::parseCellCoordinates()` to strip dollar signs and convert row/column numbers into standard uppercase keys (`coordToCellRef()`).

### Diff:

```diff
 EvalResult GridManager::dfsEvaluate(const std::string& cellRef, int iterationDepth) {
     if (iterationDepth > 500) {
         return CellError{"#CALC!"};
     }
+    std::string cleanRef = cellRef;
+    int normR = 0, normC = 0;
+    if (Evaluator::parseCellCoordinates(cellRef, normR, normC)) {
+        cleanRef = coordToCellRef(normR, normC);
+    }
-    auto it = grid.find(cellRef);
+    auto it = grid.find(cleanRef);
     if (it == grid.end()) {
-        auto sIt = spillGrid.find(cellRef);
+        auto sIt = spillGrid.find(cleanRef);
```

---

## Verification

Cell references using any format (`a1`, `A1`, `$a$1`, `$A$1`, `a$1`, `$a1`) now resolve to `"A1"` in `grid`, ensuring consistent and accurate formula evaluations.
