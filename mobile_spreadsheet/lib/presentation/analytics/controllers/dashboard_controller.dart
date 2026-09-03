import 'package:flutter/material.dart';
import '../../../domain/analytics/models/chart_config.dart';

/// Manages multiple dockable charts on the screen.
class DashboardController extends ChangeNotifier {
  final List<ChartConfig> _activeCharts = [];

  List<ChartConfig> get activeCharts => List.unmodifiable(_activeCharts);

  void addChart(ChartConfig config) {
    // Avoid duplicates by ID
    if (!_activeCharts.any((c) => c.id == config.id)) {
      _activeCharts.add(config);
      notifyListeners();
    }
  }

  void removeChart(String id) {
    _activeCharts.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void bringToFront(String id) {
    final index = _activeCharts.indexWhere((c) => c.id == id);
    if (index != -1) {
      final chart = _activeCharts.removeAt(index);
      _activeCharts.add(chart);
      notifyListeners();
    }
  }

  void clearAll() {
    _activeCharts.clear();
    notifyListeners();
  }
}
