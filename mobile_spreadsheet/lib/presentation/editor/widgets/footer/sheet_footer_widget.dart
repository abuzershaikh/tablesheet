import 'package:flutter/material.dart';
import '../../../../domain/entities/sheet_entity.dart';
import '../../../../domain/entities/theme/spreadsheet_theme_config.dart';
import '../../../../domain/services/super_engine/formula_utils.dart';
import '../../editor_controller.dart';

class SheetFooterWidget extends StatelessWidget {
  final SheetFooterConfig config;
  final SpreadsheetThemeConfig themeConfig;
  final Map<String, String> cellData;
  final List<int> visibleRows;
  final VoidCallback onTap;

  const SheetFooterWidget({
    Key? key,
    required this.config,
    required this.themeConfig,
    required this.cellData,
    required this.visibleRows,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!config.enabled) {
      return const SizedBox.shrink();
    }

    final targetCol = config.targetColumnIndex ?? 0;
    final colLetter = EditorController.getColumnLetter(targetCol);

    final calculatedValue = FooterEvaluator.evaluate(
      cellData: cellData,
      visibleRows: visibleRows,
      columnIndex: targetCol,
      calculationType: config.type,
    );

    // Apply custom colors if provided, else use theme colors
    final bgColor = config.backgroundColor != null 
        ? _colorFromHex(config.backgroundColor!) 
        : themeConfig.accentColor.withOpacity(0.1);
    final textColor = config.textColor != null 
        ? _colorFromHex(config.textColor!) 
        : themeConfig.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(color: themeConfig.borderColor),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForType(config.type),
                  size: 16,
                  color: textColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${config.label} (Col $colLetter)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            Text(
              calculatedValue.isEmpty ? '-' : calculatedValue,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'sum': return Icons.functions;
      case 'avg': return Icons.show_chart;
      case 'count': return Icons.numbers;
      case 'min': return Icons.vertical_align_bottom;
      case 'max': return Icons.vertical_align_top;
      default: return Icons.calculate;
    }
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
