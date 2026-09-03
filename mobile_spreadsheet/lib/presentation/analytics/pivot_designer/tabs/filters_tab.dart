import 'package:flutter/material.dart';
import '../models/pivot_designer_state.dart';

class FiltersTab extends StatelessWidget {
  final PivotDesignerState state;

  const FiltersTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 13, color: Colors.grey.shade700),
              const SizedBox(width: 5),
              const Text('Active Slicers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF333333))),
            ],
          ),
          Divider(height: 12, color: Colors.grey.shade300, thickness: 0.5),
          if (state.slicerFields.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.filter_alt_off_outlined, size: 24, color: Colors.grey.shade300),
                    const SizedBox(height: 6),
                    Text('No slicers active', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text('Drag fields to Filters in Fields tab', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: state.slicerFields.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final s = state.slicerFields[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.filter_alt, size: 11, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(width: 7),
                        Expanded(child: Text(s, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500))),
                        GestureDetector(
                          onTap: () => state.removeFieldFromSlicers(s),
                          child: Icon(Icons.remove_circle_outline, size: 13, color: Colors.red.shade400),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
