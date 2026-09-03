# Array Formula Deep Research & Implementation Guide

## Table of Contents
1. [Array Formula Fundamentals](#array-formula-fundamentals)
2. [Legacy CSE vs Dynamic Arrays](#legacy-cse-vs-dynamic-arrays)
3. [Core Array Functions Analysis](#core-array-functions-analysis)
4. [Implementation Logic & Algorithms](#implementation-logic--algorithms)
5. [Memory Management & Performance](#memory-management--performance)
6. [Spill Range Calculation Engine](#spill-range-calculation-engine)
7. [Error Handling & Edge Cases](#error-handling--edge-cases)
8. [C++ Implementation Strategy](#c-implementation-strategy)
9. [Testing & Validation Framework](#testing--validation-framework)
10. [Advanced Array Operations](#advanced-array-operations)

---

## Array Formula Fundamentals

### What Are Array Formulas?
Array formulas are Excel's mechanism for processing multiple values simultaneously in a single formula operation. Unlike regular formulas that work on individual cells, array formulas can:
- Process entire ranges as single units
- Return multiple results from one formula
- Perform element-wise operations across arrays
- Handle matrix calculations efficiently

### Types of Array Processing
```
1. INPUT ARRAYS: Ranges that provide data to formulas
   - Single column: A1:A10
   - Single row: B1:F1  
   - 2D Matrix: A1:C5
   - Non-contiguous: (A1:A5, C1:C5)

2. OUTPUT ARRAYS: Results returned by formulas
   - Scalar: Single value result
   - Vector: Single row/column result
   - Matrix: 2D grid result
   - Spilled: Dynamic size result
```

### Array Formula Categories
```cpp
// Element-wise Operations
{=A1:A5 + B1:B5}        // Add corresponding elements
{=A1:A5 * 2}            // Multiply each element by 2
{=A1:A5 > 100}          // Boolean comparison array

// Aggregate Operations  
{=SUM(A1:A5 * B1:B5)}   // Sum of products
{=MAX(A1:A5)}           // Maximum value
{=AVERAGE(A1:A5)}       // Average value

// Conditional Operations
{=SUM((A1:A5>100)*(B1:B5))}  // Conditional sum
{=COUNT(A1:A5<50)}           // Count matching criteria

// Matrix Operations
{=MMULT(A1:B3,D1:E2)}   // Matrix multiplication
{=TRANSPOSE(A1:C5)}     // Matrix transpose
{=MINVERSE(A1:C3)}      // Matrix inverse
```
## Legacy CSE vs Dynamic Arrays

### Legacy CSE Arrays (Ctrl+Shift+Enter)
```cpp
// Characteristics:
- Require Ctrl+Shift+Enter to enter
- Display with curly braces {=formula}
- Fixed output range (pre-selected)
- Same formula in all output cells
- Backward compatible to Excel 2007
- Multi-cell selection required for array output

// Implementation Logic:
1. User selects output range (e.g., C1:C10)
2. Types formula (e.g., =A1:A10*B1:B10)
3. Presses Ctrl+Shift+Enter
4. Excel wraps with {} and copies to all selected cells
5. Each cell evaluates the formula but returns its position's result
```

### Modern Dynamic Arrays (Spill Behavior)
```cpp
// Characteristics:
- Automatic spilling from single cell
- No Ctrl+Shift+Enter required
- Dynamic output size (auto-resize)
- Blue border around spill range
- Available in Excel 365/2021+
- Single formula cell with dependent spill cells

// Implementation Logic:
1. User types formula in single cell (e.g., A1: =FILTER(D:D,E:E>100))
2. Excel calculates result array size
3. Checks if spill range is clear
4. Populates adjacent cells with results
5. Creates spill dependency relationships
6. Updates automatically when source data changes
```

### Spill Range Calculation Algorithm
```cpp
class SpillRangeCalculator {
private:
    struct SpillRange {
        int startRow, startCol;
        int numRows, numCols;
        bool isBlocked;
        std::vector<std::pair<int,int>> obstructingCells;
    };
    
public:
    SpillRange calculateSpillRange(const EvalResult& arrayResult, 
                                 int originRow, int originCol,
                                 const SpreadsheetModel& sheet) {
        SpillRange range;
        range.startRow = originRow;
        range.startCol = originCol;
        
        if (std::holds_alternative<ArrayVal>(arrayResult)) {
            const auto& matrix = std::get<ArrayVal>(arrayResult).matrix;
            range.numRows = matrix.size();
            range.numCols = matrix.empty() ? 0 : matrix[0].size();
            
            // Check for obstructions
            range.isBlocked = false;
            for (int r = 0; r < range.numRows; r++) {
                for (int c = 0; c < range.numCols; c++) {
                    int cellRow = originRow + r;
                    int cellCol = originCol + c;
                    
                    // Skip the origin cell
                    if (r == 0 && c == 0) continue;
                    
                    if (sheet.cellHasContent(cellRow, cellCol)) {
                        range.isBlocked = true;
                        range.obstructingCells.push_back({cellRow, cellCol});
                    }
                }
            }
        } else {
            // Scalar result - no spill
            range.numRows = 1;
            range.numCols = 1;
            range.isBlocked = false;
        }
        
        return range;
    }
};
```
## Core Array Functions Analysis

### 1. FILTER Function
```cpp
// Syntax: FILTER(array, include, [if_empty])
// Logic: Return subset of array where include condition is TRUE

class FilterFunction {
public:
    EvalResult execute(const ArrayVal& sourceArray, 
                      const ArrayVal& includeArray, 
                      const EvalResult& ifEmpty = CellError{"#CALC!"}) {
        
        // Validate dimensions
        if (sourceArray.matrix.size() != includeArray.matrix.size()) {
            return CellError{"#VALUE!"};
        }
        
        ArrayVal result;
        bool hasResults = false;
        
        for (size_t row = 0; row < sourceArray.matrix.size(); row++) {
            // Check if we should include this row
            bool includeRow = false;
            if (row < includeArray.matrix.size() && 
                !includeArray.matrix[row].empty()) {
                includeRow = Evaluator::asBool(includeArray.matrix[row][0]);
            }
            
            if (includeRow) {
                result.matrix.push_back(sourceArray.matrix[row]);
                hasResults = true;
            }
        }
        
        if (!hasResults) {
            if (std::holds_alternative<CellError>(ifEmpty)) {
                return ifEmpty;
            }
            // Return empty result
            result.matrix.push_back({ifEmpty});
        }
        
        return result;
    }
};

// Usage Examples:
// =FILTER(A:A, B:B>100)           // Filter A where B > 100
// =FILTER(A1:C10, A1:A10="East")  // Filter rows where column A = "East"
// =FILTER(A:A, B:B<>"", "No Data") // Filter non-empty B, show "No Data" if none
```

### 2. SORT Function  
```cpp
// Syntax: SORT(array, [sort_index], [sort_order], [by_col])
// Logic: Sort array by specified column/row

class SortFunction {
public:
    EvalResult execute(const ArrayVal& sourceArray,
                      int sortIndex = 1,
                      int sortOrder = 1,  // 1=ascending, -1=descending
                      bool byColumn = false) {
        
        if (sourceArray.matrix.empty()) {
            return sourceArray;
        }
        
        ArrayVal result = sourceArray; // Copy for sorting
        
        if (byColumn) {
            // Sort columns by specified row
            int rowIndex = std::abs(sortIndex) - 1;
            if (rowIndex >= result.matrix.size()) {
                return CellError{"#VALUE!"};
            }
            
            // Transpose, sort, transpose back
            result = transposeArray(result);
            sortRowsByColumn(result, rowIndex, sortOrder > 0);
            result = transposeArray(result);
        } else {
            // Sort rows by specified column  
            int colIndex = std::abs(sortIndex) - 1;
            sortRowsByColumn(result, colIndex, sortOrder > 0);
        }
        
        return result;
    }

private:
    void sortRowsByColumn(ArrayVal& array, int colIndex, bool ascending) {
        std::sort(array.matrix.begin(), array.matrix.end(),
            [colIndex, ascending](const std::vector<EvalResult>& a, 
                                const std::vector<EvalResult>& b) {
                // Get values for comparison
                EvalResult aVal = (colIndex < a.size()) ? a[colIndex] : Blank{};
                EvalResult bVal = (colIndex < b.size()) ? b[colIndex] : Blank{};
                
                // Compare based on type
                bool result = compareArrayElements(aVal, bVal);
                return ascending ? result : !result;
            });
    }
    
    bool compareArrayElements(const EvalResult& a, const EvalResult& b) {
        // Numbers < Text < Logical < Errors < Blank
        int aType = getValueType(a);
        int bType = getValueType(b);
        
        if (aType != bType) return aType < bType;
        
        // Same type comparison
        if (std::holds_alternative<double>(a) && std::holds_alternative<double>(b)) {
            return std::get<double>(a) < std::get<double>(b);
        }
        if (std::holds_alternative<std::string>(a) && std::holds_alternative<std::string>(b)) {
            return std::get<std::string>(a) < std::get<std::string>(b);
        }
        
        return false; // Equal or complex comparison
    }
};

// Usage Examples:
// =SORT(A1:C10)                    // Sort by first column ascending
// =SORT(A1:C10, 2, -1)            // Sort by column 2 descending  
// =SORT(A1:C10, 1, 1, TRUE)       // Sort by first row (by column)
```
### 3. UNIQUE Function
```cpp
// Syntax: UNIQUE(array, [by_col], [exactly_once])
// Logic: Return unique values from array

class UniqueFunction {
public:
    EvalResult execute(const ArrayVal& sourceArray,
                      bool byColumn = false,
                      bool exactlyOnce = false) {
        
        if (sourceArray.matrix.empty()) {
            return sourceArray;
        }
        
        ArrayVal result;
        std::set<std::string> seenValues;
        std::map<std::string, int> valueCounts;
        
        if (byColumn) {
            // Process columns for uniqueness
            ArrayVal transposed = transposeArray(sourceArray);
            return processUniqueRows(transposed, exactlyOnce);
        } else {
            // Process rows for uniqueness
            return processUniqueRows(sourceArray, exactlyOnce);
        }
    }

private:
    ArrayVal processUniqueRows(const ArrayVal& array, bool exactlyOnce) {
        ArrayVal result;
        std::map<std::string, int> rowCounts;
        std::vector<std::string> rowKeys;
        
        // First pass: count occurrences
        for (const auto& row : array.matrix) {
            std::string rowKey = createRowKey(row);
            rowCounts[rowKey]++;
            if (rowCounts[rowKey] == 1) {
                rowKeys.push_back(rowKey);
            }
        }
        
        // Second pass: collect unique rows
        std::set<std::string> addedRows;
        for (const auto& row : array.matrix) {
            std::string rowKey = createRowKey(row);
            
            bool shouldAdd = false;
            if (exactlyOnce) {
                shouldAdd = (rowCounts[rowKey] == 1);
            } else {
                shouldAdd = (addedRows.find(rowKey) == addedRows.end());
            }
            
            if (shouldAdd) {
                result.matrix.push_back(row);
                addedRows.insert(rowKey);
            }
        }
        
        return result;
    }
    
    std::string createRowKey(const std::vector<EvalResult>& row) {
        std::string key = "";
        for (const auto& cell : row) {
            key += Evaluator::asString(cell) + "|";
        }
        return key;
    }
};

// Usage Examples:
// =UNIQUE(A1:A10)              // Unique values from column A
// =UNIQUE(A1:C10, FALSE, TRUE) // Rows that appear exactly once
// =UNIQUE(A1:C10, TRUE)        // Unique columns
```

### 4. SEQUENCE Function
```cpp
// Syntax: SEQUENCE(rows, [columns], [start], [step])
// Logic: Generate sequential numbers in array

class SequenceFunction {
public:
    EvalResult execute(int rows, 
                      int columns = 1,
                      double start = 1.0,
                      double step = 1.0) {
        
        if (rows <= 0 || columns <= 0) {
            return CellError{"#VALUE!"};
        }
        
        // Limit array size for performance
        if (rows > 1048576 || columns > 16384) {
            return CellError{"#NUM!"};
        }
        
        ArrayVal result;
        double currentValue = start;
        
        for (int r = 0; r < rows; r++) {
            std::vector<EvalResult> row;
            for (int c = 0; c < columns; c++) {
                row.push_back(currentValue);
                currentValue += step;
            }
            result.matrix.push_back(row);
        }
        
        return result;
    }
};

// Usage Examples:
// =SEQUENCE(5)                 // Generate 1,2,3,4,5 in column
// =SEQUENCE(3,4)               // Generate 3x4 matrix starting from 1
// =SEQUENCE(5,1,10,2)          // Generate 10,12,14,16,18
// =SEQUENCE(1,10,0,0.1)        // Generate 0,0.1,0.2,...,0.9 in row
```

### 5. RANDARRAY Function  
```cpp
// Syntax: RANDARRAY([rows], [columns], [min], [max], [whole_number])
// Logic: Generate array of random numbers

class RandArrayFunction {
public:
    EvalResult execute(int rows = 1,
                      int columns = 1, 
                      double minVal = 0.0,
                      double maxVal = 1.0,
                      bool wholeNumber = false) {
        
        if (rows <= 0 || columns <= 0) {
            return CellError{"#VALUE!"};
        }
        
        if (rows > 1048576 || columns > 16384) {
            return CellError{"#NUM!"};
        }
        
        ArrayVal result;
        std::random_device rd;
        std::mt19937 gen(rd());
        
        if (wholeNumber) {
            std::uniform_int_distribution<int> dis((int)minVal, (int)maxVal);
            for (int r = 0; r < rows; r++) {
                std::vector<EvalResult> row;
                for (int c = 0; c < columns; c++) {
                    row.push_back((double)dis(gen));
                }
                result.matrix.push_back(row);
            }
        } else {
            std::uniform_real_distribution<double> dis(minVal, maxVal);
            for (int r = 0; r < rows; r++) {
                std::vector<EvalResult> row;
                for (int c = 0; c < columns; c++) {
                    row.push_back(dis(gen));
                }
                result.matrix.push_back(row);
            }
        }
        
        return result;
    }
};

// Usage Examples:
// =RANDARRAY()                     // Single random number 0-1
// =RANDARRAY(5,3)                  // 5x3 array of random numbers 0-1
// =RANDARRAY(10,1,1,100,TRUE)      // 10 random integers 1-100
// =RANDARRAY(3,3,-1,1,FALSE)       // 3x3 array random decimals -1 to 1
```
## Implementation Logic & Algorithms

### Array Processing Engine Architecture
```cpp
class ArrayProcessingEngine {
private:
    struct ArrayMetadata {
        size_t rows, cols;
        bool isSpillable;
        bool requiresCSE;
        CalculationComplexity complexity;
    };
    
    enum CalculationComplexity {
        SCALAR,      // O(1)
        LINEAR,      // O(n)
        QUADRATIC,   // O(n²)
        MATRIX       // O(n³)
    };
    
public:
    EvalResult processArrayFormula(ASTNode* formulaNode, 
                                  const EvaluationContext& context) {
        // 1. Analyze formula for array requirements
        ArrayMetadata metadata = analyzeArrayRequirements(formulaNode);
        
        // 2. Determine processing strategy
        ProcessingStrategy strategy = selectProcessingStrategy(metadata);
        
        // 3. Execute based on strategy
        switch (strategy) {
            case ELEMENT_WISE:
                return processElementWise(formulaNode, context);
            case BULK_OPERATION:
                return processBulkOperation(formulaNode, context);
            case MATRIX_OPERATION:
                return processMatrixOperation(formulaNode, context);
            case AGGREGATION:
                return processAggregation(formulaNode, context);
        }
        
        return CellError{"#VALUE!"};
    }

private:
    // Element-wise processing: A1:A5 + B1:B5
    EvalResult processElementWise(ASTNode* node, const EvaluationContext& ctx) {
        if (auto binOp = dynamic_cast<BinaryOpNode*>(node)) {
            auto leftResult = evaluate(binOp->left.get(), ctx);
            auto rightResult = evaluate(binOp->right.get(), ctx);
            
            return applyElementWiseOperation(leftResult, rightResult, binOp->op);
        }
        return CellError{"#VALUE!"};
    }
    
    EvalResult applyElementWiseOperation(const EvalResult& left, 
                                       const EvalResult& right, 
                                       TokenType operation) {
        // Handle scalar + array combinations
        if (isScalar(left) && isArray(right)) {
            return applyScalarToArray(left, right, operation);
        }
        if (isArray(left) && isScalar(right)) {
            return applyArrayToScalar(left, right, operation);
        }
        if (isArray(left) && isArray(right)) {
            return applyArrayToArray(left, right, operation);
        }
        
        // Both scalars - normal operation
        return applyScalarOperation(left, right, operation);
    }
    
    EvalResult applyArrayToArray(const EvalResult& left, 
                               const EvalResult& right, 
                               TokenType operation) {
        const auto& leftArray = std::get<ArrayVal>(left);
        const auto& rightArray = std::get<ArrayVal>(right);
        
        // Validate dimensions
        if (leftArray.matrix.size() != rightArray.matrix.size()) {
            return CellError{"#VALUE!"};
        }
        
        ArrayVal result;
        for (size_t row = 0; row < leftArray.matrix.size(); row++) {
            std::vector<EvalResult> resultRow;
            size_t maxCols = std::max(leftArray.matrix[row].size(), 
                                    rightArray.matrix[row].size());
            
            for (size_t col = 0; col < maxCols; col++) {
                EvalResult leftVal = (col < leftArray.matrix[row].size()) ? 
                    leftArray.matrix[row][col] : Blank{};
                EvalResult rightVal = (col < rightArray.matrix[row].size()) ? 
                    rightArray.matrix[row][col] : Blank{};
                
                EvalResult cellResult = applyScalarOperation(leftVal, rightVal, operation);
                resultRow.push_back(cellResult);
            }
            result.matrix.push_back(resultRow);
        }
        
        return result;
    }
};
```

### Memory Management for Large Arrays
```cpp
class ArrayMemoryManager {
private:
    static const size_t MAX_ARRAY_ELEMENTS = 1048576; // 1M elements
    static const size_t LARGE_ARRAY_THRESHOLD = 10000;
    
    struct ArrayBuffer {
        std::unique_ptr<EvalResult[]> data;
        size_t rows, cols;
        bool isTemporary;
    };
    
    std::vector<std::unique_ptr<ArrayBuffer>> temporaryBuffers;
    
public:
    ArrayBuffer* allocateArrayBuffer(size_t rows, size_t cols) {
        size_t totalElements = rows * cols;
        
        if (totalElements > MAX_ARRAY_ELEMENTS) {
            throw std::runtime_error("Array too large");
        }
        
        auto buffer = std::make_unique<ArrayBuffer>();
        buffer->data = std::make_unique<EvalResult[]>(totalElements);
        buffer->rows = rows;
        buffer->cols = cols;
        buffer->isTemporary = true;
        
        ArrayBuffer* ptr = buffer.get();
        temporaryBuffers.push_back(std::move(buffer));
        
        return ptr;
    }
    
    void optimizeMemoryUsage() {
        // Remove unused temporary buffers
        temporaryBuffers.erase(
            std::remove_if(temporaryBuffers.begin(), temporaryBuffers.end(),
                [](const std::unique_ptr<ArrayBuffer>& buffer) {
                    return buffer->isTemporary && !isBufferInUse(buffer.get());
                }),
            temporaryBuffers.end());
    }
    
    // Stream processing for very large arrays
    template<typename Operation>
    EvalResult processLargeArray(const ArrayVal& source, Operation op) {
        if (getTotalElements(source) < LARGE_ARRAY_THRESHOLD) {
            return processNormalArray(source, op);
        }
        
        // Process in chunks to manage memory
        const size_t CHUNK_SIZE = 1000;
        ArrayVal result;
        
        for (size_t startRow = 0; startRow < source.matrix.size(); startRow += CHUNK_SIZE) {
            size_t endRow = std::min(startRow + CHUNK_SIZE, source.matrix.size());
            
            ArrayVal chunk;
            for (size_t i = startRow; i < endRow; i++) {
                chunk.matrix.push_back(source.matrix[i]);
            }
            
            ArrayVal chunkResult = op(chunk);
            for (const auto& row : chunkResult.matrix) {
                result.matrix.push_back(row);
            }
        }
        
        return result;
    }
};
```
## Spill Range Calculation Engine

### Spill Detection & Management
```cpp
class SpillManager {
private:
    struct SpillInfo {
        int originRow, originCol;
        int spillRows, spillCols;
        std::string formulaText;
        std::vector<std::pair<int,int>> spilledCells;
        bool isActive;
    };
    
    std::map<std::pair<int,int>, SpillInfo> activeSpills;
    
public:
    // Check if a cell is part of a spill range
    bool isCellInSpillRange(int row, int col) const {
        for (const auto& [origin, info] : activeSpills) {
            if (!info.isActive) continue;
            
            int originRow = origin.first;
            int originCol = origin.second;
            
            if (row >= originRow && row < originRow + info.spillRows &&
                col >= originCol && col < originCol + info.spillCols) {
                return true;
            }
        }
        return false;
    }
    
    // Get spill origin for a spilled cell
    std::optional<std::pair<int,int>> getSpillOrigin(int row, int col) const {
        for (const auto& [origin, info] : activeSpills) {
            if (!info.isActive) continue;
            
            int originRow = origin.first;
            int originCol = origin.second;
            
            if (row >= originRow && row < originRow + info.spillRows &&
                col >= originCol && col < originCol + info.spillCols) {
                return origin;
            }
        }
        return std::nullopt;
    }
    
    // Register a new spill range
    EvalResult registerSpill(int originRow, int originCol, 
                           const ArrayVal& result,
                           const std::string& formula,
                           SpreadsheetModel& sheet) {
        
        int spillRows = result.matrix.size();
        int spillCols = result.matrix.empty() ? 0 : result.matrix[0].size();
        
        // Check for obstructions
        std::vector<std::pair<int,int>> obstructions;
        for (int r = 0; r < spillRows; r++) {
            for (int c = 0; c < spillCols; c++) {
                if (r == 0 && c == 0) continue; // Skip origin
                
                int cellRow = originRow + r;
                int cellCol = originCol + c;
                
                if (sheet.cellHasContent(cellRow, cellCol)) {
                    obstructions.push_back({cellRow, cellCol});
                }
            }
        }
        
        if (!obstructions.empty()) {
            return CellError{"#SPILL!"};
        }
        
        // Register the spill
        SpillInfo info;
        info.originRow = originRow;
        info.originCol = originCol;
        info.spillRows = spillRows;
        info.spillCols = spillCols;
        info.formulaText = formula;
        info.isActive = true;
        
        for (int r = 0; r < spillRows; r++) {
            for (int c = 0; c < spillCols; c++) {
                info.spilledCells.push_back({originRow + r, originCol + c});
            }
        }
        
        activeSpills[{originRow, originCol}] = info;
        
        return result;
    }
    
    // Clear spill when origin formula changes
    void clearSpill(int originRow, int originCol) {
        auto key = std::make_pair(originRow, originCol);
        if (activeSpills.find(key) != activeSpills.end()) {
            activeSpills[key].isActive = false;
            activeSpills.erase(key);
        }
    }
};
```

### Spill Range Reference (# operator)
```cpp
// Excel's # operator references entire spill range
// Example: =SUM(A1#) where A1 contains spilling formula

class SpillReferenceResolver {
public:
    EvalResult resolveSpillReference(int row, int col, 
                                    const SpillManager& spillMgr,
                                    const SpreadsheetModel& sheet) {
        
        // Check if this cell is a spill origin
        auto spillInfo = spillMgr.getSpillInfo(row, col);
        if (!spillInfo) {
            // Not a spill origin - check if it's in a spill range
            auto origin = spillMgr.getSpillOrigin(row, col);
            if (origin) {
                spillInfo = spillMgr.getSpillInfo(origin->first, origin->second);
            }
        }
        
        if (!spillInfo) {
            return CellError{"#REF!"}; // Cell doesn't have spill data
        }
        
        // Get the entire spill range
        ArrayVal result;
        for (int r = 0; r < spillInfo->spillRows; r++) {
            std::vector<EvalResult> row;
            for (int c = 0; c < spillInfo->spillCols; c++) {
                int cellRow = spillInfo->originRow + r;
                int cellCol = spillInfo->originCol + c;
                row.push_back(sheet.getCellValue(cellRow, cellCol));
            }
            result.matrix.push_back(row);
        }
        
        return result;
    }
};

// Usage Examples:
// A1: =FILTER(D:D, E:E>100)  // Spills to A1:A5
// B1: =SUM(A1#)              // Sums entire spilled range A1:A5
// C1: =AVERAGE(A1#)          // Averages A1:A5
```

### Implicit Intersection (@operator)
```cpp
// @ operator handles implicit intersection in array formulas
class ImplicitIntersectionResolver {
public:
    EvalResult resolveIntersection(const ArrayVal& array,
                                  int targetRow, int targetCol) {
        
        // Try to find matching row
        if (targetRow < array.matrix.size()) {
            const auto& row = array.matrix[targetRow];
            
            // Single column - return the value
            if (row.size() == 1) {
                return row[0];
            }
            
            // Multiple columns - try to match column
            if (targetCol < row.size()) {
                return row[targetCol];
            }
        }
        
        // No intersection found
        return CellError{"#VALUE!"};
    }
};

// Usage: When old formula expects single value but gets array
// =A1:A10  in cell B5 → returns A5 (implicit intersection at row 5)
```
## Advanced Array Operations

### 6. SORTBY Function
```cpp
// Syntax: SORTBY(array, by_array1, [sort_order1], [by_array2], ...)
// Logic: Sort array based on values in other arrays

class SortByFunction {
public:
    EvalResult execute(const ArrayVal& sourceArray,
                      const std::vector<SortCriteria>& criteria) {
        
        if (sourceArray.matrix.empty()) {
            return sourceArray;
        }
        
        // Create indices for sorting
        std::vector<size_t> indices(sourceArray.matrix.size());
        std::iota(indices.begin(), indices.end(), 0);
        
        // Multi-level sort
        std::sort(indices.begin(), indices.end(),
            [&](size_t a, size_t b) {
                for (const auto& crit : criteria) {
                    int comparison = compareRows(
                        crit.byArray.matrix[a],
                        crit.byArray.matrix[b]
                    );
                    
                    if (comparison != 0) {
                        return crit.ascending ? (comparison < 0) : (comparison > 0);
                    }
                }
                return false; // Equal
            });
        
        // Build result using sorted indices
        ArrayVal result;
        for (size_t idx : indices) {
            result.matrix.push_back(sourceArray.matrix[idx]);
        }
        
        return result;
    }

private:
    struct SortCriteria {
        ArrayVal byArray;
        bool ascending;
    };
};

// Usage Examples:
// =SORTBY(A1:C10, D1:D10, 1)       // Sort by column D ascending
// =SORTBY(A1:C10, D1:D10, -1, E1:E10, 1) // Sort by D desc, then E asc
```

### 7. TRANSPOSE Function
```cpp
// Syntax: TRANSPOSE(array)
// Logic: Convert rows to columns and vice versa

class TransposeFunction {
public:
    EvalResult execute(const ArrayVal& sourceArray) {
        if (sourceArray.matrix.empty()) {
            return sourceArray;
        }
        
        // Find maximum column count
        size_t maxCols = 0;
        for (const auto& row : sourceArray.matrix) {
            maxCols = std::max(maxCols, row.size());
        }
        
        // Create transposed matrix
        ArrayVal result;
        for (size_t col = 0; col < maxCols; col++) {
            std::vector<EvalResult> newRow;
            for (size_t row = 0; row < sourceArray.matrix.size(); row++) {
                if (col < sourceArray.matrix[row].size()) {
                    newRow.push_back(sourceArray.matrix[row][col]);
                } else {
                    newRow.push_back(Blank{});
                }
            }
            result.matrix.push_back(newRow);
        }
        
        return result;
    }
};

// Usage Examples:
// =TRANSPOSE(A1:C5)    // Convert 5x3 to 3x5
// =TRANSPOSE(A:A)      // Convert column to row
```

### 8. Array Manipulation Functions

#### HSTACK (Horizontal Stack)
```cpp
// Syntax: HSTACK(array1, [array2], ...)
// Logic: Stack arrays horizontally (side by side)

class HStackFunction {
public:
    EvalResult execute(const std::vector<ArrayVal>& arrays) {
        if (arrays.empty()) {
            return CellError{"#VALUE!"};
        }
        
        // Find maximum row count
        size_t maxRows = 0;
        for (const auto& arr : arrays) {
            maxRows = std::max(maxRows, arr.matrix.size());
        }
        
        ArrayVal result;
        for (size_t row = 0; row < maxRows; row++) {
            std::vector<EvalResult> newRow;
            
            for (const auto& arr : arrays) {
                if (row < arr.matrix.size()) {
                    // Add all columns from this array's row
                    for (const auto& cell : arr.matrix[row]) {
                        newRow.push_back(cell);
                    }
                } else {
                    // Pad with blanks if array doesn't have this row
                    size_t cols = arr.matrix.empty() ? 0 : arr.matrix[0].size();
                    for (size_t c = 0; c < cols; c++) {
                        newRow.push_back(CellError{"#N/A"});
                    }
                }
            }
            
            result.matrix.push_back(newRow);
        }
        
        return result;
    }
};

// Usage: =HSTACK(A1:A10, B1:B10, C1:C10)
```

#### VSTACK (Vertical Stack)
```cpp
// Syntax: VSTACK(array1, [array2], ...)
// Logic: Stack arrays vertically (one below another)

class VStackFunction {
public:
    EvalResult execute(const std::vector<ArrayVal>& arrays) {
        if (arrays.empty()) {
            return CellError{"#VALUE!"};
        }
        
        // Find maximum column count
        size_t maxCols = 0;
        for (const auto& arr : arrays) {
            for (const auto& row : arr.matrix) {
                maxCols = std::max(maxCols, row.size());
            }
        }
        
        ArrayVal result;
        for (const auto& arr : arrays) {
            for (const auto& row : arr.matrix) {
                std::vector<EvalResult> newRow = row;
                
                // Pad row to match max columns
                while (newRow.size() < maxCols) {
                    newRow.push_back(CellError{"#N/A"});
                }
                
                result.matrix.push_back(newRow);
            }
        }
        
        return result;
    }
};

// Usage: =VSTACK(A1:C5, A10:C15, A20:C25)
```

#### WRAPCOLS & WRAPROWS
```cpp
// WRAPCOLS: Wrap array values into columns
class WrapColsFunction {
public:
    EvalResult execute(const ArrayVal& sourceArray, 
                      int numCols,
                      const EvalResult& padWith = CellError{"#N/A"}) {
        
        if (numCols <= 0) {
            return CellError{"#VALUE!"};
        }
        
        // Flatten array to 1D
        std::vector<EvalResult> flatValues;
        for (const auto& row : sourceArray.matrix) {
            for (const auto& cell : row) {
                flatValues.push_back(cell);
            }
        }
        
        // Calculate rows needed
        int numRows = (flatValues.size() + numCols - 1) / numCols;
        
        // Build result matrix
        ArrayVal result;
        for (int r = 0; r < numRows; r++) {
            std::vector<EvalResult> newRow;
            for (int c = 0; c < numCols; c++) {
                int idx = r * numCols + c;
                if (idx < flatValues.size()) {
                    newRow.push_back(flatValues[idx]);
                } else {
                    newRow.push_back(padWith);
                }
            }
            result.matrix.push_back(newRow);
        }
        
        return result;
    }
};

// Usage: =WRAPCOLS(A1:A20, 4)  // Wrap 20 values into 4 columns (5 rows)
```

### 9. TOCOL & TOROW Functions
```cpp
// Convert array to single column
class ToColFunction {
public:
    EvalResult execute(const ArrayVal& sourceArray,
                      int ignore = 0,  // 0=keep all, 1=ignore blanks, 2=ignore errors, 3=both
                      bool scanByCol = false) {
        
        std::vector<EvalResult> values;
        
        if (scanByCol) {
            // Scan column by column
            size_t maxCols = 0;
            for (const auto& row : sourceArray.matrix) {
                maxCols = std::max(maxCols, row.size());
            }
            
            for (size_t col = 0; col < maxCols; col++) {
                for (size_t row = 0; row < sourceArray.matrix.size(); row++) {
                    if (col < sourceArray.matrix[row].size()) {
                        EvalResult val = sourceArray.matrix[row][col];
                        if (shouldInclude(val, ignore)) {
                            values.push_back(val);
                        }
                    }
                }
            }
        } else {
            // Scan row by row
            for (const auto& row : sourceArray.matrix) {
                for (const auto& cell : row) {
                    if (shouldInclude(cell, ignore)) {
                        values.push_back(cell);
                    }
                }
            }
        }
        
        // Convert to column
        ArrayVal result;
        for (const auto& val : values) {
            result.matrix.push_back({val});
        }
        
        return result;
    }

private:
    bool shouldInclude(const EvalResult& val, int ignore) {
        bool isBlank = std::holds_alternative<Blank>(val) || 
                      (std::holds_alternative<std::string>(val) && 
                       std::get<std::string>(val).empty());
        bool isError = std::holds_alternative<CellError>(val);
        
        if (ignore == 1 && isBlank) return false;
        if (ignore == 2 && isError) return false;
        if (ignore == 3 && (isBlank || isError)) return false;
        
        return true;
    }
};

// Usage: 
// =TOCOL(A1:C10)           // Convert to single column
// =TOCOL(A1:C10, 1)        // Ignore blanks
// =TOROW(A1:C10)           // Convert to single row
```
## Error Handling & Edge Cases

### Common Array Formula Errors
```cpp
enum class ArrayError {
    SPILL_ERROR,        // #SPILL!  - Cannot spill into occupied cells
    VALUE_ERROR,        // #VALUE! - Incompatible array dimensions
    REF_ERROR,          // #REF!   - Invalid array reference
    CALC_ERROR,         // #CALC!  - Calculation overflow/underflow
    NUM_ERROR,          // #NUM!   - Array too large
    NA_ERROR            // #N/A    - No results from filter
};

class ArrayErrorHandler {
public:
    static EvalResult handleSpillError(const std::vector<std::pair<int,int>>& obstructions) {
        // Provide detailed error information
        std::string errorMsg = "#SPILL! Blocked by cell";
        if (!obstructions.empty()) {
            errorMsg += " " + cellAddressToString(obstructions[0].first, 
                                                 obstructions[0].second);
        }
        return CellError{errorMsg};
    }
    
    static EvalResult handleDimensionMismatch(size_t leftRows, size_t leftCols,
                                             size_t rightRows, size_t rightCols) {
        if (leftRows != rightRows && leftRows != 1 && rightRows != 1) {
            return CellError{"#VALUE! Row count mismatch"};
        }
        if (leftCols != rightCols && leftCols != 1 && rightCols != 1) {
            return CellError{"#VALUE! Column count mismatch"};
        }
        return CellError{"#VALUE!"};
    }
    
    static bool validateArraySize(size_t rows, size_t cols) {
        const size_t MAX_ROWS = 1048576;
        const size_t MAX_COLS = 16384;
        const size_t MAX_ELEMENTS = 10000000; // 10M elements
        
        if (rows > MAX_ROWS || cols > MAX_COLS) {
            return false;
        }
        if (rows * cols > MAX_ELEMENTS) {
            return false;
        }
        return true;
    }
};
```

### Array Broadcasting Rules
```cpp
// Excel's implicit broadcasting rules for array operations
class ArrayBroadcaster {
public:
    // Determine if arrays can be broadcasted together
    static bool canBroadcast(const ArrayVal& left, const ArrayVal& right) {
        size_t leftRows = left.matrix.size();
        size_t rightRows = right.matrix.size();
        size_t leftCols = left.matrix.empty() ? 0 : left.matrix[0].size();
        size_t rightCols = right.matrix.empty() ? 0 : right.matrix[0].size();
        
        // Same dimensions - OK
        if (leftRows == rightRows && leftCols == rightCols) {
            return true;
        }
        
        // One dimension is 1 (scalar expansion) - OK
        if (leftRows == 1 || rightRows == 1) {
            if (leftCols == rightCols || leftCols == 1 || rightCols == 1) {
                return true;
            }
        }
        
        return false;
    }
    
    // Broadcast arrays to compatible dimensions
    static std::pair<ArrayVal, ArrayVal> broadcast(const ArrayVal& left, 
                                                   const ArrayVal& right) {
        size_t leftRows = left.matrix.size();
        size_t rightRows = right.matrix.size();
        size_t leftCols = left.matrix.empty() ? 0 : left.matrix[0].size();
        size_t rightCols = right.matrix.empty() ? 0 : right.matrix[0].size();
        
        size_t targetRows = std::max(leftRows, rightRows);
        size_t targetCols = std::max(leftCols, rightCols);
        
        ArrayVal broadLeft = expandArray(left, targetRows, targetCols);
        ArrayVal broadRight = expandArray(right, targetRows, targetCols);
        
        return {broadLeft, broadRight};
    }

private:
    static ArrayVal expandArray(const ArrayVal& source, size_t targetRows, size_t targetCols) {
        if (source.matrix.empty()) {
            return source;
        }
        
        ArrayVal result;
        for (size_t r = 0; r < targetRows; r++) {
            std::vector<EvalResult> row;
            size_t srcRow = (r < source.matrix.size()) ? r : source.matrix.size() - 1;
            
            for (size_t c = 0; c < targetCols; c++) {
                size_t srcCol = (c < source.matrix[srcRow].size()) ? 
                               c : source.matrix[srcRow].size() - 1;
                row.push_back(source.matrix[srcRow][srcCol]);
            }
            result.matrix.push_back(row);
        }
        
        return result;
    }
};

// Broadcasting Examples:
// {1,2,3} + {10}       → {11,12,13}  (scalar expansion)
// [[1],[2],[3]] + [10,20,30] → [[11,21,31],[12,22,32],[13,23,33]] (both expand)
```

### Circular Reference Detection in Arrays
```cpp
class ArrayCircularReferenceDetector {
private:
    std::set<std::pair<int,int>> visitedCells;
    std::set<std::pair<int,int>> currentPath;
    
public:
    bool detectCircular(int row, int col, 
                       const SpreadsheetModel& sheet,
                       std::vector<std::pair<int,int>>& cyclePath) {
        
        auto cellPos = std::make_pair(row, col);
        
        // Already visited in this path - circular reference found
        if (currentPath.find(cellPos) != currentPath.end()) {
            cyclePath.push_back(cellPos);
            return true;
        }
        
        // Already checked this cell in another path - no circular ref
        if (visitedCells.find(cellPos) != visitedCells.end()) {
            return false;
        }
        
        currentPath.insert(cellPos);
        visitedCells.insert(cellPos);
        
        // Get cell formula
        std::string formula = sheet.getCellFormula(row, col);
        if (formula.empty()) {
            currentPath.erase(cellPos);
            return false;
        }
        
        // Parse formula to find all cell references
        std::vector<std::pair<int,int>> references = extractCellReferences(formula);
        
        // Check each reference
        for (const auto& ref : references) {
            if (detectCircular(ref.first, ref.second, sheet, cyclePath)) {
                cyclePath.push_back(cellPos);
                return true;
            }
        }
        
        currentPath.erase(cellPos);
        return false;
    }
    
    // Special handling for array formulas with spill ranges
    bool detectCircularInSpill(const SpillInfo& spill,
                               const SpreadsheetModel& sheet) {
        
        std::vector<std::pair<int,int>> cyclePath;
        
        // Check if any spilled cell references back to origin
        for (int r = 0; r < spill.spillRows; r++) {
            for (int c = 0; c < spill.spillCols; c++) {
                int cellRow = spill.originRow + r;
                int cellCol = spill.originCol + c;
                
                if (r == 0 && c == 0) continue; // Skip origin
                
                if (detectCircular(cellRow, cellCol, sheet, cyclePath)) {
                    return true;
                }
            }
        }
        
        return false;
    }
};
```
## Memory Management & Performance

### Performance Optimization Strategies
```cpp
class ArrayPerformanceOptimizer {
private:
    struct PerformanceMetrics {
        size_t arrayOperations;
        size_t totalElements;
        double executionTimeMs;
        size_t memoryUsedBytes;
    };
    
public:
    // Lazy evaluation for large arrays
    template<typename Operation>
    EvalResult lazyEvaluate(const ArrayVal& source, Operation op) {
        // For small arrays, evaluate immediately
        if (getTotalElements(source) < 1000) {
            return op(source);
        }
        
        // For large arrays, use iterator pattern
        return createLazyArray(source, op);
    }
    
    // Vectorized operations using SIMD
    EvalResult vectorizedMultiply(const ArrayVal& left, const ArrayVal& right) {
        #ifdef USE_SIMD
        if (canUseSIMD(left, right)) {
            return simdMultiply(left, right);
        }
        #endif
        
        return standardMultiply(left, right);
    }
    
    // Parallel processing for large arrays
    EvalResult parallelProcess(const ArrayVal& source, 
                              std::function<EvalResult(const EvalResult&)> op) {
        
        const size_t PARALLEL_THRESHOLD = 10000;
        if (getTotalElements(source) < PARALLEL_THRESHOLD) {
            return sequentialProcess(source, op);
        }
        
        #ifdef USE_THREADS
        return parallelProcessThreads(source, op);
        #else
        return sequentialProcess(source, op);
        #endif
    }

private:
    #ifdef USE_THREADS
    EvalResult parallelProcessThreads(const ArrayVal& source,
                                     std::function<EvalResult(const EvalResult&)> op) {
        
        const size_t NUM_THREADS = std::thread::hardware_concurrency();
        const size_t CHUNK_SIZE = source.matrix.size() / NUM_THREADS;
        
        std::vector<std::future<ArrayVal>> futures;
        
        for (size_t i = 0; i < NUM_THREADS; i++) {
            size_t start = i * CHUNK_SIZE;
            size_t end = (i == NUM_THREADS - 1) ? 
                        source.matrix.size() : (i + 1) * CHUNK_SIZE;
            
            futures.push_back(std::async(std::launch::async, 
                [&source, op, start, end]() {
                    ArrayVal chunk;
                    for (size_t r = start; r < end; r++) {
                        std::vector<EvalResult> newRow;
                        for (const auto& cell : source.matrix[r]) {
                            newRow.push_back(op(cell));
                        }
                        chunk.matrix.push_back(newRow);
                    }
                    return chunk;
                }));
        }
        
        // Combine results
        ArrayVal result;
        for (auto& fut : futures) {
            ArrayVal chunk = fut.get();
            for (const auto& row : chunk.matrix) {
                result.matrix.push_back(row);
            }
        }
        
        return result;
    }
    #endif
};
```

### Caching Strategy for Array Formulas
```cpp
class ArrayFormulaCache {
private:
    struct CacheEntry {
        std::string formula;
        std::vector<std::pair<int,int>> dependencies;
        EvalResult result;
        std::chrono::time_point<std::chrono::steady_clock> timestamp;
        bool isDirty;
    };
    
    std::map<std::pair<int,int>, CacheEntry> cache;
    const size_t MAX_CACHE_SIZE = 1000;
    
public:
    std::optional<EvalResult> getCached(int row, int col, 
                                       const std::string& formula) {
        auto key = std::make_pair(row, col);
        auto it = cache.find(key);
        
        if (it == cache.end()) {
            return std::nullopt;
        }
        
        if (it->second.isDirty) {
            return std::nullopt;
        }
        
        if (it->second.formula != formula) {
            return std::nullopt;
        }
        
        return it->second.result;
    }
    
    void setCached(int row, int col,
                  const std::string& formula,
                  const EvalResult& result,
                  const std::vector<std::pair<int,int>>& deps) {
        
        // Evict old entries if cache is full
        if (cache.size() >= MAX_CACHE_SIZE) {
            evictOldest();
        }
        
        CacheEntry entry;
        entry.formula = formula;
        entry.result = result;
        entry.dependencies = deps;
        entry.timestamp = std::chrono::steady_clock::now();
        entry.isDirty = false;
        
        cache[{row, col}] = entry;
    }
    
    void invalidateDependents(int changedRow, int changedCol) {
        for (auto& [pos, entry] : cache) {
            for (const auto& dep : entry.dependencies) {
                if (dep.first == changedRow && dep.second == changedCol) {
                    entry.isDirty = true;
                    break;
                }
            }
        }
    }

private:
    void evictOldest() {
        if (cache.empty()) return;
        
        auto oldest = cache.begin();
        for (auto it = cache.begin(); it != cache.end(); ++it) {
            if (it->second.timestamp < oldest->second.timestamp) {
                oldest = it;
            }
        }
        
        cache.erase(oldest);
    }
};
```

### Memory Pool for Array Allocations
```cpp
class ArrayMemoryPool {
private:
    struct MemoryBlock {
        void* data;
        size_t size;
        bool inUse;
    };
    
    std::vector<MemoryBlock> blocks;
    const size_t BLOCK_SIZE = 1024 * 1024; // 1MB blocks
    
public:
    void* allocate(size_t size) {
        // Try to find free block of sufficient size
        for (auto& block : blocks) {
            if (!block.inUse && block.size >= size) {
                block.inUse = true;
                return block.data;
            }
        }
        
        // Allocate new block
        size_t allocSize = std::max(size, BLOCK_SIZE);
        void* ptr = std::malloc(allocSize);
        
        if (!ptr) {
            throw std::bad_alloc();
        }
        
        blocks.push_back({ptr, allocSize, true});
        return ptr;
    }
    
    void deallocate(void* ptr) {
        for (auto& block : blocks) {
            if (block.data == ptr) {
                block.inUse = false;
                return;
            }
        }
    }
    
    void cleanup() {
        for (auto& block : blocks) {
            if (!block.inUse) {
                std::free(block.data);
            }
        }
        blocks.erase(
            std::remove_if(blocks.begin(), blocks.end(),
                [](const MemoryBlock& b) { return !b.inUse; }),
            blocks.end());
    }
    
    ~ArrayMemoryPool() {
        for (auto& block : blocks) {
            std::free(block.data);
        }
    }
};
```
## C++ Implementation Strategy

### Integration with Your Current Codebase
```cpp
// File: array_functions.cpp

#include "../function_registry.h"
#include "../evaluator.h"
#include <algorithm>
#include <random>

void FunctionRegistry::registerArrayFunctions() {
    
    // FILTER(array, include, [if_empty])
    registerFunction("FILTER", [](Evaluator& eval, 
                                  const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto includeVal = EVAL_ARG(eval, args, 1);
        
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(includeVal)) return includeVal;
        
        if (!std::holds_alternative<ArrayVal>(arrayVal)) {
            return CellError{"#VALUE!"};
        }
        
        const auto& sourceMatrix = std::get<ArrayVal>(arrayVal).matrix;
        ArrayVal result;
        bool hasResults = false;
        
        // Get include array
        std::vector<bool> includeFlags;
        if (std::holds_alternative<ArrayVal>(includeVal)) {
            const auto& includeMatrix = std::get<ArrayVal>(includeVal).matrix;
            for (const auto& row : includeMatrix) {
                if (!row.empty()) {
                    includeFlags.push_back(Evaluator::asBool(row[0]));
                }
            }
        } else {
            includeFlags.push_back(Evaluator::asBool(includeVal));
        }
        
        // Filter rows
        for (size_t i = 0; i < sourceMatrix.size() && i < includeFlags.size(); i++) {
            if (includeFlags[i]) {
                result.matrix.push_back(sourceMatrix[i]);
                hasResults = true;
            }
        }
        
        if (!hasResults) {
            if (args.size() == 3) {
                auto ifEmpty = EVAL_ARG(eval, args, 2);
                return ifEmpty;
            }
            return CellError{"#CALC!"};
        }
        
        return result;
    });
    
    // SORT(array, [sort_index], [sort_order], [by_col])
    registerFunction("SORT", [](Evaluator& eval,
                                const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 4) return CellError{"#VALUE!"};
        
        auto arrayVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (!std::holds_alternative<ArrayVal>(arrayVal)) return CellError{"#VALUE!"};
        
        int sortIndex = 1;
        int sortOrder = 1; // 1=asc, -1=desc
        bool byColumn = false;
        
        if (args.size() >= 2) {
            auto idxVal = EVAL_ARG(eval, args, 1);
            if (!Evaluator::isError(idxVal)) {
                sortIndex = (int)Evaluator::asNumber(idxVal);
            }
        }
        if (args.size() >= 3) {
            auto orderVal = EVAL_ARG(eval, args, 2);
            if (!Evaluator::isError(orderVal)) {
                sortOrder = (int)Evaluator::asNumber(orderVal);
            }
        }
        if (args.size() == 4) {
            auto byColVal = EVAL_ARG(eval, args, 3);
            if (!Evaluator::isError(byColVal)) {
                byColumn = Evaluator::asBool(byColVal);
            }
        }
        
        ArrayVal result = std::get<ArrayVal>(arrayVal);
        int colIdx = std::abs(sortIndex) - 1;
        
        std::sort(result.matrix.begin(), result.matrix.end(),
            [colIdx, sortOrder](const std::vector<EvalResult>& a, 
                              const std::vector<EvalResult>& b) {
                if (colIdx >= a.size() || colIdx >= b.size()) return false;
                
                double aNum = 0, bNum = 0;
                try { aNum = Evaluator::asNumber(a[colIdx]); } catch(...) {}
                try { bNum = Evaluator::asNumber(b[colIdx]); } catch(...) {}
                
                return (sortOrder > 0) ? (aNum < bNum) : (aNum > bNum);
            });
        
        return result;
    });
    
    // UNIQUE(array, [by_col], [exactly_once])
    registerFunction("UNIQUE", [](Evaluator& eval,
                                  const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 3) return CellError{"#VALUE!"};
        
        auto arrayVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (!std::holds_alternative<ArrayVal>(arrayVal)) return CellError{"#VALUE!"};
        
        bool byColumn = false;
        bool exactlyOnce = false;
        
        if (args.size() >= 2) {
            auto byColVal = EVAL_ARG(eval, args, 1);
            if (!Evaluator::isError(byColVal)) {
                byColumn = Evaluator::asBool(byColVal);
            }
        }
        if (args.size() == 3) {
            auto onceVal = EVAL_ARG(eval, args, 2);
            if (!Evaluator::isError(onceVal)) {
                exactlyOnce = Evaluator::asBool(onceVal);
            }
        }
        
        const auto& sourceMatrix = std::get<ArrayVal>(arrayVal).matrix;
        ArrayVal result;
        std::map<std::string, int> rowCounts;
        
        // First pass: count occurrences
        for (const auto& row : sourceMatrix) {
            std::string rowKey;
            for (const auto& cell : row) {
                rowKey += Evaluator::asString(cell) + "|";
            }
            rowCounts[rowKey]++;
        }
        
        // Second pass: collect unique rows
        std::set<std::string> added;
        for (const auto& row : sourceMatrix) {
            std::string rowKey;
            for (const auto& cell : row) {
                rowKey += Evaluator::asString(cell) + "|";
            }
            
            bool shouldAdd = false;
            if (exactlyOnce) {
                shouldAdd = (rowCounts[rowKey] == 1);
            } else {
                shouldAdd = (added.find(rowKey) == added.end());
            }
            
            if (shouldAdd) {
                result.matrix.push_back(row);
                added.insert(rowKey);
            }
        }
        
        if (result.matrix.empty()) {
            return CellError{"#CALC!"};
        }
        
        return result;
    });
    
    // SEQUENCE(rows, [columns], [start], [step])
    registerFunction("SEQUENCE", [](Evaluator& eval,
                                   const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 4) return CellError{"#VALUE!"};
        
        auto rowsVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(rowsVal)) return rowsVal;
        
        int rows = (int)Evaluator::asNumber(rowsVal);
        int cols = 1;
        double start = 1.0;
        double step = 1.0;
        
        if (args.size() >= 2) {
            auto colsVal = EVAL_ARG(eval, args, 1);
            if (!Evaluator::isError(colsVal)) {
                cols = (int)Evaluator::asNumber(colsVal);
            }
        }
        if (args.size() >= 3) {
            auto startVal = EVAL_ARG(eval, args, 2);
            if (!Evaluator::isError(startVal)) {
                start = Evaluator::asNumber(startVal);
            }
        }
        if (args.size() == 4) {
            auto stepVal = EVAL_ARG(eval, args, 3);
            if (!Evaluator::isError(stepVal)) {
                step = Evaluator::asNumber(stepVal);
            }
        }
        
        if (rows <= 0 || cols <= 0) return CellError{"#VALUE!"};
        if (rows > 10000 || cols > 1000) return CellError{"#NUM!"}; // Limit size
        
        ArrayVal result;
        double current = start;
        
        for (int r = 0; r < rows; r++) {
            std::vector<EvalResult> row;
            for (int c = 0; c < cols; c++) {
                row.push_back(current);
                current += step;
            }
            result.matrix.push_back(row);
        }
        
        return result;
    });
}
```
## Testing & Validation Framework

### Comprehensive Test Cases
```cpp
// File: array_functions_test.cpp

#include <gtest/gtest.h>
#include "evaluator.h"
#include "function_registry.h"

class ArrayFunctionTest : public ::testing::Test {
protected:
    Evaluator eval;
    
    void SetUp() override {
        // Setup test data
    }
};

// FILTER Function Tests
TEST_F(ArrayFunctionTest, FilterBasic) {
    // Test: =FILTER(A1:A5, B1:B5>10)
    ArrayVal source;
    source.matrix = {{5.0}, {15.0}, {8.0}, {20.0}, {3.0}};
    
    ArrayVal criteria;
    criteria.matrix = {{false}, {true}, {false}, {true}, {false}};
    
    // Expected: {15, 20}
    auto result = filterFunction(source, criteria);
    
    ASSERT_TRUE(std::holds_alternative<ArrayVal>(result));
    const auto& resultArray = std::get<ArrayVal>(result);
    ASSERT_EQ(resultArray.matrix.size(), 2);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[0][0]), 15.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[1][0]), 20.0);
}

TEST_F(ArrayFunctionTest, FilterNoResults) {
    // Test: =FILTER(A1:A5, B1:B5>100, "No Data")
    ArrayVal source;
    source.matrix = {{5.0}, {15.0}, {8.0}};
    
    ArrayVal criteria;
    criteria.matrix = {{false}, {false}, {false}};
    
    EvalResult ifEmpty = std::string("No Data");
    
    auto result = filterFunction(source, criteria, ifEmpty);
    ASSERT_TRUE(std::holds_alternative<std::string>(result));
    EXPECT_EQ(std::get<std::string>(result), "No Data");
}

// SORT Function Tests
TEST_F(ArrayFunctionTest, SortAscending) {
    ArrayVal source;
    source.matrix = {{3.0, "C"}, {1.0, "A"}, {2.0, "B"}};
    
    auto result = sortFunction(source, 1, 1); // Sort by col 1, ascending
    
    ASSERT_TRUE(std::holds_alternative<ArrayVal>(result));
    const auto& resultArray = std::get<ArrayVal>(result);
    ASSERT_EQ(resultArray.matrix.size(), 3);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[0][0]), 1.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[1][0]), 2.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[2][0]), 3.0);
}

TEST_F(ArrayFunctionTest, SortDescending) {
    ArrayVal source;
    source.matrix = {{1.0}, {3.0}, {2.0}};
    
    auto result = sortFunction(source, 1, -1); // Sort descending
    
    const auto& resultArray = std::get<ArrayVal>(result);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[0][0]), 3.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[1][0]), 2.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[2][0]), 1.0);
}

// UNIQUE Function Tests
TEST_F(ArrayFunctionTest, UniqueBasic) {
    ArrayVal source;
    source.matrix = {{"A"}, {"B"}, {"A"}, {"C"}, {"B"}};
    
    auto result = uniqueFunction(source);
    
    const auto& resultArray = std::get<ArrayVal>(result);
    ASSERT_EQ(resultArray.matrix.size(), 3);
    EXPECT_EQ(std::get<std::string>(resultArray.matrix[0][0]), "A");
    EXPECT_EQ(std::get<std::string>(resultArray.matrix[1][0]), "B");
    EXPECT_EQ(std::get<std::string>(resultArray.matrix[2][0]), "C");
}

TEST_F(ArrayFunctionTest, UniqueExactlyOnce) {
    ArrayVal source;
    source.matrix = {{"A"}, {"B"}, {"A"}, {"C"}};
    
    auto result = uniqueFunction(source, false, true); // exactly_once=true
    
    const auto& resultArray = std::get<ArrayVal>(result);
    ASSERT_EQ(resultArray.matrix.size(), 2); // Only B and C appear once
}

// SEQUENCE Function Tests
TEST_F(ArrayFunctionTest, SequenceBasic) {
    auto result = sequenceFunction(5); // Generate 1,2,3,4,5
    
    const auto& resultArray = std::get<ArrayVal>(result);
    ASSERT_EQ(resultArray.matrix.size(), 5);
    for (int i = 0; i < 5; i++) {
        EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[i][0]), i + 1.0);
    }
}

TEST_F(ArrayFunctionTest, SequenceWithStep) {
    auto result = sequenceFunction(5, 1, 10.0, 5.0); // 10,15,20,25,30
    
    const auto& resultArray = std::get<ArrayVal>(result);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[0][0]), 10.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[4][0]), 30.0);
}

TEST_F(ArrayFunctionTest, Sequence2D) {
    auto result = sequenceFunction(3, 4); // 3x4 matrix
    
    const auto& resultArray = std::get<ArrayVal>(result);
    ASSERT_EQ(resultArray.matrix.size(), 3);
    ASSERT_EQ(resultArray.matrix[0].size(), 4);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[2][3]), 12.0);
}

// Spill Range Tests
TEST_F(ArrayFunctionTest, SpillRangeDetection) {
    SpillManager spillMgr;
    ArrayVal result;
    result.matrix = {{1.0}, {2.0}, {3.0}};
    
    // Mock spreadsheet with no obstructions
    MockSpreadsheet sheet;
    
    auto spillResult = spillMgr.registerSpill(0, 0, result, "=SEQUENCE(3)", sheet);
    
    ASSERT_FALSE(std::holds_alternative<CellError>(spillResult));
    EXPECT_TRUE(spillMgr.isCellInSpillRange(1, 0));
    EXPECT_TRUE(spillMgr.isCellInSpillRange(2, 0));
    EXPECT_FALSE(spillMgr.isCellInSpillRange(3, 0));
}

TEST_F(ArrayFunctionTest, SpillErrorOnObstruction) {
    SpillManager spillMgr;
    ArrayVal result;
    result.matrix = {{1.0}, {2.0}, {3.0}};
    
    // Mock spreadsheet with obstruction at (1,0)
    MockSpreadsheet sheet;
    sheet.setCellContent(1, 0, "X");
    
    auto spillResult = spillMgr.registerSpill(0, 0, result, "=SEQUENCE(3)", sheet);
    
    ASSERT_TRUE(std::holds_alternative<CellError>(spillResult));
    EXPECT_EQ(std::get<CellError>(spillResult).type, "#SPILL!");
}

// Array Broadcasting Tests
TEST_F(ArrayFunctionTest, BroadcastScalarToArray) {
    ArrayVal array;
    array.matrix = {{1.0}, {2.0}, {3.0}};
    
    EvalResult scalar = 10.0;
    
    auto result = addArrays(array, scalar);
    
    const auto& resultArray = std::get<ArrayVal>(result);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[0][0]), 11.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[1][0]), 12.0);
    EXPECT_DOUBLE_EQ(std::get<double>(resultArray.matrix[2][0]), 13.0);
}

TEST_F(ArrayFunctionTest, BroadcastDimensionMismatch) {
    ArrayVal left;
    left.matrix = {{1.0}, {2.0}, {3.0}};
    
    ArrayVal right;
    right.matrix = {{10.0}, {20.0}}; // Different size
    
    auto result = addArrays(left, right);
    
    ASSERT_TRUE(std::holds_alternative<CellError>(result));
}

// Performance Tests
TEST_F(ArrayFunctionTest, LargeArrayPerformance) {
    // Generate 10,000 row array
    ArrayVal large;
    for (int i = 0; i < 10000; i++) {
        large.matrix.push_back({static_cast<double>(i)});
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    auto result = filterFunction(large, generateCriteria(large));
    auto end = std::chrono::high_resolution_clock::now();
    
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    EXPECT_LT(duration.count(), 1000); // Should complete in < 1 second
}
```
## Summary & Implementation Checklist

### Key Takeaways

1. **Two Array Formula Types**
   - Legacy CSE (Ctrl+Shift+Enter) - Fixed range, backward compatible
   - Dynamic Arrays (Spill) - Auto-resize, modern Excel 365+

2. **Core Array Functions Priority**
   ```
   HIGH PRIORITY:
   ✓ FILTER    - Most used, essential for data filtering
   ✓ SORT      - Common sorting needs
   ✓ UNIQUE    - Duplicate removal
   ✓ SEQUENCE  - Number generation
   
   MEDIUM PRIORITY:
   ○ SORTBY    - Advanced sorting
   ○ RANDARRAY - Random number generation
   ○ TRANSPOSE - Matrix transformation
   
   LOW PRIORITY:
   ○ HSTACK/VSTACK  - Array combination
   ○ WRAPCOLS/WRAPROWS - Array reshaping
   ○ TOCOL/TOROW - Array flattening
   ```

3. **Critical Implementation Components**
   - Spill range detection and management
   - Array broadcasting rules (scalar expansion)
   - Memory management for large arrays
   - Circular reference detection in arrays
   - Performance optimization (caching, lazy evaluation)

### Implementation Roadmap

#### Phase 1: Foundation (Week 1-2)
```cpp
□ Extend ArrayVal structure to support metadata
□ Implement SpillManager class
□ Add spill range detection algorithm
□ Implement array broadcasting logic
□ Add # operator support for spill references
```

#### Phase 2: Core Functions (Week 3-4)
```cpp
□ Implement FILTER function
□ Implement SORT function
□ Implement UNIQUE function
□ Implement SEQUENCE function
□ Add comprehensive error handling
```

#### Phase 3: Advanced Functions (Week 5-6)
```cpp
□ Implement SORTBY function
□ Implement TRANSPOSE function
□ Implement RANDARRAY function
□ Implement HSTACK/VSTACK functions
□ Implement TOCOL/TOROW functions
```

#### Phase 4: Performance & Testing (Week 7-8)
```cpp
□ Implement array formula caching
□ Add parallel processing for large arrays
□ Memory pool optimization
□ Write comprehensive test suite
□ Performance benchmarking
```

### Integration with Your Existing Code

#### 1. Update evaluator.h
```cpp
struct SpillMetadata {
    bool isSpilling;
    int spillRows, spillCols;
    std::pair<int,int> originCell;
};

// Add to ArrayVal
struct ArrayVal { 
    std::vector<std::vector<EvalResult>> matrix;
    std::optional<SpillMetadata> spillInfo; // NEW
};
```

#### 2. Update function_registry.h
```cpp
void registerArrayFunctions();      // NEW
void registerReferenceFunctions();  // EXISTING - extend for # operator
```

#### 3. Create new file: array_functions.cpp
```cpp
#include "../function_registry.h"
// Implement all array functions here
```

#### 4. Update evaluator.cpp
```cpp
void Evaluator::visit(FunctionNode& node) {
    // Add spill range handling
    auto result = callFunction(node.name, node.args);
    
    if (std::holds_alternative<ArrayVal>(result)) {
        // Check if result should spill
        auto& array = std::get<ArrayVal>(result);
        if (shouldSpill(array)) {
            array.spillInfo = SpillMetadata{
                true, 
                array.matrix.size(),
                array.matrix.empty() ? 0 : array.matrix[0].size(),
                {currentRow, currentCol}
            };
        }
    }
    
    return result;
}
```

### Mobile-Specific Optimizations

1. **Memory Constraints**
   ```cpp
   // Limit array sizes for mobile
   const size_t MOBILE_MAX_ARRAY_ELEMENTS = 100000; // 100K instead of 1M
   const size_t MOBILE_CHUNK_SIZE = 500;            // Smaller chunks
   ```

2. **UI Considerations**
   ```cpp
   // Virtual scrolling for large spill ranges
   // Progressive rendering for arrays > 1000 elements
   // Show "Calculating..." indicator for large arrays
   ```

3. **Battery Optimization**
   ```cpp
   // Suspend array recalculation when app in background
   // Batch array updates to reduce CPU usage
   ```

### Common Pitfalls to Avoid

1. **Memory Leaks**
   - Always use smart pointers for ArrayVal
   - Clear temporary arrays after operations
   - Implement proper destructor for SpillManager

2. **Performance Issues**
   - Don't recalculate unchanged arrays
   - Use caching for frequently accessed arrays
   - Limit recursion depth in circular reference detection

3. **Spill Conflicts**
   - Always check for obstructions before spilling
   - Handle #SPILL! errors gracefully
   - Clear old spills when formulas change

4. **Broadcasting Errors**
   - Validate array dimensions before operations
   - Handle scalar + array combinations properly
   - Return clear error messages for dimension mismatches

### Testing Strategy

```cpp
// Unit Tests
- Test each array function individually
- Test with empty arrays, single values, large arrays
- Test error conditions

// Integration Tests  
- Test array formula chains (FILTER → SORT → UNIQUE)
- Test spill range conflicts
- Test with actual spreadsheet model

// Performance Tests
- Benchmark 1K, 10K, 100K element arrays
- Memory usage profiling
- Identify bottlenecks

// Edge Cases
- Circular references in arrays
- Very large dimension mismatches
- Arrays with mixed data types
- Nested array functions
```

### Resources & References

**Documentation:**
- Microsoft Excel Dynamic Arrays Documentation
- MDN Array Methods (for algorithm patterns)
- C++ STL Algorithms Reference

**Performance:**
- SIMD optimization techniques
- Memory pool design patterns
- Lazy evaluation strategies

**Testing:**
- Google Test framework
- Memory profilers (Valgrind, AddressSanitizer)
- Performance benchmarking tools

---

## Conclusion

Array formulas represent a significant advancement in spreadsheet calculation capabilities. The key to successful implementation is:

1. **Start Simple** - Implement FILTER, SORT, UNIQUE first
2. **Test Thoroughly** - Edge cases are critical for arrays
3. **Optimize Incrementally** - Profile before optimizing
4. **Handle Errors Gracefully** - Clear error messages for users

Your current C++ implementation is well-structured to support array functions. The main additions needed are:
- Spill range management
- Array broadcasting logic
- 4-5 core array functions
- Performance optimizations for mobile



**Priority Order:** FILTER → SORT → UNIQUE → SEQUENCE → Advanced functions

Good luck with the implementation! 🚀