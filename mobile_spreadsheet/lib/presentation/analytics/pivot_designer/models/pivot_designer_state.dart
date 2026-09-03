import 'package:flutter/foundation.dart';
import '../../../../domain/analytics/models/aggregation_type.dart';
import '../../../../domain/analytics/models/pivot_theme.dart';

class PivotDesignerState extends ChangeNotifier {
  List<String> availableColumns;
  List<String> rowFields;
  List<String> colFields;
  List<String> dataFields;
  List<String> slicerFields;
  AggregationType aggType;
  PivotThemeMode themeMode;

  PivotDesignerState({
    required this.availableColumns,
    required this.rowFields,
    required this.colFields,
    required this.dataFields,
    required this.slicerFields,
    required this.aggType,
    required this.themeMode,
  });

  void addFieldToRows(String field) {
    if (!rowFields.contains(field)) {
      rowFields.add(field);
      notifyListeners();
    }
  }

  void removeFieldFromRows(String field) {
    rowFields.remove(field);
    notifyListeners();
  }

  void addFieldToCols(String field) {
    if (!colFields.contains(field)) {
      colFields.add(field);
      notifyListeners();
    }
  }

  void removeFieldFromCols(String field) {
    colFields.remove(field);
    notifyListeners();
  }

  void addFieldToData(String field) {
    if (!dataFields.contains(field)) {
      dataFields.add(field);
      notifyListeners();
    }
  }

  void removeFieldFromData(String field) {
    dataFields.remove(field);
    notifyListeners();
  }

  void addFieldToSlicers(String field) {
    if (!slicerFields.contains(field)) {
      slicerFields.add(field);
      notifyListeners();
    }
  }

  void removeFieldFromSlicers(String field) {
    slicerFields.remove(field);
    notifyListeners();
  }
  
  void setAggregationType(AggregationType type) {
    aggType = type;
    notifyListeners();
  }

  void setThemeMode(PivotThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }
}
