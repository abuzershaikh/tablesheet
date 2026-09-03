# 01 - Formula Engine Architecture & Syntax Parser

## 1. Overview
The Formula Engine provides real-time, high-performance evaluation of spreadsheet formulas matching Microsoft Excel and Google Sheets syntax standards.

## 2. Core Components

```
+-----------------------------------------------------------------+
|                       User Input (Cell)                         |
|                 e.g. "=A2*B2" or "=SUM(A1:A10)"                 |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|                      1. Lexer / Tokenizer                       |
|           Splits text into Tokens (CELL_REF, OP, NUMBER)        |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|                   2. Parser / AST Generator                     |
|           Builds Abstract Syntax Tree (Shunting-Yard)           |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|                   3. Dependency Graph Resolver                  |
|          Detects circular references (A1 -> B1 -> A1)           |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|                   4. Formula Evaluation Engine                  |
|    Dart Engine (scalar) & C++ NDK / Vulkan GPU (bulk vector)    |
+-----------------------------------------------------------------+
```

## 3. Cell Coordinate System & References
- **Cell Notation**: `A1`, `B2`, `AA100` (Column letters + Row numbers).
- **Range Notation**: `A1:B10` (Rectangular cell matrix).
- **Relative & Absolute References**: `A1`, `$A$1`, `A$1`, `$A1`.

## 4. Evaluation Cycle & Dependency Graph
- Each cell containing a formula starting with `=` is registered in a Directed Acyclic Graph (DAG).
- When a cell value changes (e.g. Price in A2 or Quantity in B2), all dependent cells (e.g. Total in C2) are automatically re-calculated.
- Circular dependency detection prevents infinite calculation loops (returns `#CIRCULAR!`).
