# Formula Parser Fix Implementation Guide

## 🎯 Quick Start - Critical Fixes

Yeh document step-by-step implementation guide hai sabse critical bugs ko fix karne ke liye.

---

## 🔴 FIX #1: Operator Precedence (BLOCKING BUG)

**File:** `android/app/src/main/cpp/parser.cpp`

**Problem:** Precedence order galat hai, formulas wrong results de rahe hain

**Current Bug:**
```cpp
// Line 167-184
int Parser::getPrecedence(TokenType type) const {
    switch (type) {
        case TokenType::COLON: return 7;      // ❌ WRONG
        case TokenType::CONCAT: return 2;     // ❌ WRONG
        case TokenType::POWER: return 5;      // ❌ WRONG
        // ...
    }
}
```

**Fix:**
```cpp
int Parser::getPrecedence(TokenType type) const {
    // Higher number = Higher precedence (reverse of current)
    switch (type) {
        // Comparison (Lowest precedence)
        case TokenType::EQUAL:
        case TokenType::NOT_EQUAL:
        case TokenType::LESS_THAN:
        case TokenType::LESS_THAN_OR_EQUAL:
        case TokenType::GREATER_THAN:
        case TokenType::GREATER_THAN_OR_EQUAL: return 10;
        
        // Text concatenation
        case TokenType::CONCAT: return 20;
        
        // Addition and Subtraction
        case TokenType::PLUS:
        case TokenType::MINUS: return 30;
        
        // Multiplication and Division
        case TokenType::MULTIPLY:
        case TokenType::DIVIDE: return 40;
        
        // Exponentiation
        case TokenType::POWER: return 50;
        
        // Percentage (postfix)
        case TokenType::PERCENT: return 60;
        
        // Negation (unary)
        // Handle separately in parsePrefix
        
        // Reference operators (Highest precedence)
        case TokenType::COMMA: return 70;      // Union
        case TokenType::COLON: return 80;      // Range
        // Space intersection would be 75
        
        default: return 0;
    }
}
```

**Test:**
```cpp
// Add these test cases
ASSERT_EQUAL(evaluate("=5+2*3"), 11);      // Not 21
ASSERT_EQUAL(evaluate("=2^3*2"), 16);      // Not 512
ASSERT_EQUAL(evaluate("=10-5+3"), 8);      // Left to right
```

---

## 🔴 FIX #2: Absolute Reference Support ($)

**File:** `android/app/src/main/cpp/parser.cpp`

**Step 1:** Update scanIdentifier to handle $

```cpp
// Replace scanIdentifier function
Token Tokenizer::scanCellReference() {
    int start = pos;
    bool colAbsolute = false;
    bool rowAbsolute = false;
    
    // Check for column $
    if (currentChar() == '$') {
        colAbsolute = true;
        advance();
    }
    
    // Scan column letters (A-Z, max 3 letters)
    int colStart = pos;
    int colCount = 0;
    while (!isAtEnd() && isAlpha(currentChar()) && colCount < 3) {
        advance();
        colCount++;
    }
    
    if (colCount == 0) {
        return scanError(); // No column letters found
    }
    
    std::string column = source.substr(colStart, pos - colStart);
    
    // Check for row $
    if (currentChar() == '$') {
        rowAbsolute = true;
        advance();
    }
    
    // Scan row numbers
    int rowStart = pos;
    if (!isDigit(currentChar())) {
        // Not a cell reference, might be function name
        pos = start;
        return scanIdentifier(); // Fall back to regular identifier
    }
    
    while (!isAtEnd() && isDigit(currentChar())) {
        advance();
    }
    
    std::string row = source.substr(rowStart, pos - rowStart);
    
    // Validate row number
    if (row[0] == '0') {
        return scanError(); // Row can't start with 0
    }
    
    long rowNum = std::stol(row);
    if (rowNum > 1048576) {
        return scanError(); // Exceeds Excel max row
    }
    
    // Validate column name
    if (!isValidColumn(column)) {
        return scanError(); // Invalid column
    }
    
    // Build cell reference with $ markers
    std::string cellRef;
    if (colAbsolute) cellRef += "$";
    cellRef += column;
    if (rowAbsolute) cellRef += "$";
    cellRef += row;
    
    return {TokenType::IDENTIFIER, cellRef, start};
}

// Add helper function
bool Tokenizer::isValidColumn(const std::string& col) const {
    if (col.length() > 3 || col.empty()) return false;
    
    // Convert column name to index
    int index = 0;
    for (char c : col) {
        if (c < 'A' || c > 'Z') return false;
        index = index * 26 + (c - 'A' + 1);
    }
    
    // XFD = 16384 (max column in Excel)
    return index >= 1 && index <= 16384;
}
```

