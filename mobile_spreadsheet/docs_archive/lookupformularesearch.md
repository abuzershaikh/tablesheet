# Excel Lookup Formula Deep Research & Implementation Guide

## Table of Contents
1. [Lookup Formula Fundamentals](#lookup-formula-fundamentals)
2. [Classic Lookup Functions](#classic-lookup-functions)
3. [Modern Lookup Functions](#modern-lookup-functions)
4. [Advanced Lookup Techniques](#advanced-lookup-techniques)
5. [Error Handling & Troubleshooting](#error-handling--troubleshooting)
6. [Performance Optimization](#performance-optimization)
7. [C++ Implementation Guide](#c-implementation-guide)
8. [Testing & Validation](#testing--validation)
9. [Real-World Use Cases](#real-world-use-cases)

---

## Lookup Formula Fundamentals

### What Are Lookup Functions?
Lookup functions search for a value in one location and return a related value from another location. Every lookup operation requires three components:

```
1. LOOKUP VALUE: What you're searching for
2. LOOKUP RANGE: Where to search
3. RETURN VALUE: What to return when found
```

### Lookup Function Family Tree
```
CLASSIC FUNCTIONS (Excel 2003+)
├── VLOOKUP     - Vertical lookup (most common)
├── HLOOKUP     - Horizontal lookup
├── INDEX       - Return value by position
├── MATCH       - Find position of value
└── LOOKUP      - Vector/array lookup

MODERN FUNCTIONS (Excel 365/2021+)
├── XLOOKUP     - Replaces VLOOKUP/HLOOKUP/INDEX+MATCH
├── XMATCH      - Enhanced MATCH with more options
├── CHOOSECOLS  - Select specific columns from array
├── CHOOSEROWS  - Select specific rows from array
└── FILTER      - Filter data with conditions (also lookup-like)
```

### Match Types Explained
```cpp
enum MatchType {
    EXACT_MATCH = 0,        // Must find exact value
    LESS_THAN = -1,         // Find largest value ≤ lookup (descending sorted)
    GREATER_THAN = 1        // Find largest value ≤ lookup (ascending sorted)
};

// Usage Context:
// EXACT (0): Product codes, IDs, names (most common)
// LESS_THAN (-1): Grade scales, tax brackets (descending)
// GREATER_THAN (1): Price tiers, commission rates (ascending)
```
## Classic Lookup Functions

### 1. VLOOKUP (Vertical Lookup)
```cpp
// Syntax: VLOOKUP(lookup_value, table_array, col_index_num, [range_lookup])
// Usage: Search first column, return value from specified column

class VLookupFunction {
public:
    struct VLookupParams {
        EvalResult lookupValue;
        ArrayVal tableArray;
        int colIndexNum;
        bool rangeLookup; // TRUE=approximate, FALSE=exact
    };
    
    EvalResult execute(const VLookupParams& params) {
        // Validate column index
        if (params.colIndexNum < 1) {
            return CellError{"#VALUE!"};
        }
        
        const auto& table = params.tableArray.matrix;
        if (table.empty() || params.colIndexNum > table[0].size()) {
            return CellError{"#REF!"};
        }
        
        // Get search value
        std::string searchStr = Evaluator::asString(params.lookupValue);
        bool isNumericSearch = std::holds_alternative<double>(params.lookupValue);
        double searchNum = isNumericSearch ? std::get<double>(params.lookupValue) : 0.0;
        
        if (params.rangeLookup) {
            // Approximate match - find largest value ≤ lookup value
            return approximateMatch(table, searchStr, searchNum, 
                                  isNumericSearch, params.colIndexNum);
        } else {
            // Exact match
            return exactMatch(table, searchStr, params.colIndexNum);
        }
    }

private:
    EvalResult exactMatch(const std::vector<std::vector<EvalResult>>& table,
                         const std::string& searchValue,
                         int colIndex) {
        for (const auto& row : table) {
            if (row.empty()) continue;
            
            std::string cellValue = Evaluator::asString(row[0]);
            if (cellValue == searchValue) {
                if (colIndex - 1 < row.size()) {
                    return row[colIndex - 1];
                }
                return CellError{"#REF!"};
            }
        }
        return CellError{"#N/A"};
    }
    
    EvalResult approximateMatch(const std::vector<std::vector<EvalResult>>& table,
                               const std::string& searchStr,
                               double searchNum,
                               bool isNumeric,
                               int colIndex) {
        EvalResult bestMatch = CellError{"#N/A"};
        
        // Table MUST be sorted ascending for approximate match
        for (const auto& row : table) {
            if (row.empty()) continue;
            
            bool isLessOrEqual = false;
            if (isNumeric && std::holds_alternative<double>(row[0])) {
                double cellNum = std::get<double>(row[0]);
                if (cellNum <= searchNum) {
                    isLessOrEqual = true;
                } else {
                    break; // Past our search value in sorted list
                }
            } else {
                std::string cellStr = Evaluator::asString(row[0]);
                if (cellStr <= searchStr) {
                    isLessOrEqual = true;
                } else {
                    break;
                }
            }
            
            if (isLessOrEqual) {
                if (colIndex - 1 < row.size()) {
                    bestMatch = row[colIndex - 1];
                }
            }
        }
        
        return bestMatch;
    }
};

// Examples:
// =VLOOKUP("P001", A1:D100, 3, FALSE)  // Find product P001, return column 3
// =VLOOKUP(85, A1:B10, 2, TRUE)       // Find grade for score 85 (approximate)
// =VLOOKUP(A2, Products!A:E, 4, 0)    // Look up from another sheet
```

### 2. HLOOKUP (Horizontal Lookup)
```cpp
// Syntax: HLOOKUP(lookup_value, table_array, row_index_num, [range_lookup])
// Usage: Search first row, return value from specified row

class HLookupFunction {
public:
    EvalResult execute(const EvalResult& lookupValue,
                      const ArrayVal& tableArray,
                      int rowIndexNum,
                      bool rangeLookup = false) {
        
        const auto& table = tableArray.matrix;
        if (table.empty()) {
            return CellError{"#REF!"};
        }
        
        if (rowIndexNum < 1 || rowIndexNum > table.size()) {
            return CellError{"#REF!"};
        }
        
        const auto& searchRow = table[0]; // First row
        std::string searchValue = Evaluator::asString(lookupValue);
        
        // Search in first row
        int foundCol = -1;
        if (rangeLookup) {
            // Approximate match
            for (size_t col = 0; col < searchRow.size(); col++) {
                std::string cellValue = Evaluator::asString(searchRow[col]);
                if (cellValue <= searchValue) {
                    foundCol = col;
                } else {
                    break;
                }
            }
        } else {
            // Exact match
            for (size_t col = 0; col < searchRow.size(); col++) {
                std::string cellValue = Evaluator::asString(searchRow[col]);
                if (cellValue == searchValue) {
                    foundCol = col;
                    break;
                }
            }
        }
        
        if (foundCol == -1) {
            return CellError{"#N/A"};
        }
        
        // Return value from specified row
        const auto& resultRow = table[rowIndexNum - 1];
        if (foundCol < resultRow.size()) {
            return resultRow[foundCol];
        }
        
        return CellError{"#REF!"};
    }
};

// Examples:
// =HLOOKUP("Q1", A1:E5, 3, FALSE)     // Find Q1 in first row, return row 3
// =HLOOKUP(2024, A1:M10, 5, TRUE)     // Find year 2024, return row 5
```
### 3. INDEX Function
```cpp
// Syntax: INDEX(array, row_num, [column_num])
// Usage: Return value at specific position in array

class IndexFunction {
public:
    EvalResult execute(const ArrayVal& array,
                      int rowNum,
                      int colNum = 0) {
        
        const auto& matrix = array.matrix;
        
        if (matrix.empty()) {
            return CellError{"#REF!"};
        }
        
        // Handle different return scenarios
        if (rowNum == 0 && colNum == 0) {
            // Return entire array
            return array;
        }
        
        if (rowNum == 0) {
            // Return entire column
            if (colNum < 1 || colNum > matrix[0].size()) {
                return CellError{"#REF!"};
            }
            
            ArrayVal result;
            for (const auto& row : matrix) {
                if (colNum - 1 < row.size()) {
                    result.matrix.push_back({row[colNum - 1]});
                }
            }
            return result;
        }
        
        if (colNum == 0) {
            // Return entire row
            if (rowNum < 1 || rowNum > matrix.size()) {
                return CellError{"#REF!"};
            }
            
            ArrayVal result;
            result.matrix.push_back(matrix[rowNum - 1]);
            return result;
        }
        
        // Return specific cell
        if (rowNum < 1 || rowNum > matrix.size()) {
            return CellError{"#REF!"};
        }
        
        const auto& row = matrix[rowNum - 1];
        if (colNum < 1 || colNum > row.size()) {
            return CellError{"#REF!"};
        }
        
        return row[colNum - 1];
    }
};

// Examples:
// =INDEX(A1:C10, 5, 2)        // Return value at row 5, column 2
// =INDEX(A1:A100, 10)         // Return 10th value in single column
// =INDEX(A1:D20, 0, 3)        // Return entire column 3
```

### 4. MATCH Function
```cpp
// Syntax: MATCH(lookup_value, lookup_array, [match_type])
// Usage: Return position of value in array

class MatchFunction {
public:
    EvalResult execute(const EvalResult& lookupValue,
                      const ArrayVal& lookupArray,
                      int matchType = 1) {
        
        const auto& matrix = lookupArray.matrix;
        if (matrix.empty()) {
            return CellError{"#N/A"};
        }
        
        // Determine if array is row or column
        bool isRow = (matrix.size() == 1);
        bool isCol = (matrix.size() > 1 && matrix[0].size() == 1);
        
        if (!isRow && !isCol) {
            return CellError{"#N/A"}; // Must be 1-dimensional
        }
        
        std::string searchValue = Evaluator::asString(lookupValue);
        bool isNumericSearch = std::holds_alternative<double>(lookupValue);
        double searchNum = isNumericSearch ? std::get<double>(lookupValue) : 0.0;
        
        int count = isRow ? matrix[0].size() : matrix.size();
        
        switch (matchType) {
            case 0: // Exact match
                return exactMatchPosition(matrix, searchValue, isRow, count);
            
            case 1: // Less than or equal (ascending sort required)
                return ascendingMatch(matrix, searchValue, searchNum, 
                                    isNumericSearch, isRow, count);
            
            case -1: // Greater than or equal (descending sort required)
                return descendingMatch(matrix, searchValue, searchNum,
                                     isNumericSearch, isRow, count);
            
            default:
                return CellError{"#VALUE!"};
        }
    }

private:
    EvalResult exactMatchPosition(const std::vector<std::vector<EvalResult>>& matrix,
                                 const std::string& searchValue,
                                 bool isRow, int count) {
        for (int i = 0; i < count; i++) {
            EvalResult cell = isRow ? matrix[0][i] : matrix[i][0];
            std::string cellValue = Evaluator::asString(cell);
            
            if (cellValue == searchValue) {
                return static_cast<double>(i + 1); // 1-based position
            }
        }
        return CellError{"#N/A"};
    }
    
    EvalResult ascendingMatch(const std::vector<std::vector<EvalResult>>& matrix,
                             const std::string& searchStr,
                             double searchNum,
                             bool isNumeric,
                             bool isRow, int count) {
        int bestPos = -1;
        
        for (int i = 0; i < count; i++) {
            EvalResult cell = isRow ? matrix[0][i] : matrix[i][0];
            
            bool isLessOrEqual = false;
            if (isNumeric && std::holds_alternative<double>(cell)) {
                double cellNum = std::get<double>(cell);
                if (cellNum <= searchNum) {
                    isLessOrEqual = true;
                } else {
                    break; // Sorted ascending, no more matches
                }
            } else {
                std::string cellStr = Evaluator::asString(cell);
                if (cellStr <= searchStr) {
                    isLessOrEqual = true;
                } else {
                    break;
                }
            }
            
            if (isLessOrEqual) {
                bestPos = i;
            }
        }
        
        if (bestPos == -1) {
            return CellError{"#N/A"};
        }
        return static_cast<double>(bestPos + 1);
    }
    
    EvalResult descendingMatch(const std::vector<std::vector<EvalResult>>& matrix,
                              const std::string& searchStr,
                              double searchNum,
                              bool isNumeric,
                              bool isRow, int count) {
        int bestPos = -1;
        
        for (int i = 0; i < count; i++) {
            EvalResult cell = isRow ? matrix[0][i] : matrix[i][0];
            
            bool isGreaterOrEqual = false;
            if (isNumeric && std::holds_alternative<double>(cell)) {
                double cellNum = std::get<double>(cell);
                if (cellNum >= searchNum) {
                    isGreaterOrEqual = true;
                } else {
                    break; // Sorted descending, no more matches
                }
            } else {
                std::string cellStr = Evaluator::asString(cell);
                if (cellStr >= searchStr) {
                    isGreaterOrEqual = true;
                } else {
                    break;
                }
            }
            
            if (isGreaterOrEqual) {
                bestPos = i;
            }
        }
        
        if (bestPos == -1) {
            return CellError{"#N/A"};
        }
        return static_cast<double>(bestPos + 1);
    }
};

// Examples:
// =MATCH("Apple", A1:A100, 0)     // Find exact position of "Apple"
// =MATCH(75, A1:A20, 1)          // Find position for score 75 (ascending)
// =MATCH(100, A1:A10, -1)        // Find position for 100 (descending)
```

### 5. INDEX + MATCH Combination
```cpp
// The Power Combo: INDEX + MATCH
// More flexible than VLOOKUP - can look left, dynamic columns, faster

class IndexMatchCombo {
public:
    // Single criteria lookup
    EvalResult indexMatch(const ArrayVal& returnRange,
                         const EvalResult& lookupValue,
                         const ArrayVal& lookupRange,
                         int matchType = 0) {
        
        // Step 1: Use MATCH to find position
        MatchFunction matcher;
        auto posResult = matcher.execute(lookupValue, lookupRange, matchType);
        
        if (std::holds_alternative<CellError>(posResult)) {
            return posResult; // Return error from MATCH
        }
        
        int position = static_cast<int>(std::get<double>(posResult));
        
        // Step 2: Use INDEX to get value at that position
        IndexFunction indexer;
        return indexer.execute(returnRange, position);
    }
    
    // Two-way lookup (row and column)
    EvalResult indexMatchTwoWay(const ArrayVal& dataTable,
                               const EvalResult& rowLookup,
                               const ArrayVal& rowRange,
                               const EvalResult& colLookup,
                               const ArrayVal& colRange) {
        
        // Find row position
        MatchFunction matcher;
        auto rowPosResult = matcher.execute(rowLookup, rowRange, 0);
        if (std::holds_alternative<CellError>(rowPosResult)) {
            return rowPosResult;
        }
        int rowPos = static_cast<int>(std::get<double>(rowPosResult));
        
        // Find column position
        auto colPosResult = matcher.execute(colLookup, colRange, 0);
        if (std::holds_alternative<CellError>(colPosResult)) {
            return colPosResult;
        }
        int colPos = static_cast<int>(std::get<double>(colPosResult));
        
        // Return value at intersection
        IndexFunction indexer;
        return indexer.execute(dataTable, rowPos, colPos);
    }
};

// Examples:
// =INDEX(C1:C100, MATCH("Apple", A1:A100, 0))  // Lookup left
// =INDEX(A1:Z100, MATCH(A2,A:A,0), MATCH(B1,1:1,0))  // Two-way lookup
```
## Modern Lookup Functions

### 6. XLOOKUP Function
```cpp
// Syntax: XLOOKUP(lookup_value, lookup_array, return_array, [if_not_found], 
//                 [match_mode], [search_mode])
// The ultimate lookup function - replaces VLOOKUP, HLOOKUP, INDEX+MATCH

class XLookupFunction {
public:
    enum MatchMode {
        EXACT_MATCH = 0,
        EXACT_OR_NEXT_SMALLEST = -1,
        EXACT_OR_NEXT_LARGEST = 1,
        WILDCARD_MATCH = 2
    };
    
    enum SearchMode {
        SEARCH_FIRST_TO_LAST = 1,
        SEARCH_LAST_TO_FIRST = -1,
        BINARY_SEARCH_ASCENDING = 2,
        BINARY_SEARCH_DESCENDING = -2
    };
    
    struct XLookupParams {
        EvalResult lookupValue;
        ArrayVal lookupArray;
        ArrayVal returnArray;
        EvalResult ifNotFound;
        MatchMode matchMode;
        SearchMode searchMode;
    };
    
    EvalResult execute(const XLookupParams& params) {
        // Validate arrays have same size
        const auto& lookupMatrix = params.lookupArray.matrix;
        const auto& returnMatrix = params.returnArray.matrix;
        
        if (lookupMatrix.empty()) {
            return CellError{"#VALUE!"};
        }
        
        // Flatten lookup array to 1D
        std::vector<EvalResult> lookupCells = flattenArray(lookupMatrix);
        std::vector<EvalResult> returnCells = flattenReturnArray(returnMatrix);
        
        if (lookupCells.size() > returnCells.size()) {
            return CellError{"#VALUE!"};
        }
        
        // Perform search based on search mode
        int foundIndex = -1;
        
        switch (params.searchMode) {
            case SEARCH_FIRST_TO_LAST:
                foundIndex = searchForward(lookupCells, params.lookupValue, params.matchMode);
                break;
            
            case SEARCH_LAST_TO_FIRST:
                foundIndex = searchBackward(lookupCells, params.lookupValue, params.matchMode);
                break;
            
            case BINARY_SEARCH_ASCENDING:
                foundIndex = binarySearchAsc(lookupCells, params.lookupValue, params.matchMode);
                break;
            
            case BINARY_SEARCH_DESCENDING:
                foundIndex = binarySearchDesc(lookupCells, params.lookupValue, params.matchMode);
                break;
        }
        
        if (foundIndex == -1) {
            return params.ifNotFound;
        }
        
        // Return result - could be single value or entire row/column
        if (returnMatrix.size() == 1) {
            // Horizontal return array
            if (foundIndex < returnMatrix[0].size()) {
                return returnMatrix[0][foundIndex];
            }
        } else if (returnMatrix[0].size() == 1) {
            // Vertical return array (single column)
            if (foundIndex < returnMatrix.size()) {
                return returnMatrix[foundIndex][0];
            }
        } else {
            // Multiple columns - return entire row as array
            if (foundIndex < returnMatrix.size()) {
                ArrayVal result;
                result.matrix.push_back(returnMatrix[foundIndex]);
                return result;
            }
        }
        
        return CellError{"#REF!"};
    }

private:
    std::vector<EvalResult> flattenArray(const std::vector<std::vector<EvalResult>>& matrix) {
        std::vector<EvalResult> flat;
        if (matrix.size() == 1) {
            // Horizontal array
            return matrix[0];
        } else {
            // Vertical array - take first column
            for (const auto& row : matrix) {
                if (!row.empty()) {
                    flat.push_back(row[0]);
                }
            }
        }
        return flat;
    }
    
    std::vector<EvalResult> flattenReturnArray(const std::vector<std::vector<EvalResult>>& matrix) {
        std::vector<EvalResult> flat;
        if (matrix.size() == 1 || matrix[0].size() == 1) {
            return flattenArray(matrix);
        }
        // For multi-column return, we keep the structure
        return flat; // Empty indicates multi-column
    }
    
    int searchForward(const std::vector<EvalResult>& lookupCells,
                     const EvalResult& lookupValue,
                     MatchMode matchMode) {
        
        std::string searchStr = Evaluator::asString(lookupValue);
        bool isNumeric = std::holds_alternative<double>(lookupValue);
        double searchNum = isNumeric ? std::get<double>(lookupValue) : 0.0;
        
        int bestMatch = -1;
        
        for (size_t i = 0; i < lookupCells.size(); i++) {
            if (matchesValue(lookupCells[i], searchStr, searchNum, 
                           isNumeric, matchMode)) {
                if (matchMode == EXACT_MATCH || matchMode == WILDCARD_MATCH) {
                    return i; // Return first match
                }
                bestMatch = i; // Keep updating for approximate match
            }
        }
        
        return bestMatch;
    }
    
    int searchBackward(const std::vector<EvalResult>& lookupCells,
                      const EvalResult& lookupValue,
                      MatchMode matchMode) {
        
        std::string searchStr = Evaluator::asString(lookupValue);
        bool isNumeric = std::holds_alternative<double>(lookupValue);
        double searchNum = isNumeric ? std::get<double>(lookupValue) : 0.0;
        
        // Search from end to start
        for (int i = lookupCells.size() - 1; i >= 0; i--) {
            if (matchesValue(lookupCells[i], searchStr, searchNum,
                           isNumeric, matchMode)) {
                return i; // Return last match
            }
        }
        
        return -1;
    }
    
    bool matchesValue(const EvalResult& cell,
                     const std::string& searchStr,
                     double searchNum,
                     bool isNumeric,
                     MatchMode matchMode) {
        
        switch (matchMode) {
            case EXACT_MATCH: {
                std::string cellStr = Evaluator::asString(cell);
                return cellStr == searchStr;
            }
            
            case EXACT_OR_NEXT_SMALLEST: {
                if (isNumeric && std::holds_alternative<double>(cell)) {
                    double cellNum = std::get<double>(cell);
                    return cellNum <= searchNum;
                }
                std::string cellStr = Evaluator::asString(cell);
                return cellStr <= searchStr;
            }
            
            case EXACT_OR_NEXT_LARGEST: {
                if (isNumeric && std::holds_alternative<double>(cell)) {
                    double cellNum = std::get<double>(cell);
                    return cellNum >= searchNum;
                }
                std::string cellStr = Evaluator::asString(cell);
                return cellStr >= searchStr;
            }
            
            case WILDCARD_MATCH: {
                // Support * and ? wildcards
                return wildcardMatch(Evaluator::asString(cell), searchStr);
            }
        }
        
        return false;
    }
    
    bool wildcardMatch(const std::string& text, const std::string& pattern) {
        // Convert Excel wildcards to regex
        std::string regexPattern = "^";
        for (char c : pattern) {
            if (c == '*') {
                regexPattern += ".*";
            } else if (c == '?') {
                regexPattern += ".";
            } else if (c == '~') {
                // Escape character
                continue;
            } else {
                if (std::string(".+()[]{}^$|\\").find(c) != std::string::npos) {
                    regexPattern += '\\';
                }
                regexPattern += c;
            }
        }
        regexPattern += "$";
        
        try {
            std::regex re(regexPattern, std::regex_constants::icase);
            return std::regex_match(text, re);
        } catch (...) {
            return text == pattern;
        }
    }
    
    int binarySearchAsc(const std::vector<EvalResult>& lookupCells,
                       const EvalResult& lookupValue,
                       MatchMode matchMode) {
        // Binary search for sorted ascending data
        // Implementation similar to std::lower_bound
        int left = 0;
        int right = lookupCells.size() - 1;
        int result = -1;
        
        std::string searchStr = Evaluator::asString(lookupValue);
        bool isNumeric = std::holds_alternative<double>(lookupValue);
        double searchNum = isNumeric ? std::get<double>(lookupValue) : 0.0;
        
        while (left <= right) {
            int mid = left + (right - left) / 2;
            
            int cmp = compareValues(lookupCells[mid], searchStr, searchNum, isNumeric);
            
            if (cmp == 0) {
                return mid; // Exact match
            } else if (cmp < 0) {
                result = mid; // Potential match for approximate
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        
        return matchMode == EXACT_MATCH ? -1 : result;
    }
    
    int binarySearchDesc(const std::vector<EvalResult>& lookupCells,
                        const EvalResult& lookupValue,
                        MatchMode matchMode) {
        // Binary search for sorted descending data
        int left = 0;
        int right = lookupCells.size() - 1;
        int result = -1;
        
        std::string searchStr = Evaluator::asString(lookupValue);
        bool isNumeric = std::holds_alternative<double>(lookupValue);
        double searchNum = isNumeric ? std::get<double>(lookupValue) : 0.0;
        
        while (left <= right) {
            int mid = left + (right - left) / 2;
            
            int cmp = compareValues(lookupCells[mid], searchStr, searchNum, isNumeric);
            
            if (cmp == 0) {
                return mid;
            } else if (cmp > 0) {
                result = mid;
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        
        return matchMode == EXACT_MATCH ? -1 : result;
    }
    
    int compareValues(const EvalResult& cell,
                     const std::string& searchStr,
                     double searchNum,
                     bool isNumeric) {
        if (isNumeric && std::holds_alternative<double>(cell)) {
            double cellNum = std::get<double>(cell);
            if (cellNum < searchNum) return -1;
            if (cellNum > searchNum) return 1;
            return 0;
        }
        
        std::string cellStr = Evaluator::asString(cell);
        if (cellStr < searchStr) return -1;
        if (cellStr > searchStr) return 1;
        return 0;
    }
};

// Examples:
// =XLOOKUP(A2, B:B, C:C)                        // Simple lookup
// =XLOOKUP(A2, B:B, C:C, "Not Found")          // With custom error message
// =XLOOKUP(A2, B:B, C:E)                        // Return multiple columns
// =XLOOKUP(A2, B:B, C:C, , 0, -1)              // Search from bottom
// =XLOOKUP(A2, B:B, C:C, , -1)                 // Approximate match
// =XLOOKUP("App*", B:B, C:C, , 2)              // Wildcard match
```
### 7. XMATCH Function
```cpp
// Syntax: XMATCH(lookup_value, lookup_array, [match_mode], [search_mode])
// Enhanced MATCH with more options

class XMatchFunction {
public:
    enum MatchMode {
        EXACT_MATCH = 0,
        EXACT_OR_NEXT_SMALLEST = -1,
        EXACT_OR_NEXT_LARGEST = 1,
        WILDCARD_MATCH = 2
    };
    
    enum SearchMode {
        SEARCH_FIRST_TO_LAST = 1,
        SEARCH_LAST_TO_FIRST = -1,
        BINARY_SEARCH_ASCENDING = 2,
        BINARY_SEARCH_DESCENDING = -2
    };
    
    EvalResult execute(const EvalResult& lookupValue,
                      const ArrayVal& lookupArray,
                      MatchMode matchMode = EXACT_MATCH,
                      SearchMode searchMode = SEARCH_FIRST_TO_LAST) {
        
        // Similar logic to XLOOKUP's search but returns position
        // Returns 1-based position like MATCH
        
        const auto& matrix = lookupArray.matrix;
        std::vector<EvalResult> cells;
        
        // Flatten to 1D
        if (matrix.size() == 1) {
            cells = matrix[0];
        } else {
            for (const auto& row : matrix) {
                if (!row.empty()) {
                    cells.push_back(row[0]);
                }
            }
        }
        
        // Use XLOOKUP's search logic
        // (Reuse searchForward, searchBackward, binary search methods)
        
        int position = searchWithMode(cells, lookupValue, matchMode, searchMode);
        
        if (position == -1) {
            return CellError{"#N/A"};
        }
        
        return static_cast<double>(position + 1); // 1-based
    }
};

// Examples:
// =XMATCH(A2, B:B)                 // Exact match
// =XMATCH(A2, B:B, 0, -1)         // Exact match from bottom
// =XMATCH(A2, B:B, -1, 2)         // Approximate, binary search
// =XMATCH("App*", B:B, 2)         // Wildcard match
```

### 8. CHOOSECOLS & CHOOSEROWS
```cpp
// CHOOSECOLS: Select specific columns from array
class ChooseColsFunction {
public:
    EvalResult execute(const ArrayVal& array,
                      const std::vector<int>& columnNumbers) {
        
        const auto& matrix = array.matrix;
        if (matrix.empty()) {
            return CellError{"#VALUE!"};
        }
        
        ArrayVal result;
        
        for (const auto& row : matrix) {
            std::vector<EvalResult> newRow;
            
            for (int colNum : columnNumbers) {
                if (colNum < 1 || colNum > row.size()) {
                    return CellError{"#VALUE!"};
                }
                newRow.push_back(row[colNum - 1]);
            }
            
            result.matrix.push_back(newRow);
        }
        
        return result;
    }
};

// CHOOSEROWS: Select specific rows from array  
class ChooseRowsFunction {
public:
    EvalResult execute(const ArrayVal& array,
                      const std::vector<int>& rowNumbers) {
        
        const auto& matrix = array.matrix;
        if (matrix.empty()) {
            return CellError{"#VALUE!"};
        }
        
        ArrayVal result;
        
        for (int rowNum : rowNumbers) {
            if (rowNum < 1 || rowNum > matrix.size()) {
                return CellError{"#VALUE!"};
            }
            result.matrix.push_back(matrix[rowNum - 1]);
        }
        
        return result;
    }
};

// Examples:
// =CHOOSECOLS(A1:E10, 1, 3, 5)    // Get columns 1, 3, 5
// =CHOOSEROWS(A1:E10, 2, 4, 6)    // Get rows 2, 4, 6
// =CHOOSECOLS(A1:Z100, XMATCH(B1, A1:Z1))  // Dynamic column selection
```
## Error Handling & Troubleshooting

### Common Lookup Errors

#### 1. #N/A Error
```cpp
class LookupErrorHandler {
public:
    enum ErrorCause {
        VALUE_NOT_FOUND,
        WRONG_MATCH_TYPE,
        UNSORTED_DATA,
        WRONG_LOOKUP_RANGE,
        TYPO_IN_DATA,
        LEADING_TRAILING_SPACES,
        DATA_TYPE_MISMATCH
    };
    
    struct ErrorDiagnostics {
        ErrorCause cause;
        std::string message;
        std::string solution;
    };
    
    ErrorDiagnostics diagnoseNA(const std::string& lookupValue,
                               const ArrayVal& lookupRange,
                               bool approximateMatch) {
        
        ErrorDiagnostics diag;
        
        // Check if value exists at all
        bool valueExists = checkValueExists(lookupValue, lookupRange);
        
        if (!valueExists) {
            diag.cause = VALUE_NOT_FOUND;
            diag.message = "Lookup value '" + lookupValue + "' not found";
            diag.solution = "1. Check spelling\n2. Verify data exists\n3. Use IFERROR to handle";
            return diag;
        }
        
        // Check for spaces
        if (hasSpaceIssues(lookupValue, lookupRange)) {
            diag.cause = LEADING_TRAILING_SPACES;
            diag.message = "Spaces detected in lookup value or range";
            diag.solution = "Use TRIM() function: =VLOOKUP(TRIM(A2), TRIM(B:B), 2, 0)";
            return diag;
        }
        
        // Check data types
        if (hasDataTypeMismatch(lookupValue, lookupRange)) {
            diag.cause = DATA_TYPE_MISMATCH;
            diag.message = "Data type mismatch (number vs text)";
            diag.solution = "Convert data types: =VLOOKUP(VALUE(A2), B:B, 2, 0)";
            return diag;
        }
        
        // Check sort order for approximate match
        if (approximateMatch && !isSorted(lookupRange)) {
            diag.cause = UNSORTED_DATA;
            diag.message = "Data must be sorted for approximate match";
            diag.solution = "Sort data ascending or use exact match (FALSE)";
            return diag;
        }
        
        diag.cause = WRONG_LOOKUP_RANGE;
        diag.message = "Unknown cause";
        diag.solution = "Review formula and data carefully";
        return diag;
    }

private:
    bool checkValueExists(const std::string& value, const ArrayVal& range) {
        for (const auto& row : range.matrix) {
            for (const auto& cell : row) {
                if (Evaluator::asString(cell) == value) {
                    return true;
                }
            }
        }
        return false;
    }
    
    bool hasSpaceIssues(const std::string& value, const ArrayVal& range) {
        // Check for leading/trailing spaces
        if (value != trim(value)) {
            return true;
        }
        
        for (const auto& row : range.matrix) {
            for (const auto& cell : row) {
                std::string cellStr = Evaluator::asString(cell);
                if (cellStr != trim(cellStr)) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    bool hasDataTypeMismatch(const std::string& value, const ArrayVal& range) {
        bool lookupIsNumeric = isNumericString(value);
        
        for (const auto& row : range.matrix) {
            if (row.empty()) continue;
            
            bool cellIsNumeric = std::holds_alternative<double>(row[0]);
            if (lookupIsNumeric != cellIsNumeric) {
                return true;
            }
        }
        
        return false;
    }
    
    bool isSorted(const ArrayVal& range) {
        if (range.matrix.size() <= 1) return true;
        
        for (size_t i = 1; i < range.matrix.size(); i++) {
            if (range.matrix[i].empty() || range.matrix[i-1].empty()) continue;
            
            try {
                double prev = Evaluator::asNumber(range.matrix[i-1][0]);
                double curr = Evaluator::asNumber(range.matrix[i][0]);
                if (curr < prev) return false;
            } catch (...) {
                std::string prev = Evaluator::asString(range.matrix[i-1][0]);
                std::string curr = Evaluator::asString(range.matrix[i][0]);
                if (curr < prev) return false;
            }
        }
        
        return true;
    }
};

// Handling #N/A with IFERROR
// =IFERROR(VLOOKUP(A2, B:C, 2, 0), "Not Found")
// =IFNA(XLOOKUP(A2, B:B, C:C), "Not Found")
```

#### 2. #REF! Error
```cpp
class RefErrorHandler {
public:
    enum RefErrorCause {
        COLUMN_INDEX_TOO_LARGE,
        COLUMN_INDEX_NEGATIVE,
        ROW_INDEX_OUT_OF_BOUNDS,
        DELETED_REFERENCE,
        INVALID_RANGE
    };
    
    RefErrorCause diagnoseRefError(int colIndex, const ArrayVal& table) {
        if (colIndex < 1) {
            return COLUMN_INDEX_NEGATIVE;
        }
        
        if (table.matrix.empty()) {
            return INVALID_RANGE;
        }
        
        size_t maxCols = 0;
        for (const auto& row : table.matrix) {
            maxCols = std::max(maxCols, row.size());
        }
        
        if (colIndex > maxCols) {
            return COLUMN_INDEX_TOO_LARGE;
        }
        
        return INVALID_RANGE;
    }
    
    std::string getSolution(RefErrorCause cause) {
        switch (cause) {
            case COLUMN_INDEX_TOO_LARGE:
                return "Column index exceeds table width. Check col_index_num parameter.";
            
            case COLUMN_INDEX_NEGATIVE:
                return "Column index must be >= 1. Check col_index_num parameter.";
            
            case ROW_INDEX_OUT_OF_BOUNDS:
                return "Row index exceeds table height. Check row_index_num parameter.";
            
            case DELETED_REFERENCE:
                return "Referenced range was deleted. Update formula with valid range.";
            
            case INVALID_RANGE:
                return "Invalid or empty range reference. Check table_array parameter.";
        }
        return "Unknown #REF! error";
    }
};

// Common #REF! fixes:
// 1. =VLOOKUP(A2, B:D, 5, 0)  // ERROR: Only 3 columns (B,C,D), asking for 5th
//    Fix: =VLOOKUP(A2, B:D, 3, 0)
//
// 2. =INDEX(A:C, 5, 5)  // ERROR: Only 3 columns, asking for 5th
//    Fix: =INDEX(A:C, 5, 3)
```

#### 3. #VALUE! Error
```cpp
class ValueErrorHandler {
public:
    enum ValueErrorCause {
        INVALID_MATCH_TYPE,
        NON_NUMERIC_COLUMN_INDEX,
        ARRAY_SIZE_MISMATCH,
        INVALID_SEARCH_MODE,
        TEXT_IN_NUMERIC_OPERATION
    };
    
    std::string diagnoseAndFix(ValueErrorCause cause) {
        switch (cause) {
            case INVALID_MATCH_TYPE:
                return "Match type must be -1, 0, or 1\n"
                       "Fix: =VLOOKUP(A2, B:C, 2, 0) or =VLOOKUP(A2, B:C, 2, FALSE)";
            
            case NON_NUMERIC_COLUMN_INDEX:
                return "Column index must be a number\n"
                       "Fix: Change 'Two' to 2 in =VLOOKUP(A2, B:D, 'Two', 0)";
            
            case ARRAY_SIZE_MISMATCH:
                return "Lookup array and return array must have same size\n"
                       "Fix: Ensure both ranges have equal rows";
            
            case INVALID_SEARCH_MODE:
                return "Search mode must be -2, -1, 1, or 2\n"
                       "Fix: Use valid search mode in XLOOKUP";
            
            case TEXT_IN_NUMERIC_OPERATION:
                return "Cannot perform numeric operation on text\n"
                       "Fix: Ensure data types are consistent";
        }
        return "Unknown #VALUE! error";
    }
};
```

### Data Cleaning for Lookups
```cpp
class LookupDataCleaner {
public:
    // Remove leading/trailing spaces
    std::string trim(const std::string& str) {
        size_t start = str.find_first_not_of(" \t\r\n");
        size_t end = str.find_last_not_of(" \t\r\n");
        
        if (start == std::string::npos) return "";
        return str.substr(start, end - start + 1);
    }
    
    // Convert text numbers to actual numbers
    EvalResult textToNumber(const EvalResult& value) {
        if (std::holds_alternative<std::string>(value)) {
            try {
                std::string str = std::get<std::string>(value);
                return std::stod(str);
            } catch (...) {
                return value; // Can't convert
            }
        }
        return value;
    }
    
    // Clean entire lookup range
    ArrayVal cleanLookupRange(const ArrayVal& dirty) {
        ArrayVal clean;
        
        for (const auto& row : dirty.matrix) {
            std::vector<EvalResult> cleanRow;
            for (const auto& cell : row) {
                if (std::holds_alternative<std::string>(cell)) {
                    std::string str = std::get<std::string>(cell);
                    cleanRow.push_back(trim(str));
                } else {
                    cleanRow.push_back(cell);
                }
            }
            clean.matrix.push_back(cleanRow);
        }
        
        return clean;
    }
    
    // Check for duplicates in lookup column
    bool hasDuplicates(const ArrayVal& lookupRange) {
        std::set<std::string> seen;
        
        for (const auto& row : lookupRange.matrix) {
            if (row.empty()) continue;
            
            std::string key = Evaluator::asString(row[0]);
            if (seen.find(key) != seen.end()) {
                return true; // Duplicate found
            }
            seen.insert(key);
        }
        
        return false;
    }
};

// Example usage in formula:
// =VLOOKUP(TRIM(A2), TRIM(B:B), 2, 0)  // Clean spaces
// =VLOOKUP(VALUE(A2), B:C, 2, 0)       // Convert text to number
```