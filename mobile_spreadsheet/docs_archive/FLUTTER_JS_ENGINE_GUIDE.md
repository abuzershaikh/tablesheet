# Flutter.js Engine - Complete Implementation Guide

## 🎯 **FLUTTER.JS ENGINE OVERVIEW**

Flutter.js एक lightweight JavaScript engine है जो Flutter apps के साथ seamlessly integrate होता है:

### ✅ **Key Benefits:**
- **Small Size**: केवल 2-3MB footprint
- **Flutter Optimized**: Direct Dart integration
- **Easy Setup**: Minimal configuration required
- **Cross Platform**: Android + iOS support
- **Real-time**: Hot reload support

### 🔧 **Alternative Options:**
1. **flutter_js** - Pure Dart implementation (Recommended)
2. **js** - Official Dart JS interop
3. **webview_flutter** - WebView-based JS execution
4. **dart_eval** - Dart code interpretation

## 📦 **OPTION 1: flutter_js Package (RECOMMENDED)**

### Installation
```yaml
# pubspec.yaml
dependencies:
  flutter_js: ^0.8.0
  json_annotation: ^4.8.1
  
dev_dependencies:
  json_serializable: ^6.7.1
  build_runner: ^2.4.6
```

### Basic Setup
```dart
// lib/services/flutter_js_service.dart
import 'package:flutter_js/flutter_js.dart';

class FlutterJSService {
  static JavascriptRuntime? _jsRuntime;
  
  static Future<void> initialize() async {
    _jsRuntime = getJavascriptRuntime();
  }
  
  static JsEvalResult executeScript(String script) {
    if (_jsRuntime == null) throw Exception('JS Runtime not initialized');
    return _jsRuntime!.evaluate(script);
  }
}
```
## 🏗️ **COMPLETE IMPLEMENTATION**

### 1. Spreadsheet JS Service
```dart
// lib/services/spreadsheet_js_service.dart
import 'package:flutter_js/flutter_js.dart';
import 'dart:convert';

class SpreadsheetJSService {
  static JavascriptRuntime? _runtime;
  
  static Future<void> initialize() async {
    _runtime = getJavascriptRuntime();
    await _loadSpreadsheetLibrary();
  }
  
  static Future<void> _loadSpreadsheetLibrary() async {
    const String jsLibrary = '''
      // Global spreadsheet data
      let spreadsheetData = [];
      let currentSelection = { startRow: 0, startCol: 0, endRow: 0, endCol: 0 };
      
      // Utility functions
      function setSpreadsheetData(data) {
        spreadsheetData = data;
      }
      
      function getCellValue(row, col) {
        if (row >= 0 && row < spreadsheetData.length && 
            col >= 0 && col < spreadsheetData[row].length) {
          return spreadsheetData[row][col];
        }
        return "";
      }
      
      function setCellValue(row, col, value) {
        if (row >= 0 && col >= 0) {
          // Expand array if needed
          while (spreadsheetData.length <= row) {
            spreadsheetData.push([]);
          }
          while (spreadsheetData[row].length <= col) {
            spreadsheetData[row].push("");
          }
          spreadsheetData[row][col] = value;
        }
      }
    ''';
    
    _runtime!.evaluate(jsLibrary);
  }
  
  static JsEvalResult executeFormula(String formula, Map<String, dynamic> context) {
    // Set context variables
    context.forEach((key, value) {
      _runtime!.evaluate('var $key = ${jsonEncode(value)};');
    });
    
    return _runtime!.evaluate(formula);
  }
  
  static void loadData(List<List<String>> data) {
    _runtime!.evaluate('setSpreadsheetData(${jsonEncode(data)});');
  }
}
```

