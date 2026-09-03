# BUG-01: Formula Tokenizer Abort on Missing Leading `=`

## Bug Overview

- **Bug ID**: `BUG-01`
- **Bug Name**: Formula Tokenizer Abort on Missing Leading `=`
- **File Location**: [`android/app/src/main/cpp/parser.cpp`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/android/app/src/main/cpp/parser.cpp)
- **Component**: Native C++ Formula Engine / Lexical Analyzer (`Tokenizer`)
- **Severity**: Critical (Caused formulas across all sheets to fail and return raw text)

---

## Detailed Description & Root Cause

When a cell formula (e.g., `=SUM(A1:A10)` or `=A1+B1`) was entered, the C++ `GridManager::setCellFormula()` and `GridManager::dfsEvaluate()` methods automatically stripped the leading `=` character before passing the formula string (`"SUM(A1:A10)"`) to `Tokenizer`.

Inside `parser.cpp`, `Tokenizer::tokenize()` contained the following logic:

```cpp
// BEFORE (Buggy Implementation):
std::vector<Token> Tokenizer::tokenize() {
    std::vector<Token> tks;
    if (!source.empty() && source[0] == '=') {
        advance();
    } else {
        bool isNum = true;
        for (char c : source) {
            if (!isDigit(c) && c != '.') { isNum = false; break; }
        }
        if (isNum && !source.empty()) {
            tks.push_back({TokenType::NUMBER, source, 0});
        } else {
            tks.push_back({TokenType::STRING, source, 0});
        }
        tks.push_back({TokenType::END_OF_FILE, "", (int)source.length()});
        return tks;
    }

    while (!isAtEnd()) {
        // ... token scanning ...
    }
```

### Why it failed:
1. `dfsEvaluate` passed `"SUM(A1:A10)"` (without `=`) into `Tokenizer`.
2. Because `source[0]` was `'S'` (not `'='`), the condition `source[0] == '='` evaluated to `false`.
3. The tokenizer entered the `else` branch, wrapping the entire formula `"SUM(A1:A10)"` into a single `STRING` token.
4. The AST parser parsed this single token as a literal string constant rather than an executable function call.
5. The C++ engine returned `"SUM(A1:A10)"` as the evaluated result, causing the UI to display raw formula text.

---

## How It Was Fixed

The premature `else` abort branch was removed. `Tokenizer::tokenize()` now skips a leading `=` if present and proceeds to scan function names, operators, identifiers, numbers, and range delimiters into distinct syntax tokens.

### Diff:

```diff
 std::vector<Token> Tokenizer::tokenize() {
     std::vector<Token> tks;
     if (!source.empty() && source[0] == '=') {
         advance();
-    } else {
-        bool isNum = true;
-        for (char c : source) {
-            if (!isDigit(c) && c != '.') { isNum = false; break; }
-        }
-        if (isNum && !source.empty()) {
-            tks.push_back({TokenType::NUMBER, source, 0});
-        } else {
-            tks.push_back({TokenType::STRING, source, 0});
-        }
-        tks.push_back({TokenType::END_OF_FILE, "", (int)source.length()});
-        return tks;
     }

     while (!isAtEnd()) {
```

---

## Verification

After applying this fix, formula expressions such as `SUM(A1:A10)` are tokenized into `IDENTIFIER(SUM)`, `LPAREN`, `IDENTIFIER(A1)`, `COLON`, `IDENTIFIER(A10)`, `RPAREN`. Formulas in all sheets now evaluate to accurate numerical and logical results.