**Step 2:** Update ast.h to store absolute flags

```cpp
// In ast.h
class CellReferenceNode : public ASTNode {
public:
    std::string sheetName;
    std::string cellName;
    bool columnAbsolute;
    bool rowAbsolute;
    
    explicit CellReferenceNode(std::string name, std::string sheet = "", 
                               bool colAbs = false, bool rowAbs = false) 
        : sheetName(std::move(sheet)), 
          cellName(std::move(name)),
          columnAbsolute(colAbs),
          rowAbsolute(rowAbs) {}
    // ...
};
```

**Step 3:** Update tokenizer switch to use new function

```cpp
// In tokenize() switch statement
default:
    if (isDigit(c) || c == '.') {
        tks.push_back(scanNumber());
    } else if (c == '$' || isAlpha(c) || c == '_') {
        // Try to parse as cell reference first
        Token tok = scanCellReference();
        tks.push_back(tok);
    } else {
        advance();
    }
    break;
```

---

## 🔴 FIX #3: String Escape Sequences

**File:** `android/app/src/main/cpp/parser.cpp`

**Replace scanString function:**

```cpp
Token Tokenizer::scanString() {
    int start = pos;
    std::string result;
    advance(); // Skip opening "
    
    while (!isAtEnd()) {
        char c = currentChar();
        
        if (c == '"') {
            advance();
            // Check if it's escaped quote ""
            if (currentChar() == '"') {
                result += '"';  // Add single quote to result
                advance();
            } else {
                // End of string
                break;
            }
        } else {
            result += c;
            advance();
        }
    }
    
    return {TokenType::STRING, result, start};
}

// Same logic for scanSheetName
Token Tokenizer::scanSheetName() {
    int start = pos;
    std::string result;
    advance(); // Skip opening '
    
    while (!isAtEnd()) {
        char c = currentChar();
        
        if (c == '\'') {
            advance();
            // Check if it's escaped apostrophe ''
            if (currentChar() == '\'') {
                result += '\'';
                advance();
            } else {
                // End of sheet name
                break;
            }
        } else {
            result += c;
            advance();
        }
    }
    
    return {TokenType::IDENTIFIER, result, start};
}
```

---

## 🔴 FIX #4: Entire Row/Column References

**File:** `android/app/src/main/cpp/parser.cpp`

**Update range parsing logic:**

```cpp
// In parseExpression where COLON is handled (line ~209)
if (op == TokenType::COLON) {
    std::string leftRef = "";
    std::string rightRef = "";
    std::string sheetName = "";
    bool isEntireColumn = false;
    bool isEntireRow = false;
    
    auto* cellLeft = dynamic_cast<CellReferenceNode*>(left.get());
    auto* numLeft = dynamic_cast<NumberNode*>(left.get());
    
    if (cellLeft) {
        leftRef = cellLeft->cellName;
        sheetName = cellLeft->sheetName;
        
        // Check if it's just a column letter (for A:Z syntax)
        if (isColumnOnly(leftRef)) {
            isEntireColumn = true;
        }
    } else if (numLeft) {
        // Entire row reference (1:10)
        leftRef = std::to_string((int)numLeft->value);
        isEntireRow = true;
    }
    
    if (!leftRef.empty()) {
        auto right = parseExpression(getPrecedence(op));
        auto* cellRight = dynamic_cast<CellReferenceNode*>(right.get());
        auto* numRight = dynamic_cast<NumberNode*>(right.get());
        
        if (cellRight) {
            rightRef = cellRight->cellName;
            if (isEntireColumn && !isColumnOnly(rightRef)) {
                throw std::runtime_error("Invalid column range");
            }
        } else if (numRight) {
            rightRef = std::to_string((int)numRight->value);
            if (!isEntireRow) {
                throw std::runtime_error("Invalid row range");
            }
        }
        
        if (!rightRef.empty()) {
            auto rangeNode = std::make_unique<RangeReferenceNode>(
                leftRef, rightRef, sheetName
            );
            rangeNode->isEntireColumn = isEntireColumn;
            rangeNode->isEntireRow = isEntireRow;
            left = std::move(rangeNode);
            continue;
        }
    }
    throw std::runtime_error("Invalid range notation");
}

// Helper function
bool isColumnOnly(const std::string& ref) {
    for (char c : ref) {
        if (!isalpha(c) && c != '$') return false;
    }
    return true;
}
```

**Update ast.h:**

```cpp
class RangeReferenceNode : public ASTNode {
public:
    std::string sheetName;
    std::string topLeft;
    std::string bottomRight;
    bool isEntireColumn;
    bool isEntireRow;
    
    RangeReferenceNode(std::string tl, std::string br, std::string sheet = "") 
        : sheetName(std::move(sheet)), 
          topLeft(std::move(tl)), 
          bottomRight(std::move(br)),
          isEntireColumn(false),
          isEntireRow(false) {}
    // ...
};
```

