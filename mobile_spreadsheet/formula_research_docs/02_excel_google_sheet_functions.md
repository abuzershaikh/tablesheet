# 02 - Excel & Google Sheets Mathematical & Sales Functions

## 1. Primary E-Commerce & Sales Calculation Use-Cases

### Row-Wise Multiplication (Price * Sale = Total)
- **Formula Syntax**: `=A2*B2` or `=MULTIPLY(A2, B2)` or `=PRODUCT(A2, B2)`
- **Example Scenario**:
  - Column A: Price (e.g. `250`)
  - Column B: Sales / Quantity (e.g. `4`)
  - Column C: Total (`=A2*B2` -> `1000`)

### Summary & Aggregate Functions
- `=SUM(A2:A100)`: Calculates the sum of a range of cells.
- `=AVERAGE(A2:A100)`: Calculates the mean of a range.
- `=MIN(A2:A100)`: Finds the minimum value.
- `=MAX(A2:A100)`: Finds the maximum value.
- `=COUNT(A2:A100)`: Counts numeric cells.
- `=COUNTA(A2:A100)`: Counts non-empty cells.

## 2. Standard Mathematical Operators
| Operator | Function | Example | Result |
| :--- | :--- | :--- | :--- |
| `+` | Addition | `=A1 + B1` | `Sum of A1 and B1` |
| `-` | Subtraction | `=A1 - B1` | `Difference of A1 and B1` |
| `*` | Multiplication | `=A1 * B1` | `Product of A1 and B1` |
| `/` | Division | `=A1 / B1` | `Quotient of A1 and B1` |
| `^` | Exponentiation | `=A1 ^ 2` | `Square of A1` |
| `%` | Percentage | `=A1 * 10%` | `10 percent of A1` |

## 3. Financial & Business Functions
- `=ROUND(value, decimals)`: Rounds number to specified decimal places.
- `=SUBTRACT(value1, value2)`: Returns difference.
- `=DIVIDE(numerator, denominator)`: Returns division result.
- `=MOD(dividend, divisor)`: Returns remainder.
- `=ABS(value)`: Returns absolute value.