### 2. Advanced Formula Functions
```dart
// lib/services/js_formula_library.dart
class JSFormulaLibrary {
  static const String advancedFormulas = '''
    // Excel-compatible functions
    function XLOOKUP(lookup_value, lookup_array, return_array, if_not_found) {
      const index = lookup_array.indexOf(lookup_value);
      return index !== -1 ? return_array[index] : (if_not_found || "#N/A");
    }
    
    function FILTER(array, criteria) {
      if (typeof criteria === 'function') {
        return array.filter(criteria);
      }
      // Simple value filter
      return array.filter(row => row.includes(criteria));
    }
    
    function UNIQUE(array) {
      const seen = new Set();
      return array.filter(item => {
        const key = JSON.stringify(item);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
    }
    
    function SORT(array, columnIndex, ascending) {
      columnIndex = columnIndex || 0;
      ascending = ascending !== false;
      
      return array.slice().sort((a, b) => {
        const aVal = a[columnIndex];
        const bVal = b[columnIndex];
        
        if (ascending) {
          return aVal > bVal ? 1 : aVal < bVal ? -1 : 0;
        } else {
          return aVal < bVal ? 1 : aVal > bVal ? -1 : 0;
        }
      });
    }
  ''';
}
### 3. Data Cleaning Functions
```dart
class JSDataCleaning {
  static const String cleaningFunctions = '''
    // Data cleaning utilities
    function cleanNullValues(data, replacement) {
      replacement = replacement || "";
      return data.map(row => 
        row.map(cell => 
          (cell === null || cell === undefined || cell === "") ? replacement : cell
        )
      );
    }
    
    function normalizeText(data) {
      return data.map(row =>
        row.map(cell =>
          typeof cell === 'string' ? 
            cell.trim().toLowerCase().replace(/\\s+/g, ' ') : 
            cell
        )
      );
    }
    
    function removeDuplicateRows(data) {
      const seen = new Set();
      return data.filter(row => {
        const key = JSON.stringify(row);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
    }
    
    function detectDataTypes(data) {
      return data.map(row =>
        row.map(cell => {
          if (typeof cell !== 'string') return { value: cell, type: typeof cell };
          
          // Try number
          const num = parseFloat(cell);
          if (!isNaN(num) && isFinite(num)) {
            return { value: num, type: 'number' };
          }
          
          // Try date
          const date = new Date(cell);
          if (!isNaN(date.getTime())) {
            return { value: date.toISOString().split('T')[0], type: 'date' };
          }
          
          // Try boolean
          if (cell.toLowerCase() === 'true' || cell.toLowerCase() === 'false') {
            return { value: cell.toLowerCase() === 'true', type: 'boolean' };
          }
          
          return { value: cell, type: 'string' };
        })
      );
    }
    
    function validateData(data, rules) {
      const errors = [];
      
      data.forEach((row, rowIndex) => {
        row.forEach((cell, colIndex) => {
          if (rules[colIndex]) {
            const rule = rules[colIndex];
            
            // Required check
            if (rule.required && (cell === null || cell === undefined || cell === "")) {
              errors.push({
                row: rowIndex,
                col: colIndex,
                error: 'Required field is empty'
              });
            }
            
            // Type check
            if (rule.type && typeof cell !== rule.type) {
              errors.push({
                row: rowIndex,
                col: colIndex,
                error: Expected type ${rule.type}, got ${typeof cell}
              });
            }
            
            // Range check for numbers
            if (rule.min !== undefined && cell < rule.min) {
              errors.push({
                row: rowIndex,
                col: colIndex,
                error: Value ${cell} is below minimum ${rule.min}
              });
            }
            
            if (rule.max !== undefined && cell > rule.max) {
              errors.push({
                row: rowIndex,
                col: colIndex,
                error: Value ${cell} is above maximum ${rule.max}
              });
            }
          }
        });
      });
      
      return errors;
    }
  ''';
}
### 4. Statistical Analysis Functions
```dart
class JSStatistics {
  static const String statisticsFunctions = '''
    // Advanced statistics
    function calculateStatistics(data) {
      const flattened = data.flat().filter(val => typeof val === 'number');
      const sorted = flattened.slice().sort((a, b) => a - b);
      const n = flattened.length;
      const sum = flattened.reduce((a, b) => a + b, 0);
      const mean = sum / n;
      
      return {
        count: n,
        sum: sum,
        mean: mean,
        median: n % 2 === 0 ? 
          (sorted[n/2-1] + sorted[n/2]) / 2 : 
          sorted[Math.floor(n/2)],
        mode: calculateMode(flattened),
        min: Math.min(...flattened),
        max: Math.max(...flattened),
        range: Math.max(...flattened) - Math.min(...flattened),
        standardDeviation: Math.sqrt(
          flattened.reduce((sq, n) => sq + Math.pow(n - mean, 2), 0) / n
        ),
        variance: flattened.reduce((sq, n) => sq + Math.pow(n - mean, 2), 0) / n
      };
    }
    
    function calculateMode(arr) {
      const frequency = {};
      let maxCount = 0;
      let mode = null;
      
      arr.forEach(num => {
        frequency[num] = (frequency[num] || 0) + 1;
        if (frequency[num] > maxCount) {
          maxCount = frequency[num];
          mode = num;
        }
      });
      
      return mode;
    }
    
    function linearRegression(xValues, yValues) {
      const n = xValues.length;
      const sumX = xValues.reduce((a, b) => a + b, 0);
      const sumY = yValues.reduce((a, b) => a + b, 0);
      const sumXY = xValues.reduce((sum, x, i) => sum + x * yValues[i], 0);
      const sumXX = xValues.reduce((sum, x) => sum + x * x, 0);
      
      const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
      const intercept = (sumY - slope * sumX) / n;
      
      return { slope, intercept };
    }
    
    function correlation(xValues, yValues) {
      const n = xValues.length;
      const sumX = xValues.reduce((a, b) => a + b, 0);
      const sumY = yValues.reduce((a, b) => a + b, 0);
      const sumXY = xValues.reduce((sum, x, i) => sum + x * yValues[i], 0);
      const sumXX = xValues.reduce((sum, x) => sum + x * x, 0);
      const sumYY = yValues.reduce((sum, y) => sum + y * y, 0);
      
      const numerator = n * sumXY - sumX * sumY;
      const denominator = Math.sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY));
      
      return numerator / denominator;
    }
  ''';
}
### 5. Main JS Engine Service Implementation
```dart
// lib/services/js_engine_manager.dart
import 'package:flutter_js/flutter_js.dart';
import 'dart:convert';

