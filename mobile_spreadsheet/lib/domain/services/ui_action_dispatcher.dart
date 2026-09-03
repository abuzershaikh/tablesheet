import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../analytics/engines/analytics_engine.dart';
import '../analytics/models/chart_config.dart';

class UiActionDispatcher {
  static final UiActionDispatcher instance = UiActionDispatcher._internal();
  UiActionDispatcher._internal();

  /// Parses UI Actions embedded in the JS execution result 
  /// and dispatches them to the Flutter UI layer.
  void dispatch(List<dynamic> uiActions) {
    if (uiActions.isEmpty) return;

    for (var actionObj in uiActions) {
      if (actionObj is! Map<String, dynamic>) continue;

      final action = actionObj['action'] as String?;
      if (action == null) continue;

      debugPrint("[UiActionDispatcher] Received Action: $action");

      switch (action) {
        case 'create_chart':
          _handleCreateChart(actionObj['config']);
          break;
        case 'create_pivot':
          _handleCreatePivot(actionObj['config']);
          break;
        case 'select':
          _handleSelectRange(actionObj['range']);
          break;
        default:
          debugPrint("[UiActionDispatcher] Unknown action type: $action");
      }
    }
  }

  void _handleCreateChart(dynamic configJson) {
    if (configJson == null) return;
    
    try {
      final configMap = (configJson is String) ? jsonDecode(configJson) : configJson;
      
      final xCol = configMap['axis']?.toString() ?? 'A';
      final seriesRaw = configMap['series'] as List<dynamic>? ?? ['B'];
      final seriesList = seriesRaw.map((e) => e.toString()).toList();
      var chartTypeStr = configMap['chartType']?.toString() ?? 'bar';
      
      final chartTypeEnum = ChartType.values.firstWhere(
        (e) => e.name == chartTypeStr, 
        orElse: () => ChartType.bar,
      );
      
      List<Map<String, dynamic>> parsedData = [];
      if (configMap['data'] != null && configMap['data'] is List) {
        parsedData = (configMap['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final chartConfig = ChartConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: configMap['title']?.toString() ?? 'Javascript Chart',
        chartType: chartTypeEnum,
        series: seriesList,
        axis: xCol,
        data: parsedData,
      );

      AnalyticsEngine.instance.createChart(chartConfig);
    } catch (e) {
      debugPrint("[UiActionDispatcher] Error parsing chart config: $e");
    }
  }

  void _handleCreatePivot(dynamic configJson) {
    // Phase 2 implementation for pivot UI rendering
    debugPrint("[UiActionDispatcher] Pivot table UI creation requested: $configJson");
  }

  void _handleSelectRange(dynamic rangeStr) {
    // Notify the Grid UI to highlight this range
    debugPrint("[UiActionDispatcher] Select range requested: $rangeStr");
    // TODO: Create a Stream for Grid UI selection highlights
  }
}
