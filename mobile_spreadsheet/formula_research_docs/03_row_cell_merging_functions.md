# 03 - Row & Cell Data Merging & String Functions

## 1. Multi-Cell & Multi-Row String Concatenation

Users frequently need to combine text from 2 rows/columns or 3 rows/columns into a single output cell (e.g. First Name + Last Name, or Code + Category + Date).

### Supported Formulas for Merging
1. **String Concatenation Operator (`&`)**:
   - `=A1 & " " & B1` (Merges 2 cells/rows with a space)
   - `=A1 & "-" & B1 & "-" & C1` (Merges 3 cells/rows with hyphens)

2. **`CONCAT(text1, text2)` / `CONCATENATE(text1, text2, ...)`**:
   - `=CONCAT(A1, B1)`
   - `=CONCATENATE(A1, " ", B1, " ", C1)` (Merges 3 rows/cells)

3. **`TEXTJOIN(delimiter, ignore_empty, text1, text2, ...)`**:
   - `=TEXTJOIN(" ", TRUE, A1, B1, C1)` (Combines 3 rows/cells using " " as separator, skipping empty cells)

4. **`JOIN(delimiter, value_or_array)`**:
   - `=JOIN(" ", A1:C1)` (Joins range of 3 cells into a single string)

## 2. Text Manipulation Functions
- `=UPPER(text)`: Converts string to UPPERCASE.
- `=LOWER(text)`: Converts string to lowercase.
- `=PROPER(text)`: Capitalizes First Letter Of Each Word.
- `=LEN(text)`: Returns character count of cell string.
- `=TRIM(text)`: Removes extra leading and trailing whitespace.
- `=LEFT(text, num_chars)`: Extracts characters from start of text.
- `=RIGHT(text, num_chars)`: Extracts characters from end of text.