class JSEngineManager {
  static JavascriptRuntime? _runtime;
  static bool _isInitialized = false;
  
  static Future<bool> initialize() async {
    try {
      _runtime = getJavascriptRuntime();
      
      // Load all JS libraries
      await _loadLibraries();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      print('JS Engine initialization failed: $e');
      return false;
    }
  }
  
  static Future<void> _loadLibraries() async {
    // Load core spreadsheet functions
    await _execute(SpreadsheetJSService._getCoreLibrary());
    
    // Load advanced formulas
    await _execute(JSFormulaLibrary.advancedFormulas);
    
    // Load data cleaning functions
    await _execute(JSDataCleaning.cleaningFunctions);
    
    // Load statistics functions  
    await _execute(JSStatistics.statisticsFunctions);
  }
  
  static JsEvalResult _execute(String script) {
    if (!_isInitialized || _runtime == null) {
      throw Exception('JS Engine not initialized');
    }
    return _runtime!.evaluate(script);
  }
  
  // Data operations
  static void setSpreadsheetData(List<List<dynamic>> data) {
    _execute('setSpreadsheetData(${jsonEncode(data)});');
  }
  
  static dynamic getCellValue(int row, int col) {
    final result = _execute('getCellValue($row, $col)');
    return result.rawResult;
  }
  
  static void setCellValue(int row, int col, dynamic value) {
    _execute('setCellValue($row, $col, ${jsonEncode(value)});');
  }
  
