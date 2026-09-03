import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../editor_controller.dart';
import '../../modules/number_format/number_format_model.dart';
import '../../modules/number_format/number_format_dropdown.dart';

class HomeTab extends StatelessWidget {
  final String spreadsheetId;
  final Map<String, String> cellData;
  final Map<String, CellFormat> formatMap;
  final ValueChanged<Map<String, CellFormat>> onFormatMapChanged;

  const HomeTab({
    Key? key,
    required this.spreadsheetId,
    required this.cellData,
    required this.formatMap,
    required this.onFormatMapChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorController>(
      builder: (context, controller, _) {
        // Determine format of the primary selected cell
        final primary = controller.selectedCells.isNotEmpty
            ? controller.selectedCells.first
            : null;
        final currentFmt = primary != null
            ? (formatMap['${primary.row}:${primary.column}'] ?? CellFormat.general)
            : CellFormat.general;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Number Format Group ─────────────────────────────────────
              _RibbonGroup(
                label: 'NUMBER FORMAT',
                child: NumberFormatDropdown(
                  currentFormat: currentFmt,
                  onFormatChanged: (fmt) {
                    _applyFormat(context, controller, fmt);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyFormat(
    BuildContext context,
    EditorController controller,
    CellFormat fmt,
  ) {
    final selected = controller.selectedCells;
    final fullCol = controller.selectedFullColumn;
    final fullRow = controller.selectedFullRow;
    
    if (selected.isEmpty && fullCol == null && fullRow == null) return;

    final newMap = Map<String, CellFormat>.from(formatMap);

    if (fullCol != null) {
      for (final key in cellData.keys) {
        final parts = key.split(':');
        if (parts.length == 2 && int.tryParse(parts[1]) == fullCol) {
          if (fmt == CellFormat.general) {
            newMap.remove(key);
          } else {
            newMap[key] = fmt;
          }
        }
      }
    } else if (fullRow != null) {
      for (final key in cellData.keys) {
        final parts = key.split(':');
        if (parts.length == 2 && int.tryParse(parts[0]) == fullRow) {
          if (fmt == CellFormat.general) {
            newMap.remove(key);
          } else {
            newMap[key] = fmt;
          }
        }
      }
    } else {
      for (final cell in selected) {
        final key = '${cell.row}:${cell.column}';
        if (fmt == CellFormat.general) {
          newMap.remove(key);
        } else {
          newMap[key] = fmt;
        }
      }
    }
    
    onFormatMapChanged(newMap);
  }
}

// ── Ribbon Group Container ─────────────────────────────────────────────────

class _RibbonGroup extends StatelessWidget {
  final String label;
  final Widget child;
  const _RibbonGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        child,
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8A8886),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
