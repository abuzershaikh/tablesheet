/// Supported aggregation types in the Pivot Engine
enum AggregationType {
  sum,
  average,
  count,
  counta,
  min,
  max,
  median,
  mode,
  product,
  stdev,
  variance,
  percentile,
  quartile
}

extension AggregationTypeExtension on AggregationType {
  String get name {
    return toString().split('.').last.toUpperCase();
  }
  
  static AggregationType fromString(String val) {
    return AggregationType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => AggregationType.sum,
    );
  }
}