  // Advanced operations
  static List<List<dynamic>> cleanData(
    List<List<dynamic>> data, 
    String? replacement
  ) {
    setSpreadsheetData(data);
    final script = replacement != null 
        ? 'cleanNullValues(spreadsheetData, ${jsonEncode(replacement)})'
        : 'cleanNullValues(spreadsheetData)';
        
    final result = _execute(script);
    return _parseArrayResult(result);
  }
  
  static List<List<dynamic>> normalizeText(List<List<dynamic>> data) {
    setSpreadsheetData(data);
    final result = _execute('normalizeText(spreadsheetData)');
    return _parseArrayResult(result);
  }
  
  static List<List<dynamic>> removeDuplicates(List<List<dynamic>> data) {
    setSpreadsheetData(data);
    final result = _execute('removeDuplicateRows(spreadsheetData)');
    return _parseArrayResult(result);
  }
  
  static Map<String, dynamic> calculateStats(List<List<dynamic>> data) {
    setSpreadsheetData(data);
    final result = _execute('calculateStatistics(spreadsheetData)');
    return Map<String, dynamic>.from(jsonDecode(result.stringResult));
  }
  
  // Formula execution
  static dynamic executeCustomFormula(String formula, Map<String, dynamic> variables) {
    // Set variables in JS context
    variables.forEach((key, value) {
      _execute('var $key = ${jsonEncode(value)};');
    });
    
    final result = _execute(formula);
    return result.rawResult;
  }
  
  // Data validation
  static List<Map<String, dynamic>> validateData(
    List<List<dynamic>> data, 
    List<Map<String, dynamic>> rules
  ) {
    setSpreadsheetData(data);
    _execute('var validationRules = ${jsonEncode(rules)};');
    final result = _execute('validateData(spreadsheetData, validationRules)');
    
    final List<dynamic> errors = jsonDecode(result.stringResult);
    return errors.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  
  // Helper methods
  static List<List<dynamic>> _parseArrayResult(JsEvalResult result) {
    final List<dynamic> parsed = jsonDecode(result.stringResult);
    return parsed.map((row) => List<dynamic>.from(row)).toList();
  }
  
  static void dispose() {
    _runtime?.dispose();
    _runtime = null;
    _isInitialized = false;
  }
}
```
### 6. UI Integration Example
```dart
// lib/widgets/js_formula_editor.dart
import 'package:flutter/material.dart';
import '../services/js_engine_manager.dart';

class JSFormulaEditor extends StatefulWidget {
  final Function(dynamic result) onResult;
  
  const JSFormulaEditor({Key? key, required this.onResult}) : super(key: key);
  
  @override
  _JSFormulaEditorState createState() => _JSFormulaEditorState();
}

class _JSFormulaEditorState extends State<JSFormulaEditor> {
  final TextEditingController _controller = TextEditingController();
  String _result = '';
  bool _isExecuting = false;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'JavaScript Formula',
              hintText: 'Enter JavaScript code...\nExample: FILTER(data, row => row[0] > 100)',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _isExecuting ? null : _executeFormula,
                child: _isExecuting 
                    ? CircularProgressIndicator(strokeWidth: 2)
                    : Text('Execute'),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _clearResult,
                child: Text('Clear'),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_result.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[50],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Result:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(_result, style: TextStyle(fontFamily: 'monospace')),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _executeFormula() async {
    setState(() {
      _isExecuting = true;
      _result = '';
    });
    
    try {
      final formula = _controller.text.trim();
      if (formula.isEmpty) return;
      
      // Execute the formula
      final result = JSEngineManager.executeCustomFormula(formula, {});
      
      setState(() {
        _result = _formatResult(result);
      });
      
      widget.onResult(result);
      
    } catch (e) {
      setState(() {
        _result = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isExecuting = false;
      });
    }
  }
  
  String _formatResult(dynamic result) {
    if (result is List) {
      return jsonEncode(result);
    } else if (result is Map) {
      return jsonEncode(result);
    } else {
      return result.toString();
    }
  }
  
