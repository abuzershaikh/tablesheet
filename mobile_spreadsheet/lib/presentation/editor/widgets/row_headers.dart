import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/entities/theme/spreadsheet_theme_config.dart';

/// Row headers widget (1, 2, 3, ...)
/// Stays fixed vertically but syncs with grid scroll position
class RowHeaders extends StatelessWidget {
  final int rowCount;
  final double rowHeight;
  final double Function(int row)? getRowHeight;
  final ScrollController? gridScrollController;
  final Function(int)? onRowTap;
  final Function(int)? onRowLongPress;
  final VoidCallback? onAddRow;
  final List<int>? visibleRows;
  final SpreadsheetThemeConfig? themeConfig;
  final int frozenRows;

  const RowHeaders({
    Key? key,
    required this.rowCount,
    this.rowHeight = 40.0,
    this.getRowHeight,
    this.gridScrollController,
    this.onRowTap,
    this.onRowLongPress,
    this.onAddRow,
    this.visibleRows,
    this.themeConfig,
    this.frozenRows = 0,
  }) : super(key: key);

  double _getH(int r) => getRowHeight?.call(r) ?? rowHeight;

  @override
  Widget build(BuildContext context) {
    final cfg = themeConfig ?? SpreadsheetThemeConfig.defaultTheme;
    final rowBg = cfg.isHeaderOnly ? const Color(0xFFF5F5F5) : cfg.rowHeaderBgColor;

    final effectiveRowCount = visibleRows?.length ?? rowCount;
    double totalHeight = 0;
    for (int i = 0; i < effectiveRowCount; i++) {
      final r = visibleRows != null ? visibleRows![i] : i;
      totalHeight += _getH(r);
    }

    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          right: BorderSide(color: cfg.borderColor),
        ),
      ),
      child: AnimatedBuilder(
        animation: gridScrollController ?? const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          final offset = (gridScrollController?.hasClients ?? false)
              ? gridScrollController!.offset
              : 0.0;
          final addRowY = totalHeight - offset;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Painted row numbers
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final dy = details.localPosition.dy;
                  final scrollOffset = gridScrollController?.offset ?? 0;

                  double currentY = 0;
                  int matchedVisualRow = -1;
                  for (int i = 0; i < effectiveRowCount; i++) {
                    final actualRow = visibleRows != null ? visibleRows![i] : i;
                    final h = _getH(actualRow);
                    if (dy + scrollOffset >= currentY && dy + scrollOffset < currentY + h) {
                      matchedVisualRow = i;
                      break;
                    }
                    currentY += h;
                  }

                  if (matchedVisualRow >= 0 && matchedVisualRow < effectiveRowCount) {
                    final actualRow = visibleRows != null ? visibleRows![matchedVisualRow] : matchedVisualRow;
                    onRowTap?.call(actualRow);
                  }
                },
                onLongPressStart: (details) {
                  final dy = details.localPosition.dy;
                  final scrollOffset = gridScrollController?.offset ?? 0;

                  double currentY = 0;
                  int matchedVisualRow = -1;
                  for (int i = 0; i < effectiveRowCount; i++) {
                    final actualRow = visibleRows != null ? visibleRows![i] : i;
                    final h = _getH(actualRow);
                    if (dy + scrollOffset >= currentY && dy + scrollOffset < currentY + h) {
                      matchedVisualRow = i;
                      break;
                    }
                    currentY += h;
                  }

                  if (matchedVisualRow >= 0 && matchedVisualRow < effectiveRowCount) {
                    final actualRow = visibleRows != null ? visibleRows![matchedVisualRow] : matchedVisualRow;
                    onRowLongPress?.call(actualRow);
                  }
                },
                child: ClipRect(
                  child: CustomPaint(
                    painter: _RowHeadersPainter(
                      rowCount: visibleRows?.length ?? rowCount,
                      rowHeight: rowHeight,
                      getRowHeight: getRowHeight,
                      scrollController: gridScrollController,
                      visibleRows: visibleRows,
                      themeConfig: cfg,
                      frozenRows: frozenRows,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              // + Add Row button (positioned ONLY below the last row number)
              if (onAddRow != null)
                Positioned(
                  top: addRowY,
                  left: 0,
                  right: 0,
                  child: _AddRowButton(
                    onTap: onAddRow!,
                    accentColor: cfg.accentColor,
                    bgColor: rowBg,
                    borderColor: cfg.borderColor,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Beautiful + button with ripple for adding rows
class _AddRowButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;

  const _AddRowButton({
    required this.onTap,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: accentColor.withOpacity(0.3),
          highlightColor: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RowHeadersPainter extends CustomPainter {
  final int rowCount;
  final double rowHeight;
  final double Function(int row)? getRowHeight;
  final ScrollController? scrollController;
  final Function(int)? onRowTap;
  final List<int>? visibleRows;
  final SpreadsheetThemeConfig themeConfig;
  final int frozenRows;

  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  _RowHeadersPainter({
    required this.rowCount,
    required this.rowHeight,
    this.getRowHeight,
    required this.scrollController,
    this.visibleRows,
    this.onRowTap,
    required this.themeConfig,
    this.frozenRows = 0,
  }) : super(repaint: scrollController);

  double _getH(int r) => getRowHeight?.call(r) ?? rowHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final rowBg = themeConfig.isHeaderOnly ? const Color(0xFFF5F5F5) : themeConfig.rowHeaderBgColor;
    final rowText = themeConfig.isHeaderOnly ? const Color(0xFF212121) : themeConfig.rowHeaderTextColor;

    final borderPaint = Paint()
      ..color = themeConfig.borderColor
      ..strokeWidth = 1;
    final bgPaint = Paint()..color = rowBg;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final double scrollOffset = (scrollController != null && scrollController!.hasClients)
        ? scrollController!.offset
        : 0.0;

    double currentY = 0.0;
    
    // CRITICAL BUG FIX: Track rendered row numbers to prevent duplicates
    final Set<int> renderedRows = {};

    // ── PASS 1: Draw NON-frozen rows first ──
    for (int i = 0; i < rowCount; i++) {
      final actualRowIndex = visibleRows != null ? visibleRows![i] : i;
      
      if (renderedRows.contains(actualRowIndex)) continue;
      
      final h = _getH(actualRowIndex);
      final isFrozen = i < frozenRows;

      if (!isFrozen) {
        final y = currentY - scrollOffset;
        if (y + h >= -h && y <= size.height + h) {
          // Draw bottom border
          canvas.drawLine(
            Offset(0, y + h),
            Offset(size.width, y + h),
            borderPaint,
          );

          // Draw row number
          _textPainter.text = TextSpan(
            text: '${actualRowIndex + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: rowText,
            ),
          );
          _textPainter.layout();
          _textPainter.paint(
            canvas,
            Offset(
              (size.width - _textPainter.width) / 2,
              y + (h - _textPainter.height) / 2,
            ),
          );
          renderedRows.add(actualRowIndex);
        }
      }

      currentY += h;
      if (currentY - scrollOffset > size.height + 1000) break;
    }

    // ── PASS 2: Draw FROZEN rows ON TOP with solid background ──
    if (frozenRows > 0) {
      double frozenY = 0.0;
      for (int i = 0; i < frozenRows && i < rowCount; i++) {
        final actualRowIndex = visibleRows != null ? visibleRows![i] : i;
        final h = _getH(actualRowIndex);

        // Solid background to cover scrolling rows underneath
        final bgPaint = Paint()..color = rowBg;
        canvas.drawRect(Rect.fromLTWH(0, frozenY, size.width, h), bgPaint);

        // Accent freeze line at bottom of frozen area
        final freezePaint = Paint()
          ..color = themeConfig.accentColor
          ..strokeWidth = 2.5;
        canvas.drawLine(
          Offset(0, frozenY + h),
          Offset(size.width, frozenY + h),
          freezePaint,
        );

        // Draw row number in accent color
        _textPainter.text = TextSpan(
          text: '${actualRowIndex + 1}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: themeConfig.accentColor,
          ),
        );
        _textPainter.layout();
        _textPainter.paint(
          canvas,
          Offset(
            (size.width - _textPainter.width) / 2,
            frozenY + (h - _textPainter.height) / 2,
          ),
        );

        frozenY += h;
      }
    }
  }

  @override
  bool shouldRepaint(_RowHeadersPainter oldDelegate) {
    return true;
  }
}