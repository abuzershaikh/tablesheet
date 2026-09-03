import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/entities/theme/spreadsheet_theme_config.dart';

/// Column headers widget (A, B, C, ...)
/// Stays fixed horizontally but syncs with grid scroll position
class ColumnHeaders extends StatefulWidget {
  final int columnCount;
  final double Function(int) getColumnWidth;
  final String? Function(int)? getColumnName;
  final ScrollController? gridScrollController;
  final Function(int columnIndex)? onColumnTap;
  final Function(int columnIndex)? onColumnLongPress;
  final Function(int columnIndex)? onColumnDoubleTap;
  final VoidCallback? onAddColumn;
  final SpreadsheetThemeConfig? themeConfig;

  // Callbacks for Swipe & Reorder
  final Function(int columnIndex)? onSwipeLeft;
  final Function(int columnIndex)? onSwipeRight;
  final Function(int oldIndex, int newIndex)? onReorder;
  final String Function(int row, int col)? getCellValue;

  final int frozenColumns;

  const ColumnHeaders({
    Key? key,
    this.columnCount = 26,
    required this.getColumnWidth,
    required this.getColumnName,
    this.gridScrollController,
    this.onColumnTap,
    this.onColumnLongPress,
    this.onColumnDoubleTap,
    this.onAddColumn,
    this.themeConfig,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onReorder,
    this.getCellValue,
    this.frozenColumns = 0,
  }) : super(key: key);

  @override
  State<ColumnHeaders> createState() => _ColumnHeadersState();
}

class _ColumnHeadersState extends State<ColumnHeaders> {
  Timer? _autoScrollTimer;

  void _startAutoScrollIfNeeded(double globalDx) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double edgeThreshold = 60.0;
    final scrollController = widget.gridScrollController;

    if (scrollController == null || !scrollController.hasClients) return;

