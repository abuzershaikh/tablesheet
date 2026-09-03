import 'package:flutter/material.dart';
import '../../../../domain/entities/column_types/base/column_type.dart';

/// Clean Solid Column Type Selector with distinct solid colors for each type
class ColumnTypeSelector extends StatelessWidget {
  final List<ColumnType> availableTypes;
  final ColumnType selectedType;
  final ValueChanged<ColumnType> onTypeSelected;

  const ColumnTypeSelector({
    Key? key,
    required this.availableTypes,
    required this.selectedType,
    required this.onTypeSelected,
  }) : super(key: key);

  static Color getSolidColor(String typeId) {
    switch (typeId) {
      case 'text':
        return const Color(0xFF1E88E5); // Solid Blue
      case 'number':
        return const Color(0xFF00ACC1); // Solid Cyan
      case 'amount':
        return const Color(0xFF2E7D32); // Solid Dark Green
      case 'date':
        return const Color(0xFFF57C00); // Solid Orange
      case 'time':
        return const Color(0xFFFF8F00); // Solid Amber
      case 'checkbox':
        return const Color(0xFF00897B); // Solid Teal
      case 'selectable':
        return const Color(0xFF6A1B9A); // Solid Deep Purple
      case 'image':
        return const Color(0xFFD81B60); // Solid Pink
      case 'audio':
        return const Color(0xFF512DA8); // Solid Indigo
      case 'pdf':
        return const Color(0xFFD32F2F); // Solid Red
      case 'phone':
        return const Color(0xFF558B2F); // Solid Light Green
      case 'link':
        return const Color(0xFF1565C0); // Solid Royal Blue
      case 'address':
        return const Color(0xFF4E342E); // Solid Brown
      case 'location':
        return const Color(0xFFE64A19); // Solid Deep Orange
      default:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: availableTypes.length,
        itemBuilder: (context, index) {
          final type = availableTypes[index];
          final isSelected = type.id == selectedType.id;
          final solidColor = getSolidColor(type.id);

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onTypeSelected(type),
              child: Container(
                width: 76,
                decoration: BoxDecoration(
                  color: isSelected ? solidColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? solidColor : const Color(0xFFE0E0E0),
                    width: isSelected ? 2.5 : 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Solid Color Icon Circle
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : solidColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        type.icon,
                        size: 22,
                        color: isSelected ? solidColor : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF424242),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
