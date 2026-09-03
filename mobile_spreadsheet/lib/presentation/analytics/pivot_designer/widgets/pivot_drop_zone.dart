import 'package:flutter/material.dart';

class PivotDropZone extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Function(String) onAccept;
  final Function(String) onRemove;
  final String? subtitle;

  const PivotDropZone({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.onAccept,
    required this.onRemove,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, cand, rej) {
        final h = cand.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: h ? const Color(0xFFE8F5E9) : Colors.white,
            border: Border.all(color: h ? const Color(0xFF66BB6A) : Colors.grey.shade300, width: h ? 1 : 0.6),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 11, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey.shade800)),
                  if (subtitle != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(subtitle!, style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                  ),
                  child: Center(
                    child: Text('Drop fields here', style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontStyle: FontStyle.italic)),
                  ),
                )
              else
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: items.map((i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        border: Border.all(color: Colors.grey.shade300, width: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(i, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
                          const SizedBox(width: 3),
                          GestureDetector(
                            onTap: () => onRemove(i),
                            child: Icon(Icons.close, size: 9, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
