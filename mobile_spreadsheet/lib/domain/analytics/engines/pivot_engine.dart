import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/pivot_result.dart';
import '../models/pivot_theme.dart';
import '../models/slicer_config.dart';
import '../models/aggregation_type.dart';
import '../../services/super_engine/ffi_bridge.dart';

String _executePivotIsolate(String jsonRequest) {
  return NativeEngine.executePivot(jsonRequest);
}

class PivotEngine {
  Future<PivotResult> pivot({
    required String sheetId,
    required List<String> rowFields,
    required List<String> colFields,
    required List<String> dataFields,
    required AggregationType aggType,
    PivotThemeMode themeMode = PivotThemeMode.professionalBlue,
    List<String> slicerFields = const [],
    Map<String, List<String>> activeSlicerFilters = const {},
    List<Map<String, dynamic>> rawData = const [],
  }) async {
    final startTime = DateTime.now();
    final theme = PivotTheme.fromMode(themeMode);

    if (rawData.isNotEmpty) {
      return _buildInMemoryPivot(
        rawData: rawData,
        rowFields: rowFields,
        colFields: colFields,
        dataFields: dataFields,
        aggType: aggType,
        theme: theme,
        slicerFields: slicerFields,
        activeSlicerFilters: activeSlicerFilters,
        startTime: startTime,
      );
    }

    final requestMap = {
      'sheetId': sheetId,
      'rowFields': rowFields,
      'colFields': colFields,
      'dataFields': dataFields,
      'aggType': aggType.name,
      'slicerFields': slicerFields,
      'activeSlicerFilters': activeSlicerFilters,
    };
    final jsonRequest = jsonEncode(requestMap);

    try {
      final resultJsonStr = await compute(_executePivotIsolate, jsonRequest);
      final resultJson = jsonDecode(resultJsonStr);

      if (resultJson['error'] != null) {
        return PivotResult(
          rowFields: rowFields,
          colFields: colFields,
          dataFields: dataFields,
          aggregationType: aggType.name.toUpperCase(),
          groupedData: {},
          flatData: [],
          theme: theme,
          error: resultJson['error']?.toString(),
          computationTime: DateTime.now().difference(startTime),
        );
      }

      final flatData = List<Map<String, dynamic>>.from(resultJson['flatData'] ?? []);
      return _buildInMemoryPivot(
        rawData: flatData,
        rowFields: rowFields,
        colFields: colFields,
        dataFields: dataFields,
        aggType: aggType,
        theme: theme,
        slicerFields: slicerFields,
        activeSlicerFilters: activeSlicerFilters,
        startTime: startTime,
      );
    } catch (e, stack) {
      debugPrint('[PivotEngine ERROR in Native Path] $e\n$stack');
      return PivotResult(
        rowFields: rowFields,
        colFields: colFields,
        dataFields: dataFields,
        aggregationType: aggType.name.toUpperCase(),
        groupedData: {},
        flatData: [],
        theme: theme,
        error: e.toString(),
        computationTime: DateTime.now().difference(startTime),
      );
    }
  }

  double? _parseNumericValue(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    final s = val.toString().trim();
    if (s.isEmpty) return null;

    // Robust parsing: strip currency symbols, commas, spaces
    final sanitized = s
        .replaceAll(RegExp(r'[₹$€£¥¢]'), '')
        .replaceAll(',', '')
        .trim();

    if (sanitized.endsWith('%')) {
      final numStr = sanitized.substring(0, sanitized.length - 1).trim();
      final d = double.tryParse(numStr);
      if (d != null) return d / 100.0;
    }

    return double.tryParse(sanitized);
  }

