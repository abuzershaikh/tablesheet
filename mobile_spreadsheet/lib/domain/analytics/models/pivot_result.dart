import 'pivot_theme.dart';
import 'slicer_config.dart';

class PivotResult {
  final List<String> rowFields;
  final List<String> colFields;
  final List<String> dataFields;
  final String aggregationType; // SUM, AVG, COUNT, MIN, MAX

  final Map<String, dynamic> groupedData;
  final List<Map<String, dynamic>> flatData;

  final List<List<String>> rowHeaderGrid;
  final List<List<String>> colHeaderGrid;
  final List<List<dynamic>> dataGrid;
  final List<double> rowSubtotals;
  final List<double> colSubtotals;
  final double grandTotal;

  final String? error;

  final PivotTheme theme;
  final List<SlicerConfig> slicers;
  final Duration computationTime;

  PivotResult({
    required this.rowFields,
    this.colFields = const [],
    required this.dataFields,
    this.aggregationType = 'SUM',
    required this.groupedData,
    required this.flatData,
    this.rowHeaderGrid = const [],
    this.colHeaderGrid = const [],
    this.dataGrid = const [],
    this.rowSubtotals = const [],
    this.colSubtotals = const [],
    this.grandTotal = 0.0,
    required this.theme,
    this.slicers = const [],
    required this.computationTime,
    this.error,
  });
}
