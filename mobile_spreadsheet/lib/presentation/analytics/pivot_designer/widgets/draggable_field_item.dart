import 'package:flutter/material.dart';

class DraggableFieldItem extends StatelessWidget {
  final String fieldName;

  const DraggableFieldItem({super.key, required this.fieldName});

  IconData _ico(String n) {
    final l = n.toLowerCase();
    if (l.contains('date') || l.contains('time')) return Icons.calendar_today_outlined;
    if (l.contains('sales') || l.contains('qty') || l.contains('quantity') || l.contains('amount') || l.contains('price') || l.contains('total')) return Icons.tag;
    return Icons.text_fields_outlined;
  }

  Color _clr(String n) {
    final l = n.toLowerCase();
    if (l.contains('date') || l.contains('time')) return const Color(0xFF1565C0);
    if (l.contains('sales') || l.contains('qty') || l.contains('quantity') || l.contains('amount') || l.contains('price') || l.contains('total')) return const Color(0xFF2E7D32);
    return const Color(0xFF5D4037);
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<String>(
      data: fieldName,
      feedback: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFF2E7D32), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_ico(fieldName), size: 10, color: const Color(0xFF2E7D32)),
              const SizedBox(width: 4),
              Text(fieldName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none, color: Colors.black87)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _item()),
      child: _item(),
    );
  }

  Widget _item() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 11, color: Colors.grey.shade400),
          const SizedBox(width: 5),
          Expanded(
            child: Text(fieldName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
          ),
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: _clr(fieldName).withOpacity(0.08),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Icon(_ico(fieldName), size: 10, color: _clr(fieldName)),
          ),
        ],
      ),
    );
  }
}
