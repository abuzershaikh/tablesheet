import 'package:flutter/material.dart';
import '../../../../domain/entities/sheet_entity.dart';

class SheetTabItem extends StatelessWidget {
  final SheetEntity sheet;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(String) onRename;

  const SheetTabItem({
    Key? key,
    required this.sheet,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
  }) : super(key: key);

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: sheet.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Sheet', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Enter new sheet name',
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                onRename(value);
              }
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onRename(controller.text);
                }
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: () => _showRenameDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
            right: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Center(
          child: Text(
            sheet.name,
            style: TextStyle(
              fontSize: 12, // Small beautiful style
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.black : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
