import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../domain/analytics/models/chart_config.dart';
import '../../../domain/analytics/registry/chart_renderer_registry.dart';

// ─────────────────────────────────────────────
// Plugin Registration
// ─────────────────────────────────────────────

class PieRenderer implements ChartPlugin {
  @override
  String get pluginId => 'fl_chart_pie_plugin';

  @override
  List<ChartType> get supportedTypes => [ChartType.pie, ChartType.donut];

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
    return _PieChartWidget(config: config);
  }
}

// ─────────────────────────────────────────────
// Color Palette
// ─────────────────────────────────────────────

const List<Color> _kSliceColors = [
  Color(0xFF2196F3), // Blue
  Color(0xFFFF5722), // Deep Orange
  Color(0xFF4CAF50), // Green
  Color(0xFF9C27B0), // Purple
  Color(0xFFFF9800), // Orange
  Color(0xFF00BCD4), // Cyan
  Color(0xFFE91E63), // Pink
  Color(0xFF795548), // Brown
  Color(0xFF607D8B), // Blue Grey
  Color(0xFFCDDC39), // Lime
];

Color _sliceColor(int index, List<Color> themeColors) {
  if (themeColors.isNotEmpty) {
    return themeColors[index % themeColors.length];
  }
  return _kSliceColors[index % _kSliceColors.length];
}

// ─────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────

class _PieChartWidget extends StatefulWidget {
  final ChartConfig config;

  const _PieChartWidget({required this.config});

  @override
  State<_PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<_PieChartWidget> {
  int _touchedIndex = -1;

  // ChartType.donut → center hole visible
  bool get _isDonut => widget.config.chartType == ChartType.donut;

  // ── Helpers ────────────────────────────────

  /// Compact number formatter
  String _formatNumber(double val) {
    if (val.abs() >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val.abs() >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  /// Percentage string: 2 decimal places
  String _formatPercent(double value, double total) {
    if (total <= 0) return '0%';
    return '${(value / total * 100).toStringAsFixed(1)}%';
  }

  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config    = widget.config;
    final data      = config.data;
    final axisKey   = config.axis;
    final valueKey  = config.series.first;

    // ── Filter negative/zero values ──────────
    final validData = data.where((row) {
      final v = (row[valueKey] as num?)?.toDouble() ?? 0.0;
      return v > 0;
    }).toList();

    if (validData.isEmpty) {
      return const _EmptyState(message: 'No positive values to display');
    }

    // ── Theme colors (safe) ──────────────────
    final themeColors = (config.themeColors ?? [])
        .whereType<Color>()
        .toList();

    // ── Total for percentage ─────────────────
    final total = validData.fold<double>(
      0,
      (sum, row) => sum + ((row[valueKey] as num?)?.toDouble() ?? 0.0),
    );

    // ── Pie Sections ─────────────────────────
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < validData.length; i++) {
      final row       = validData[i];
      final yVal      = (row[valueKey] as num?)?.toDouble() ?? 0.0;
      final label     = row[axisKey]?.toString() ?? '';
      final color     = _sliceColor(i, themeColors);
      final isTouched = i == _touchedIndex;
      final percent   = _formatPercent(yVal, total);

      // Only show title if slice is large enough (> 5%)
      final slicePercent = total > 0 ? (yVal / total * 100) : 0;
      final showTitle = slicePercent > 5;

      sections.add(PieChartSectionData(
        value:  yVal,
        color:  isTouched ? color : color.withValues(alpha: 0.85),
        radius: isTouched ? 80 : 65,

        // Title inside slice
        title: showTitle ? percent : '',
        titleStyle: const TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.bold,
          color:      Colors.white,
          shadows:    [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
        titlePositionPercentageOffset: 0.65,

        // Badge (label chip outside slice) for large slices
        badgeWidget: isTouched
            ? _TooltipBadge(
                label: label,
                value: _formatNumber(yVal),
                percent: percent,
                color: color,
              )
            : null,
        badgePositionPercentageOffset: 1.3,
      ));
    }

    // ── Center Label (donut only) ────────────
    final centerContent = _isDonut
        ? _buildCenterLabel(
            _touchedIndex >= 0 && _touchedIndex < validData.length
                ? validData[_touchedIndex]
                : null,
            valueKey,
            axisKey,
            total,
          )
        : null;

    return LayoutBuilder(builder: (context, constraints) {
      final size     = constraints.biggest;
      final minSide  = size.shortestSide.clamp(80.0, 400.0);
      final isNarrow = size.width < 400;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Chart + Legend row ──────────────
          Expanded(
            child: isNarrow
                ? Column(children: [
                    Expanded(child: _buildChart(sections, centerContent, minSide)),
                    _buildLegend(validData, axisKey, valueKey, themeColors, total, isColumn: true),
                  ])
                : Row(children: [
                    Expanded(child: _buildChart(sections, centerContent, minSide)),
                    _buildLegend(validData, axisKey, valueKey, themeColors, total, isColumn: false),
                  ]),
          ),
        ],
      );
    });
  }

