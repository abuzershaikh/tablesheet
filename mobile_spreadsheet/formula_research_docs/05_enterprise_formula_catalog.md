# 05 - Enterprise Formula Catalog & Modular Engine Architecture

## 1. Overview
To achieve feature parity with Microsoft Excel and Google Sheets, the Mobile Spreadsheet Formula Engine is structured into 12 specialized modular categories containing over 200 functions.

## 2. Spreadsheet Engine Modular Architecture

```
Spreadsheet Engine
├── Formula Engine (lib/domain/services/formula/)
│   ├── math/            -> ABS, CEILING, FLOOR, POWER, ROUND, SQRT, SUM, SUMPRODUCT...
│   ├── statistical/     -> AVERAGE, COUNT, COUNTA, COUNTIF, MAX, MIN, MEDIAN, STDEV...
│   ├── logical/         -> IF, IFS, IFERROR, IFNA, AND, OR, NOT, XOR, SWITCH...
│   ├── lookup/          -> VLOOKUP, XLOOKUP, INDEX, MATCH, FILTER, SORT, UNIQUE...
│   ├── text/            -> CONCAT, TEXTJOIN, LEFT, RIGHT, MID, LEN, REPLACE, TRIM...
│   ├── date_time/       -> DATE, TODAY, NOW, DAY, MONTH, YEAR, DATEDIF, EDATE...
│   ├── financial/       -> FV, PV, PMT, IPMT, PPMT, RATE, NPER, NPV, IRR...
│   ├── database/        -> DAVERAGE, DCOUNT, DGET, DMAX, DMIN, DSUM...
│   ├── array/           -> ARRAYFORMULA, SEQUENCE, TRANSPOSE, FLATTEN...
│   ├── info/            -> ISBLANK, ISERROR, ISNUMBER, ISTEXT, ISEVEN, ISODD...
│   ├── engineering/     -> BIN2DEC, DEC2BIN, HEX2DEC, DEC2HEX...
│   └── inventory_billing/ -> Stock Value, Profit, Margin, Tax, GST, Invoice Total
├── Cell Engine
├── Table Engine
├── Theme Engine
├── Chart Engine
├── Drawing Engine
├── Pivot Engine
├── Filter Engine
├── Print Engine
├── Import/Export Engine
├── Collaboration Engine
└── AI Engine
```

## 3. Complete 12-Category Formula Specification

### 1. Math Functions
`ABS`, `ACOS`, `ACOSH`, `ASIN`, `ASINH`, `ATAN`, `ATAN2`, `CEILING`, `COMBIN`, `COS`, `COSH`, `DEGREES`, `EVEN`, `EXP`, `FACT`, `FLOOR`, `GCD`, `INT`, `LCM`, `LN`, `LOG`, `LOG10`, `MOD`, `MROUND`, `ODD`, `PI`, `POWER`, `PRODUCT`, `QUOTIENT`, `RADIANS`, `RAND`, `RANDBETWEEN`, `ROUND`, `ROUNDUP`, `ROUNDDOWN`, `SIGN`, `SIN`, `SINH`, `SQRT`, `SQRTPI`, `SUM`, `SUMPRODUCT`, `SUMSQ`, `TAN`, `TANH`, `TRUNC`

### 2. Statistical Functions
`AVERAGE`, `AVERAGEA`, `AVERAGEIF`, `AVERAGEIFS`, `COUNT`, `COUNTA`, `COUNTBLANK`, `COUNTIF`, `COUNTIFS`, `MAX`, `MAXA`, `MIN`, `MINA`, `MEDIAN`, `MODE`, `LARGE`, `SMALL`, `RANK`, `RANKAVG`, `PERCENTILE`, `PERCENTRANK`, `QUARTILE`, `STDEV`, `STDEVP`, `STDEV.S`, `STDEV.P`, `VAR`, `VARP`, `VAR.S`, `VAR.P`, `GEOMEAN`, `HARMEAN`

### 3. Logical Functions
`IF`, `IFS`, `IFERROR`, `IFNA`, `AND`, `OR`, `NOT`, `XOR`, `SWITCH`, `TRUE`, `FALSE`

### 4. Lookup & Reference Functions
`ADDRESS`, `CHOOSE`, `COLUMN`, `COLUMNS`, `HLOOKUP`, `INDEX`, `INDIRECT`, `LOOKUP`, `MATCH`, `OFFSET`, `ROW`, `ROWS`, `VLOOKUP`, `XLOOKUP`, `XMATCH`, `FILTER`, `SORT`, `SORTBY`, `UNIQUE`, `TAKE`, `DROP`, `CHOOSECOLS`, `CHOOSEROWS`

### 5. Text Functions
`ASC`, `CHAR`, `CLEAN`, `CODE`, `CONCAT`, `CONCATENATE`, `EXACT`, `FIND`, `LEFT`, `LEN`, `LOWER`, `MID`, `PROPER`, `REPLACE`, `REPT`, `RIGHT`, `SEARCH`, `SPLIT`, `SUBSTITUTE`, `TEXT`, `TEXTJOIN`, `TRIM`, `UPPER`, `VALUE`

### 6. Date & Time Functions
`DATE`, `DATEDIF`, `DATEVALUE`, `DAY`, `DAYS`, `EDATE`, `EOMONTH`, `HOUR`, `MINUTE`, `MONTH`, `NETWORKDAYS`, `NOW`, `SECOND`, `TIME`, `TIMEVALUE`, `TODAY`, `WEEKDAY`, `WEEKNUM`, `WORKDAY`, `YEAR`, `YEARFRAC`

### 7. Financial Functions
`FV`, `PV`, `PMT`, `IPMT`, `PPMT`, `RATE`, `NPER`, `NPV`, `IRR`, `MIRR`, `SLN`, `DB`, `DDB`

### 8. Database Functions
`DAVERAGE`, `DCOUNT`, `DCOUNTA`, `DGET`, `DMAX`, `DMIN`, `DPRODUCT`, `DSTDEV`, `DSUM`, `DVAR`

### 9. Array Functions
`ARRAYFORMULA`, `FILTER`, `FLATTEN`, `SEQUENCE`, `SORT`, `SORTN`, `TRANSPOSE`, `UNIQUE`, `WRAPROWS`, `WRAPCOLS`

### 10. Information Functions
`CELL`, `ERROR.TYPE`, `INFO`, `ISBLANK`, `ISERROR`, `ISEVEN`, `ISFORMULA`, `ISLOGICAL`, `ISNA`, `ISNONTEXT`, `ISNUMBER`, `ISODD`, `ISTEXT`, `N`, `NA`, `TYPE`

### 11. Engineering Functions
`BIN2DEC`, `BIN2HEX`, `DEC2BIN`, `DEC2HEX`, `HEX2BIN`, `HEX2DEC`

### 12. Inventory & Billing Business Presets
- **Stock Value**: `=SUMPRODUCT(PriceRange, StockRange)`
- **Profit**: `=SellingPrice - CostPrice`
- **Total Profit**: `=SUMPRODUCT(SalesRange, MarginRange)`
- **Low Stock Alert**: `=IF(StockCell <= ReorderLevelCell, "LOW STOCK", "OK")`
- **Out of Stock**: `=IF(StockCell = 0, "OUT OF STOCK", "IN STOCK")`
- **Expiry Alert**: `=IF(ExpiryDateCell <= TODAY(), "EXPIRED", "VALID")`
- **GST / Tax**: `=ROUND(Amount * TaxRate, 2)`
- **Net Amount**: `=GrossAmount - Discount + GST`
- **Remaining Stock**: `=OpeningStock + Purchases - Sales`
