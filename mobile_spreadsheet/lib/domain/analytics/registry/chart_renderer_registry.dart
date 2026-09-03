import 'package:flutter/material.dart';
import '../models/chart_config.dart';

/// Base Plugin Interface for all chart implementations.
abstract class ChartPlugin {
  /// The specific name/id of the plugin (e.g., 'fl_chart_pie', 'native_pivot_table')
  String get pluginId;
  
  /// Types of charts this plugin can render
  List<ChartType> get supportedTypes;
  
  /// Capabilities
  bool get supportsAnimation;
  bool get supports3D;

  /// Render the chart
  Widget render(ChartConfig config);
}

/// Registry pattern to hold all chart plugins.
class ChartRendererRegistry {
  static final List<ChartPlugin> _plugins = [];

  static void registerPlugin(ChartPlugin plugin) {
    if (!_plugins.any((p) => p.pluginId == plugin.pluginId)) {
      _plugins.add(plugin);
    }
  }

  static Widget buildChart(ChartConfig config) {
    // Find the best plugin for this config
    try {
      final plugin = _plugins.firstWhere((p) {
        if (!p.supportedTypes.contains(config.chartType)) return false;
        if (config.animate && !p.supportsAnimation) return false;
        if (config.chartStyle == '3D' && !p.supports3D) return false;
        return true;
      });
      return plugin.render(config);
    } catch (_) {
      // Fallback if strict requirements not met
      try {
        final fallback = _plugins.firstWhere((p) => p.supportedTypes.contains(config.chartType));
        return fallback.render(config);
      } catch (_) {
        return Center(
          child: Text('No plugin found for ${config.chartType.name}'),
        );
      }
    }
  }
}