    if (globalDx > screenWidth - edgeThreshold) {
      // Near right edge -> Scroll Right slowly
      _autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (!scrollController.hasClients) return;
        final maxScroll = scrollController.position.maxScrollExtent;
        final newOffset = (scrollController.offset + 10.0).clamp(0.0, maxScroll);
        scrollController.jumpTo(newOffset);
      });
    } else if (globalDx < edgeThreshold + 50.0) {
      // Near left edge -> Scroll Left slowly
      _autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (!scrollController.hasClients) return;
        final newOffset = (scrollController.offset - 10.0).clamp(0.0, double.infinity);
        scrollController.jumpTo(newOffset);
      });
    } else {
      _stopAutoScroll();
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.themeConfig ?? SpreadsheetThemeConfig.defaultTheme;

    double totalWidth = 0;
    for (int i = 0; i < widget.columnCount; i++) {
      totalWidth += widget.getColumnWidth(i);
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: cfg.headerBgColor,
        border: Border(
          bottom: BorderSide(color: cfg.borderColor),
        ),
      ),
      child: Row(
        children: [
          // Corner cell (fixed)
          Container(
            width: 50,
            decoration: BoxDecoration(
              color: cfg.headerBgColor,
              border: Border(
                right: BorderSide(color: cfg.borderColor),
              ),
            ),
          ),
          
          // Column headers (synced with grid)
          Expanded(
            child: AnimatedBuilder(
              animation: widget.gridScrollController ?? const AlwaysStoppedAnimation(0),
              builder: (context, child) {
                final offset = (widget.gridScrollController?.hasClients ?? false)
                    ? widget.gridScrollController!.offset
                    : 0.0;
                final addColX = totalWidth - offset;

                // Build children with manual culling
                final List<Widget> children = [];
                double currentX = 0;
                final screenWidth = MediaQuery.of(context).size.width;

                // PASS 1: Render NON-frozen column headers first
                for (int i = 0; i < widget.columnCount; i++) {
                  final width = widget.getColumnWidth(i);
                  final isFrozen = widget.frozenColumns > 0 && i < widget.frozenColumns;

                  if (!isFrozen) {
                    final left = currentX - offset;
                    if (left + width >= 0 && left <= screenWidth) {
                      final letter = widget.getColumnName?.call(i) ?? _getColumnLetter(i);
                      final displayText = letter.isNotEmpty ? letter : _getColumnLetter(i);
                      
                      children.add(
                        Positioned(
                          left: left,
                          width: width,
                          top: 0,
                          bottom: 0,
                          child: _ColumnHeaderCell(
                            index: i,
                            width: width,
                            text: displayText,
                            cfg: cfg,
                            getCellValue: widget.getCellValue,
                            onTap: () => widget.onColumnTap?.call(i),
                            onDoubleTapDots: () => widget.onColumnDoubleTap?.call(i),
                            onSwipeLeft: () => widget.onSwipeLeft?.call(i),
                            onSwipeRight: () => widget.onSwipeRight?.call(i),
                            onReorder: (oldIdx, newIdx) {
                              _stopAutoScroll();
                              widget.onReorder?.call(oldIdx, newIdx);
                            },
                            onDragUpdate: (dx) => _startAutoScrollIfNeeded(dx),
                            onDragEnd: () => _stopAutoScroll(),
                          ),
                        ),
                      );
                    }
                  }
                  currentX += width;
                }

                // PASS 2: Render FROZEN column headers ON TOP with solid background & aligned accent line
                if (widget.frozenColumns > 0) {
                  double frozenX = 0;
                  for (int i = 0; i < widget.frozenColumns && i < widget.columnCount; i++) {
                    final width = widget.getColumnWidth(i);
                    final letter = widget.getColumnName?.call(i) ?? _getColumnLetter(i);
                    final displayText = letter.isNotEmpty ? letter : _getColumnLetter(i);

                    children.add(
                      Positioned(
                        left: frozenX,
                        width: width,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          color: cfg.headerBgColor,
                          child: _ColumnHeaderCell(
                            index: i,
                            width: width,
                            text: displayText,
                            cfg: cfg,
                            getCellValue: widget.getCellValue,
                            onTap: () => widget.onColumnTap?.call(i),
                            onDoubleTapDots: () => widget.onColumnDoubleTap?.call(i),
                            onSwipeLeft: () => widget.onSwipeLeft?.call(i),
                            onSwipeRight: () => widget.onSwipeRight?.call(i),
                            onReorder: (oldIdx, newIdx) {
                              _stopAutoScroll();
                              widget.onReorder?.call(oldIdx, newIdx);
                            },
                            onDragUpdate: (dx) => _startAutoScrollIfNeeded(dx),
                            onDragEnd: () => _stopAutoScroll(),
                          ),
                        ),
                      ),
                    );

                    // Add centered 2.5px accent line at exact boundary match
                    if (i == widget.frozenColumns - 1) {
                      children.add(
                        Positioned(
                          left: frozenX + width - 1.25,
                          width: 2.5,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            color: cfg.accentColor,
                          ),
                        ),
                      );
                    }
                    frozenX += width;
                  }
                }

                // Add button at the end
                if (widget.onAddColumn != null) {
                  children.add(
                    Positioned(
                      left: addColX,
                      top: 0,
                      bottom: 0,
                      child: _AddColumnButton(
                        onTap: widget.onAddColumn!,
                        accentColor: cfg.accentColor,
                        bgColor: cfg.headerBgColor,
                        borderColor: cfg.borderColor,
                      ),
                    ),
                  );
                }

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: children,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getColumnLetter(int index) {
    if (index < 0) return '';
    String letter = '';
    int position = index;
    
    while (position >= 0) {
      letter = String.fromCharCode(65 + (position % 26)) + letter;
      position = (position ~/ 26) - 1;
    }
    return letter;
  }
}

class _ColumnHeaderCell extends StatelessWidget {
  final int index;
  final double width;
  final String text;
  final SpreadsheetThemeConfig cfg;
  final String Function(int row, int col)? getCellValue;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTapDots;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final Function(int oldIndex, int newIndex)? onReorder;
  final Function(double globalDx)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const _ColumnHeaderCell({
    required this.index,
    required this.width,
    required this.text,
    required this.cfg,
    this.getCellValue,
    required this.onTap,
    this.onDoubleTapDots,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onReorder,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    // Basic Cell Appearance
    Widget buildHeaderContent({bool isCandidate = false}) {
      return Container(
        decoration: BoxDecoration(
          color: cfg.headerBgColor,
          border: Border(
            right: BorderSide(color: cfg.borderColor, width: 1),
            top: isCandidate ? BorderSide(color: cfg.accentColor, width: 2) : BorderSide.none,
            bottom: isCandidate ? BorderSide(color: cfg.accentColor, width: 2) : BorderSide.none,
            left: isCandidate ? BorderSide(color: cfg.accentColor, width: 2) : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Column Name / Letter
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: cfg.headerTextColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            
            // 6-Dots Icon (Tap / Double Tap -> Settings, Long Press Drag -> Reorder)
            LongPressDraggable<int>(
              data: index,
              onDragUpdate: (details) {
                onDragUpdate?.call(details.globalPosition.dx);
              },
              onDragEnd: (_) {
                onDragEnd?.call();
              },
              onDraggableCanceled: (_, __) {
                onDragEnd?.call();
              },
              feedback: Material(
                elevation: 16,
                shadowColor: cfg.accentColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: width,
                    height: 220, // Fixed: 40px header + 5 × 36px rows = 220px
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Badge (40px)
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: cfg.accentColor,
                            border: Border.all(color: cfg.accentColor, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.drag_indicator,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                        
                        // 5 Empty Rows (each 36px) — no text, no overflow
                        ...List.generate(5, (i) => Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: i % 2 == 0
                                ? Colors.white
                                : const Color(0xFFF5F5F5),
                            border: Border(
                              left: BorderSide(color: cfg.accentColor, width: 2),
                              right: BorderSide(color: cfg.accentColor, width: 2),
                              bottom: BorderSide(color: cfg.borderColor.withOpacity(0.4), width: 1),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: cfg.accentColor,
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDoubleTapDots,
                  onDoubleTap: onDoubleTapDots,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                    child: Icon(
                      Icons.drag_indicator, // Bold 6-dots icon
                      size: 20,
                      color: const Color(0xFF1E3A8A), // Vibrant Navy Blue
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DragTarget<int>(
      onAcceptWithDetails: (details) {
        final draggedIndex = details.data;
        if (draggedIndex != index && onReorder != null) {
          onReorder!(draggedIndex, index);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isCandidate = candidateData.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // Long press on header opens Swipe Quick Action menu!
          onLongPress: () {
            onSwipeLeft?.call();
          },
          // Horizontal swipe left/right opens Quick Action menu!
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < -150) {
              // Swipe Left -> Quick Actions
              onSwipeLeft?.call();
            } else if (details.primaryVelocity! > 150) {
              // Swipe Right -> Quick Actions
              onSwipeRight?.call();
            }
          },
          child: buildHeaderContent(isCandidate: isCandidate),
        );
      },
    );
  }
}

/// Beautiful + button with ripple for adding columns
class _AddColumnButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;

  const _AddColumnButton({
    required this.onTap,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
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