  // ── Chart ─────────────────────────────────

  Widget _buildChart(
    List<PieChartSectionData> sections,
    Widget? centerContent,
    double minSide,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections:          sections,
            centerSpaceRadius: _isDonut ? minSide * 0.18 : 0,
            sectionsSpace:     2,
            startDegreeOffset: -90, // Start from top
            pieTouchData: PieTouchData(
              enabled: true,
              touchCallback: (event, response) {
                setState(() {
                  if (response == null ||
                      response.touchedSection == null ||
                      event is FlTapUpEvent ||
                      event is FlPointerExitEvent) {
                    _touchedIndex = -1;
                  } else {
                    _touchedIndex =
                        response.touchedSection!.touchedSectionIndex;
                  }
                });
              },
            ),
          ),
          swapAnimationDuration: Duration(
            milliseconds: widget.config.animate
                ? (widget.config.animationDurationMs ?? 400)
                : 0,
          ),
          swapAnimationCurve: Curves.easeInOut,
        ),

        // Center label (donut mode)
        if (_isDonut && centerContent != null) centerContent,
      ],
    );
  }

  // ── Center Label ──────────────────────────

  Widget _buildCenterLabel(
    Map<String, dynamic>? row,
    String valueKey,
    String axisKey,
    double total,
  ) {
    if (row == null) {
      // No slice selected → show total
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatNumber(total),
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.bold,
              color:      Colors.black87,
            ),
          ),
          const Text(
            'Total',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      );
    }

    final val     = (row[valueKey] as num?)?.toDouble() ?? 0.0;
    final label   = row[axisKey]?.toString() ?? '';
    final percent = _formatPercent(val, total);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          percent,
          style: const TextStyle(
            fontSize:   18,
            fontWeight: FontWeight.bold,
            color:      Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          _formatNumber(val),
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  // ── Legend ────────────────────────────────

  Widget _buildLegend(
    List<Map<String, dynamic>> data,
    String axisKey,
    String valueKey,
    List<Color> themeColors,
    double total, {
    required bool isColumn,
  }) {
    final total_ = total;

    final items = List.generate(data.length, (i) {
      final row     = data[i];
      final label   = row[axisKey]?.toString() ?? '';
      final val     = (row[valueKey] as num?)?.toDouble() ?? 0.0;
      final color   = _sliceColor(i, themeColors);
      final percent = _formatPercent(val, total_);
      final isSel   = i == _touchedIndex;

      return GestureDetector(
        onTap: () => setState(() {
          _touchedIndex = isSel ? -1 : i;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin:  const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color:        isSel ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(
              color: isSel ? color : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width:  isSel ? 14 : 10,
                height: isSel ? 14 : 10,
                decoration: BoxDecoration(
                  color:  color,
                  shape:  BoxShape.circle,
                  boxShadow: isSel
                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                      : [],
                ),
              ),
              const SizedBox(width: 6),
              // Label + percent
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color:      Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '$percent  •  ${_formatNumber(val)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });

    if (isColumn) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: items),
      );
    }

    return SizedBox(
      width: 160,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tooltip Badge (shown on touched slice)
// ─────────────────────────────────────────────

class _TooltipBadge extends StatelessWidget {
  final String label;
  final String value;
  final String percent;
  final Color  color;

  const _TooltipBadge({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color:        const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(8),
        boxShadow:    const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value  ($percent)',
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
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
          Icon(Icons.pie_chart_outline, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}