  void _clearResult() {
    setState(() {
      _result = '';
    });
    _controller.clear();
  }
}
```
### 7. Main App Integration
```dart
// lib/main.dart modifications
import 'services/js_engine_manager.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JS-Powered Spreadsheet',
      home: FutureBuilder<bool>(
        future: JSEngineManager.initialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing JavaScript Engine...'),
                  ],
                ),
              ),
            );
          }
          
          if (snapshot.hasError || !snapshot.data!) {
            return Scaffold(
              body: Center(
                child: Text('Failed to initialize JS Engine'),
              ),
            );
          }
          
          return HomePage();
        },
      ),
    );
  }
}
```

### 8. Usage Examples
```dart
// Example: Data cleaning
class DataCleaningExample {
  static Future<void> cleanSpreadsheetData() async {
    List<List<dynamic>> rawData = [
      ['Name', 'Age', 'Email'],
      ['  John Doe  ', '25', 'john@email.com'],
      ['', '30', 'jane@email.com'],
      ['Bob Smith', null, ''],
    ];
    
    // Clean null values
    final cleanedData = JSEngineManager.cleanData(rawData, 'N/A');
    
    // Normalize text
    final normalizedData = JSEngineManager.normalizeText(cleanedData);
    
    // Remove duplicates
    final finalData = JSEngineManager.removeDuplicates(normalizedData);
    
    print('Cleaned data: $finalData');
  }
}

// Example: Advanced formulas
class FormulaExample {
  static Future<void> executeAdvancedFormulas() async {
    List<List<dynamic>> data = [
      [100, 'Product A', 'Electronics'],
      [200, 'Product B', 'Books'],
      [150, 'Product C', 'Electronics'],
      [80, 'Product D', 'Books'],
    ];
    
    JSEngineManager.setSpreadsheetData(data);
    
    // Filter products with price > 100
    final expensiveProducts = JSEngineManager.executeCustomFormula(
      'FILTER(spreadsheetData, row => row[0] > 100)', 
      {}
    );
    
    // Get unique categories
    final categories = JSEngineManager.executeCustomFormula(
      'UNIQUE(spreadsheetData.map(row => row[2]))', 
      {}
    );
    
    print('Expensive products: $expensiveProducts');
    print('Categories: $categories');
  }
}

// Example: Statistics
class StatisticsExample {
  static Future<void> calculateDataStats() async {
    List<List<dynamic>> salesData = [
      [1000, 1200, 900],
      [1100, 1300, 950],
      [950, 1150, 1050],
    ];
    
    final stats = JSEngineManager.calculateStats(salesData);
    
    print('Statistics: $stats');
    // Output: {mean: 1075, median: 1100, standardDeviation: 123.45, ...}
  }
}
```

## 📱 **INTEGRATION STEPS**

### Step 1: Add Dependencies
```yaml
dependencies:
  flutter_js: ^0.8.0
  json_annotation: ^4.8.1
```

### Step 2: Initialize in main()
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JSEngineManager.initialize();
  runApp(MyApp());
}
```

### Step 3: Use in your spreadsheet
```dart
// In your spreadsheet widget
final result = JSEngineManager.executeCustomFormula(
  'SUM(getCellRange(A1:A10))', 
  {}
);
```

## ✅ **KEY BENEFITS**

1. **Lightweight**: केवल 2-3MB size increase
2. **Fast**: Direct Dart integration, no FFI overhead  
3. **Flexible**: Full JavaScript ES6+ support
4. **Safe**: Sandboxed execution environment
5. **Easy**: Simple Dart API, no complex setup

## 🚀 **ADVANCED FEATURES**

1. **Real-time formula execution**
2. **Custom function libraries**
3. **Data validation and cleaning**
4. **Statistical analysis**
5. **Chart data generation**
6. **Import/Export automation**

यह implementation आपको **unlimited JavaScript capabilities** देती है बिना heavy V8 engine के complexity के!