---

## 🔴 FIX #5: Circular Reference Detection

**New File:** `android/app/src/main/cpp/circular_detector.h`

```cpp
#ifndef SPREADSHEET_CIRCULAR_DETECTOR_H
#define SPREADSHEET_CIRCULAR_DETECTOR_H

#include <string>
#include <unordered_set>
#include <vector>

class CircularReferenceDetector {
public:
    CircularReferenceDetector() {}
    
    void beginEvaluation(const std::string& cellRef) {
        if (evaluating.find(cellRef) != evaluating.end()) {
            // Circular reference detected!
            throw std::runtime_error("Circular reference: " + cellRef);
        }
        evaluating.insert(cellRef);
        evaluationStack.push_back(cellRef);
    }
    
    void endEvaluation(const std::string& cellRef) {
        evaluating.erase(cellRef);
        if (!evaluationStack.empty() && evaluationStack.back() == cellRef) {
            evaluationStack.pop_back();
        }
    }
    
    std::vector<std::string> getEvaluationStack() const {
        return evaluationStack;
    }
    
    void reset() {
        evaluating.clear();
        evaluationStack.clear();
    }
    
private:
    std::unordered_set<std::string> evaluating;
    std::vector<std::string> evaluationStack;
};

#endif
```

**Update evaluator.h:**

```cpp
#include "circular_detector.h"

class Evaluator : public ASTVisitor {
private:
    CircularReferenceDetector* circularDetector;
    // ...
public:
    void setCircularDetector(CircularReferenceDetector* detector) {
        circularDetector = detector;
    }
    // ...
};
```

**Update evaluator.cpp:**

```cpp
void Evaluator::visit(CellReferenceNode& node) {
    std::string ref = node.sheetName.empty() ? node.cellName 
                     : node.sheetName + "!" + node.cellName;
    
    // Check circular reference
    if (circularDetector) {
        circularDetector->beginEvaluation(ref);
    }
    
    // ... existing code ...
    
    if (getCell) {
        currentResult = getCell(ref);
    } else {
        currentResult = CellError{"#REF!"};
    }
    
    if (circularDetector) {
        circularDetector->endEvaluation(ref);
    }
}
```

---

## 🧪 TESTING CHECKLIST

### Test File: `test/cpp/parser_fixes_test.cpp`

```cpp
#include <gtest/gtest.h>
#include "parser.h"
#include "evaluator.h"

// Test Absolute References
TEST(ParserFixes, AbsoluteReferences) {
    EXPECT_NO_THROW(parse("=$A$1"));
    EXPECT_NO_THROW(parse("=$A1"));
    EXPECT_NO_THROW(parse("=A$1"));
    EXPECT_NO_THROW(parse("=SUM($A$1:$Z$100)"));
}

// Test Operator Precedence
TEST(ParserFixes, OperatorPrecedence) {
    EXPECT_EQ(evaluate("=5+2*3"), 11.0);
    EXPECT_EQ(evaluate("=2^3*2"), 16.0);
    EXPECT_EQ(evaluate("=10/2*5"), 25.0);  // Left to right
}

// Test String Escapes
TEST(ParserFixes, StringEscapes) {
    EXPECT_EQ(evaluate("=\"He said \"\"Hello\"\"\""), "He said \"Hello\"");
    EXPECT_EQ(evaluate("=\"It's \"\"working\"\"\""), "It's \"working\"");
}

// Test Entire Row/Column
TEST(ParserFixes, EntireRowColumn) {
    EXPECT_NO_THROW(parse("=SUM(A:A)"));
    EXPECT_NO_THROW(parse("=SUM(1:1)"));
    EXPECT_NO_THROW(parse("=AVERAGE(A:Z)"));
}

// Test Circular Detection
TEST(ParserFixes, CircularReference) {
    CircularReferenceDetector detector;
    // Setup: A1 = B1, B1 = A1
    EXPECT_THROW(evaluateWithCircular("A1", detector), std::runtime_error);
}

// Test Column Validation
TEST(ParserFixes, ColumnValidation) {
    EXPECT_NO_THROW(parse("=XFD1"));     // Max column
    EXPECT_THROW(parse("=XFE1"), ...);   // Invalid
    EXPECT_THROW(parse("=AAAA1"), ...);  // Too long
}

// Test Row Validation
TEST(ParserFixes, RowValidation) {
    EXPECT_NO_THROW(parse("=A1048576")); // Max row
    EXPECT_THROW(parse("=A1048577"), ...);
    EXPECT_THROW(parse("=A0"), ...);     // Row 0 invalid
}
```

---

