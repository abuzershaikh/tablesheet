import '../models/aggregation_type.dart';

/// Registry pattern for Aggregation logic.
/// Instead of hardcoding switch statements in the engine,
/// we map AggregationType to specific math functions.
class AggregationRegistry {
  static final Map<AggregationType, double Function(List<double>)> _evaluators = {
    AggregationType.sum: _sum,
    AggregationType.average: _average,
    AggregationType.count: _count,
    AggregationType.min: _min,
    AggregationType.max: _max,
  };

  static double evaluate(AggregationType type, List<double> values) {
    if (values.isEmpty) return 0.0;
    final evaluator = _evaluators[type] ?? _sum;
    return evaluator(values);
  }

  static double _sum(List<double> vals) => vals.fold(0.0, (a, b) => a + b);
  static double _average(List<double> vals) => _sum(vals) / vals.length;
  static double _count(List<double> vals) => vals.length.toDouble();
  static double _min(List<double> vals) => vals.reduce((a, b) => a < b ? a : b);
  static double _max(List<double> vals) => vals.reduce((a, b) => a > b ? a : b);
  
  // Future implementations (stdev, variance, percentile) can be added here easily.
}
