import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/analytics/engines/analytics_engine.dart';
import '../../../domain/analytics/models/chart_config.dart';
import '../controllers/dashboard_controller.dart';
import 'dockable_chart_card.dart';

/// Overlays the spreadsheet grid. Listens to AnalyticsEngine for new charts.
class FloatingDashboardManager extends StatefulWidget {
  const FloatingDashboardManager({Key? key}) : super(key: key);

  @override
  State<FloatingDashboardManager> createState() => _FloatingDashboardManagerState();
}

class _FloatingDashboardManagerState extends State<FloatingDashboardManager> {
  final DashboardController _controller = DashboardController();
  late StreamSubscription<ChartConfig> _chartSubscription;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    
    // Listen to new charts from the AI Agent or UI interactions
    _chartSubscription = AnalyticsEngine.instance.chartEngine.onNewChart.listen((config) {
      _controller.addChart(config);
    });
  }

  @override
  void dispose() {
    _chartSubscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.activeCharts.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: _controller.activeCharts.map((config) {
        return DockableChartCard(
          key: ValueKey(config.id),
          config: config,
          onClose: () => _controller.removeChart(config.id),
          onBringToFront: () => _controller.bringToFront(config.id),
        );
      }).toList(),
    );
  }
}
