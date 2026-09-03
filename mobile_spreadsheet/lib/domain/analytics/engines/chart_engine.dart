import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chart_config.dart';
import '../../services/super_engine/ffi_bridge.dart';

/// Responsible for preparing chart data and broadcasting it to the Presentation layer.
class ChartEngine {
  // Streams are better than ValueNotifier for handling multiple charts dynamically.
  // We use a StreamController to push new charts to the Dashboard Controller.
  final _chartStreamController = StreamController<ChartConfig>.broadcast();

  Stream<ChartConfig> get onNewChart => _chartStreamController.stream;

  void broadcastChart(ChartConfig config) async {
    debugPrint("[ChartEngine] Broadcasting new chart: ${config.id}");
    
    // If the data is empty but we have series and axis, fetch from C++ Downsampling Engine
    if (config.data.isEmpty && config.series.isNotEmpty && config.axis.isNotEmpty) {
      final reqJson = jsonEncode({
        "xField": config.axis,
        "yField": config.series.first,
        "maxPoints": 500
      });
      
      final resultStr = await compute((String req) => NativeEngine.getChartData(req), reqJson);
      final resultJson = jsonDecode(resultStr);
      
      if (resultJson['error'] == null) {
        final List<dynamic> points = resultJson['data'] ?? [];
        final List<Map<String, dynamic>> finalData = points.map((p) => {
          config.axis: p['x'],
          config.series.first: p['y']
        }).toList();
        
        // Rebuild config with data
        config = ChartConfig(
          id: config.id,
          title: config.title,
          subtitle: config.subtitle,
          chartType: config.chartType,
          series: config.series,
          axis: config.axis,
          data: finalData,
          showLegend: config.showLegend,
          theme: config.theme,
          animate: config.animate,
          interactive: config.interactive,
          animationDurationMs: config.animationDurationMs,
          themeColors: config.themeColors,
          chartStyle: config.chartStyle,
        );
      }
    }
    
    _chartStreamController.sink.add(config);
  }

  void dispose() {
    _chartStreamController.close();
  }
}
