import 'package:flutter/material.dart';
import '../../../domain/entities/template_entity.dart';

class TemplateCard extends StatelessWidget {
  final SheetTemplate template;
  final VoidCallback onUse;

  const TemplateCard({
    super.key,
    required this.template,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUse,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: template.iconColor.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: template.iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      template.icon,
                      color: template.iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${template.columnCount} columns',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  template.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Column type chips preview
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _buildColumnChips(),
              ),
            ),

            // Use button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: onUse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: template.iconColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Use Template'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildColumnChips() {
    final types = template.columns
        .map((c) => c.typeId)
        .toSet()
        .take(4)
        .toList();

    return types.map((type) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _getTypeColor(type).withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          type,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: _getTypeColor(type),
          ),
        ),
      );
    }).toList();
  }

  Color _getTypeColor(String typeId) {
    switch (typeId) {
      case 'text':
        return const Color(0xFF5B6B7F);
      case 'number':
        return const Color(0xFF2196F3);
      case 'amount':
        return const Color(0xFF4CAF50);
      case 'date':
        return const Color(0xFFFF9800);
      case 'time':
        return const Color(0xFF9C27B0);
      case 'checkbox':
        return const Color(0xFF009688);
      case 'selectable':
        return const Color(0xFFE91E63);
      case 'image':
        return const Color(0xFF795548);
      case 'phone':
        return const Color(0xFF3F51B5);
      case 'link':
        return const Color(0xFF00BCD4);
      case 'address':
        return const Color(0xFF607D8B);
      case 'location':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF757575);
    }
  }
}
