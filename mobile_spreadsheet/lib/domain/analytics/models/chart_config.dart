/// Defines the types of charts available in the Analytics Engine.
enum ChartType {
  bar,
  column,
  line,
  pie,
  donut,
  scatter,
  area,
  radar,
  histogram,
  treemap,
  pivotTable,
}

/// Generic configuration for rendering any chart.
/// This decouples the AI logic from the specific rendering library (like fl_chart).
class ChartConfig {
  final String id;
  final String title;
  final String subtitle;
  final ChartType chartType;
  
  // Data mappings
  final List<String> series; // The Y-axis or values (e.g., ['SUM_Sales', 'AVG_Profit'])
  final String axis;         // The X-axis or categories (e.g., 'Region')
  
  // Data Payload
  final List<Map<String, dynamic>> data;

  // Customization
  final bool showLegend;
  final String theme; // 'light', 'dark', 'corporate', etc.
  final bool animate;
  final bool interactive;

  // New Animation and Styling Properties
  final int animationDurationMs;
  final List<dynamic> themeColors;
  final String chartStyle;

  ChartConfig({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.chartType,
    required this.series,
    required this.axis,
    required this.data,
    this.showLegend = true,
    this.theme = 'default',
    this.animate = true,
    this.interactive = true,
    this.animationDurationMs = 500,
    this.themeColors = const [],
    this.chartStyle = 'flat',
  });

  /// Useful for caching or serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'chartType': chartType.name,
      'series': series,
      'axis': axis,
      'showLegend': showLegend,
      'theme': theme,
      'animate': animate,
      'interactive': interactive,
    };
  }
}
