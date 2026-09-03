import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../domain/analytics/models/chart_config.dart';
import '../../../domain/analytics/registry/chart_renderer_registry.dart';

// ─────────────────────────────────────────────
// Plugin Registration
// ─────────────────────────────────────────────

class BarRenderer implements ChartPlugin {
  @override
  String get pluginId => 'fl_chart_bar_plugin';

  @override
  List<ChartType> get supportedTypes => [ChartType.bar, ChartType.column];

  @override
  bool get supportsAnimation => true;

  @override
  bool get supports3D => false;

  @override
  Widget render(ChartConfig config) {
    if (config.data.isEmpty) {
      return const _EmptyState(message: 'No data available');
    }
    if (config.series.isEmpty) {
      return const _EmptyState(message: 'No series configured');
    }
    return _BarChartWidget(config: config);
  }
}

// ─────────────────────────────────────────────
// Color Palette
// ─────────────────────────────────────────────

const List<Color> _kSeriesColors = [
  Color(0xFF2196F3), // Blue
  Color(0xFFFF5722), // Deep Orange
  Color(0xFF4CAF50), // Green
  Color(0xFF9C27B0), // Purple
  Color(0xFFFF9800), // Orange
  Color(0xFF00BCD4), // Cyan
  Color(0xFFE91E63), // Pink
  Color(0xFF795548), // Brown
];

Color _seriesColor(int index) =>
    _kSeriesColors[index % _kSeriesColors.length];

// ─────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────

class _BarChartWidget extends StatefulWidget {
  final ChartConfig config;

  const _BarChartWidget({required this.config});

  @override
  State<_BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<_BarChartWidget> {
  int? _touchedGroupIndex;
  int? _touchedRodIndex;

  // ChartType.bar  → horizontal  (bars go left-right)
  // ChartType.column → vertical (default)
  bool get _isHorizontal => widget.config.chartType == ChartType.bar;

  // ── Helpers ────────────────────────────────

  /// Pick a "nice" grid interval so there are ~5 lines
  double _niceInterval(double min, double max) {
    final range = max - min;
    if (range <= 0) return 1;
    final raw = range / 5;
    const candidates = [
      1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500,
      1000, 2000, 5000, 10000, 20000, 50000, 100000,
    ];
    for (final c in candidates) {
      if (raw <= c) return c.toDouble();
    }
    return raw.ceilToDouble();
  }

  /// Compact number display: 1,500 → 1.5K, 2,000,000 → 2M
  String _formatNumber(double val) {
    if (val.abs() >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    }
    if (val.abs() >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config  = widget.config;
    final series  = config.series;   // e.g. ['Revenue', 'Profit']
    final data    = config.data;
    final axisKey = config.axis;     // label column key

    // ── Compute min / max across ALL series ──
    double maxVal = double.negativeInfinity;
    double minVal = double.infinity;

    for (final row in data) {
      for (final s in series) {
        final v = (row[s] as num?)?.toDouble() ?? 0.0;
        if (v > maxVal) maxVal = v;
        if (v < minVal) minVal = v;
      }
    }

    // Fallback if all values are zero
    if (maxVal == double.negativeInfinity) maxVal = 0;
    if (minVal == double.infinity)         minVal = 0;

    final allZero  = maxVal == 0 && minVal == 0;
    final yMax     = maxVal <= 0 ? 1.0 : maxVal * 1.15;
    final yMin     = minVal >= 0 ? 0.0 : minVal * 1.15;
    final interval = _niceInterval(yMin, yMax);

    // ── Bar Groups ──────────────────────────
    final barGroups = <BarChartGroupData>[];

    for (int xi = 0; xi < data.length; xi++) {
      final row  = data[xi];
      final rods = <BarChartRodData>[];

      for (int si = 0; si < series.length; si++) {
        final yVal    = (row[series[si]] as num?)?.toDouble() ?? 0.0;
        final color   = _seriesColor(si);
        final touched = _touchedGroupIndex == xi && _touchedRodIndex == si;

        rods.add(BarChartRodData(
          toY:    yVal,
          fromY:  minVal < 0 ? 0.0 : null, // baseline for negatives
          color:  touched ? color.withValues(alpha: 0.65) : color,
          width:  series.length == 1 ? 20 : 12,
          borderRadius: const BorderRadius.only(
            topLeft:  Radius.circular(4),
            topRight: Radius.circular(4),
          ),
          // Faint background rod
          backDrawRodData: BackgroundBarChartRodData(
            show:  true,
            toY:   maxVal <= 0 ? 1 : maxVal,
            color: Colors.grey.withValues(alpha: 0.06),
          ),
        ));
      }

      barGroups.add(BarChartGroupData(
        x:         xi,
        barRods:   rods,
        barsSpace: series.length > 1 ? 4 : 0,
        showingTooltipIndicators: _touchedGroupIndex == xi
            ? List.generate(series.length, (i) => i)
            : [],
      ));
    }

    // ── fl_chart ────────────────────────────
    final chart = BarChart(
      BarChartData(
        alignment:  BarChartAlignment.spaceAround,
        maxY:       yMax,
        minY:       yMin,
        borderData: FlBorderData(
          show:   true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
            left:   BorderSide(color: Colors.grey.shade300),
          ),
        ),
        gridData: FlGridData(
          show:             true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

          // Y-axis (left)
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: 52,
              interval:     interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  _formatNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),

          // X-axis (bottom) — label column
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles:   true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final label = data[idx][axisKey]?.toString() ?? '';
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: barGroups,

        // ── Touch / Tooltip ─────────────────
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor:  (_) => const Color(0xFF1C1C2E),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label      = data[groupIndex][axisKey]?.toString() ?? '';
              final seriesName = series[rodIndex];
              final value      = _formatNumber(rod.toY);
              return BarTooltipItem(
                '$label\n',
                const TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize:   12,
                ),
                children: [
                  TextSpan(
                    text: '$seriesName: $value',
                    style: TextStyle(
                      color:  _seriesColor(rodIndex).withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
          touchCallback: (event, response) {
            setState(() {
              // Hide tooltip on lift / pointer exit
              if (response == null ||
                  response.spot == null ||
                  event is FlTapUpEvent ||
                  event is FlPointerExitEvent) {
                _touchedGroupIndex = null;
                _touchedRodIndex   = null;
              } else {
                _touchedGroupIndex = response.spot!.touchedBarGroupIndex;
                _touchedRodIndex   = response.spot!.touchedRodDataIndex;
              }
            });
          },
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 400),
      swapAnimationCurve:    Curves.easeInOut,
    );

    // ── Layout ───────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legend — only when multiple series
        if (series.length > 1) _buildLegend(series),

        // Chart body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              right: 16, top: 8, bottom: 4, left: 4,
            ),
            child: _isHorizontal
                ? RotatedBox(quarterTurns: 3, child: chart)
                : chart,
          ),
        ),

        // Zero-value notice
        if (allZero)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                'All values are zero',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ── Legend ───────────────────────────────────

  Widget _buildLegend(List<String> series) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Wrap(
        spacing:    16,
        runSpacing: 4,
        children: List.generate(series.length, (i) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width:  12,
                height: 12,
                decoration: BoxDecoration(
                  color:        _seriesColor(i),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                series[i],
                style: const TextStyle(
                  fontSize: 11, color: Colors.black87,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty State Helper
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}