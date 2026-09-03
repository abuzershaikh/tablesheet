import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chart_config.dart';
import '../models/pivot_result.dart';
import '../models/aggregation_type.dart';
import 'chart_engine.dart';
import 'pivot_engine.dart';
// import 'insight_engine.dart';
// import 'recommender_engine.dart';

/// The central facade for all Business Intelligence features.
/// UI and AI Agent interact only with this engine.
class AnalyticsEngine {
  static final AnalyticsEngine instance = AnalyticsEngine._internal();
  AnalyticsEngine._internal();

  final ChartEngine chartEngine = ChartEngine();
  final PivotEngine pivotEngine = PivotEngine();
  // final InsightEngine insightEngine = InsightEngine();
  // final RecommenderEngine recommenderEngine = RecommenderEngine();

  /// Requests a pivot operation (usually runs in background isolate)
  Future<PivotResult> createPivot({
    required String sheetId,
    required List<String> rowFields,
    List<String> colFields = const [],
    required List<String> dataFields,
    AggregationType aggType = AggregationType.sum,
  }) async {
    return await pivotEngine.pivot(
      sheetId: sheetId,
      rowFields: rowFields,
      colFields: colFields,
      dataFields: dataFields,
      aggType: aggType,
    );
  }

  /// Requests a chart to be generated and broadcasted to the floating dashboard.
  void createChart(ChartConfig config) {
    chartEngine.broadcastChart(config);
  }
}
