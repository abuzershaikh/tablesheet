import 'package:flutter/material.dart';
import '../../../../domain/entities/sheet_entity.dart';
import 'sheet_tab_item.dart';

/// Sheet tabs widget at bottom of screen
class SheetTabsBar extends StatelessWidget {
  final List<SheetEntity> sheets;
  final int selectedIndex;
  final Function(int) onSheetSelected;
  final VoidCallback onAddSheet;
  final Function(int, String) onRenameSheet;

  const SheetTabsBar({
    Key? key,
    required this.sheets,
    required this.selectedIndex,
    required this.onSheetSelected,
    required this.onAddSheet,
    required this.onRenameSheet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36, // Thin slidebar
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Add sheet button (small and minimal)
          InkWell(
            onTap: onAddSheet,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 18, color: Colors.black54),
            ),
          ),
          
          // Divider
          Container(width: 1, height: 20, color: Colors.grey[400]),

          // Horizontal scrollable tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sheets.length,
              itemBuilder: (context, index) {
                return SheetTabItem(
                  sheet: sheets[index],
                  isSelected: index == selectedIndex,
                  onTap: () => onSheetSelected(index),
                  onRename: (newName) => onRenameSheet(index, newName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