  dynamic _getFieldVal(Map<String, dynamic> row, String field) {
    if (row.containsKey(field)) return row[field];
    final lower = field.toLowerCase().trim();
    for (final entry in row.entries) {
      if (entry.key.toLowerCase().trim() == lower) {
        return entry.value;
      }
    }
    // Check if field is a column letter (A, B, C, D...)
    if (field.length == 1) {
      final code = field.toUpperCase().codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        final idx = code - 65;
        if (idx >= 0 && idx < row.length) {
          return row.values.elementAt(idx);
        }
      }
    }
    return null;
  }

  PivotResult _buildInMemoryPivot({
    required List<Map<String, dynamic>> rawData,
    required List<String> rowFields,
    required List<String> colFields,
    required List<String> dataFields,
    required AggregationType aggType,
    required PivotTheme theme,
    required List<String> slicerFields,
    required Map<String, List<String>> activeSlicerFilters,
    required DateTime startTime,
  }) {
    try {
      // 1. Build Slicer Configs (Cross-filtering)
      final List<SlicerConfig> slicerConfigs = [];
      for (final field in slicerFields) {
        final Map<String, int> counts = {};
        final Set<String> allValues = {};

        for (final row in rawData) {
          final val = _getFieldVal(row, field)?.toString() ?? '';
          allValues.add(val);

          // Check if row matches all OTHER active slicer filters
          bool match = true;
          activeSlicerFilters.forEach((otherField, allowedVals) {
            if (otherField != field) {
              final rowVal = _getFieldVal(row, otherField)?.toString() ?? '';
              if (!allowedVals.contains(rowVal)) {
                match = false;
              }
            }
          });

          if (match) {
            counts[val] = (counts[val] ?? 0) + 1;
          }
        }

        final activeList = activeSlicerFilters[field];
        final items = allValues.map((v) {
          // If activeList is null (no filter applied yet), all are selected
          final isSelected = activeList == null || activeList.contains(v);
          final isEnabled = (counts[v] ?? 0) > 0;
          return SlicerItem(
            value: v,
            isSelected: isSelected,
            isEnabled: isEnabled,
            recordCount: counts[v] ?? 0,
          );
        }).toList();

        items.sort((a, b) => a.value.compareTo(b.value));
        slicerConfigs.add(SlicerConfig(fieldName: field, items: items));
      }

      // 2. Filter raw data based on ALL active slicer filters
      final filteredData = rawData.where((row) {
        for (final entry in activeSlicerFilters.entries) {
          final field = entry.key;
          final allowed = entry.value;
          final rowVal = _getFieldVal(row, field)?.toString() ?? '';
          if (!allowed.contains(rowVal)) return false;
        }
        return true;
      }).toList();

      // Helper function for aggregation
      double aggregate(List<double> vals, AggregationType type) {
        if (vals.isEmpty) return 0.0;
        switch (type) {
          case AggregationType.average:
            return vals.reduce((a, b) => a + b) / vals.length;
          case AggregationType.count:
            return vals.length.toDouble();
          case AggregationType.min:
            return vals.reduce((a, b) => a < b ? a : b);
          case AggregationType.max:
            return vals.reduce((a, b) => a > b ? a : b);
          case AggregationType.sum:
          default:
            return vals.reduce((a, b) => a + b);
        }
      }

      // 3. Perform Grouping & Aggregation
      final Set<String> uniqueRowKeys = {};
      final Set<String> uniqueColKeys = {};

      for (final row in filteredData) {
        final List<String> rParts = [];
        for (final rf in rowFields) {
          final fVal = _getFieldVal(row, rf);
          rParts.add(fVal?.toString()?.trim() ?? '(blank)');
        }
        uniqueRowKeys.add(rParts.join("||"));

        final List<String> cParts = [];
        for (final cf in colFields) {
          final fVal = _getFieldVal(row, cf);
          cParts.add(fVal?.toString()?.trim() ?? '(blank)');
        }
        uniqueColKeys.add(cParts.join("||"));
      }

      // Add default headers if lists are empty
      if (rowFields.isEmpty) uniqueRowKeys.add('(Total)');
      if (colFields.isEmpty) uniqueColKeys.add('');

      final List<String> sortedRowKeys = uniqueRowKeys.toList()..sort();
      final List<String> sortedColKeys = uniqueColKeys.toList()..sort();

      // Collect numeric values matching rowKey x colKey x df
      final Map<String, Map<String, Map<String, List<double>>>> cellValues = {};
      final Map<String, Map<String, List<double>>> rowGrandTotalValues = {};
      final Map<String, Map<String, List<double>>> colGrandTotalValues = {};
      final Map<String, List<double>> globalGrandTotalValues = {};

      for (final row in filteredData) {
        final List<String> rParts = [];
        for (final rf in rowFields) {
          final fVal = _getFieldVal(row, rf);
          rParts.add(fVal?.toString()?.trim() ?? '(blank)');
        }
        final rowKey = rowFields.isEmpty ? '(Total)' : rParts.join("||");

        final List<String> cParts = [];
        for (final cf in colFields) {
          final fVal = _getFieldVal(row, cf);
          cParts.add(fVal?.toString()?.trim() ?? '(blank)');
        }
        final colKey = colFields.isEmpty ? '' : cParts.join("||");

        for (final df in dataFields) {
          final rawVal = _getFieldVal(row, df);
          final valNum = _parseNumericValue(rawVal);

          if (valNum != null) {
            cellValues
                .putIfAbsent(rowKey, () => {})
                .putIfAbsent(colKey, () => {})
                .putIfAbsent(df, () => [])
                .add(valNum);

            rowGrandTotalValues
                .putIfAbsent(rowKey, () => {})
                .putIfAbsent(df, () => [])
                .add(valNum);

            colGrandTotalValues
                .putIfAbsent(colKey, () => {})
                .putIfAbsent(df, () => [])
                .add(valNum);

            globalGrandTotalValues
                .putIfAbsent(df, () => [])
                .add(valNum);
          }
        }
      }

      // Generate visual Row Header Grid
      final List<List<String>> rowHeaderGrid = sortedRowKeys.map((k) {
        return rowFields.isEmpty ? [k] : k.split("||");
      }).toList();

      // Generate visual Column Header Grid (Cross-grouped colFields x dataFields)
      final List<List<String>> colHeaderGrid = [];
      for (final colKey in sortedColKeys) {
        final List<String> colParts = colFields.isEmpty ? [] : colKey.split("||");
        for (final df in dataFields) {
          colHeaderGrid.add([...colParts, df]);
        }
      }

      // Populate Data Grid
      final List<List<dynamic>> dataGrid = [];
      for (final rowKey in sortedRowKeys) {
        final List<dynamic> rowDataList = [];
        for (final colKey in sortedColKeys) {
          for (final df in dataFields) {
            final vals = cellValues[rowKey]?[colKey]?[df] ?? [];
            rowDataList.add(aggregate(vals, aggType));
          }
        }
        dataGrid.add(rowDataList);
      }

      // Compute Row Grand Totals (across all columns per row, for each data field)
      final List<double> rowSubtotals = [];
      for (final rowKey in sortedRowKeys) {
        for (final df in dataFields) {
          final vals = rowGrandTotalValues[rowKey]?[df] ?? [];
          rowSubtotals.add(aggregate(vals, aggType));
        }
      }

      // Compute Column Grand Totals (across all rows per column group, for each data field)
      final List<double> colSubtotals = [];
      for (final colKey in sortedColKeys) {
        for (final df in dataFields) {
          final vals = colGrandTotalValues[colKey]?[df] ?? [];
          colSubtotals.add(aggregate(vals, aggType));
        }
      }

      // Compute global Grand Total (using the first data field)
      double grandTotalVal = 0.0;
      if (dataFields.isNotEmpty) {
        final firstDf = dataFields.first;
        final vals = globalGrandTotalValues[firstDf] ?? [];
        grandTotalVal = aggregate(vals, aggType);
      }

      // Compute flatData dynamically matching the aggregation type
      final List<Map<String, dynamic>> flatData = [];
      for (final rowKey in sortedRowKeys) {
        final List<String> rParts = rowFields.isEmpty ? [] : rowKey.split("||");
        for (final colKey in sortedColKeys) {
          final List<String> cParts = colFields.isEmpty ? [] : colKey.split("||");

          final Map<String, dynamic> flatRow = {};
          for (int i = 0; i < rowFields.length; i++) {
            if (i < rParts.length) flatRow[rowFields[i]] = rParts[i];
          }
          for (int i = 0; i < colFields.length; i++) {
            if (i < cParts.length) flatRow[colFields[i]] = cParts[i];
          }

          bool hasData = false;
          for (final df in dataFields) {
            final vals = cellValues[rowKey]?[colKey]?[df] ?? [];
            if (vals.isNotEmpty) {
              flatRow[df] = aggregate(vals, aggType);
              hasData = true;
            } else {
              flatRow[df] = null;
            }
          }

          if (hasData) {
            flatData.add(flatRow);
          }
        }
      }

      return PivotResult(
        rowFields: rowFields,
        colFields: colFields,
        dataFields: dataFields,
        aggregationType: aggType.name.toUpperCase(),
        groupedData: {},
        flatData: flatData,
        rowHeaderGrid: rowHeaderGrid,
        colHeaderGrid: colHeaderGrid,
        dataGrid: dataGrid,
        rowSubtotals: rowSubtotals,
        colSubtotals: colSubtotals,
        grandTotal: grandTotalVal,
        theme: theme,
        slicers: slicerConfigs,
        computationTime: DateTime.now().difference(startTime),
      );
    } catch (e, stack) {
      debugPrint('[PivotEngine ERROR] $e\n$stack');
      return PivotResult(
        rowFields: rowFields,
        colFields: colFields,
        dataFields: dataFields,
        aggregationType: aggType.name.toUpperCase(),
        groupedData: {},
        flatData: [],
        theme: theme,
        error: e.toString(),
        computationTime: DateTime.now().difference(startTime),
      );
    }
  }
}
