import 'package:flutter/material.dart';
import '../models/pivot_designer_state.dart';
import '../../../../domain/analytics/models/aggregation_type.dart';

class SettingsTab extends StatelessWidget {
  final PivotDesignerState state;

  const SettingsTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hdr('Aggregation Function', Icons.functions),
          const SizedBox(height: 5),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
              borderRadius: BorderRadius.circular(5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AggregationType>(
                isExpanded: true,
                value: state.aggType,
                icon: Icon(Icons.keyboard_arrow_down, size: 15, color: Colors.grey.shade600),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                items: AggregationType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(_ic(t), size: 12, color: const Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        Text(t.name.toUpperCase()),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) state.setAggregationType(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          _hdr('Layout & Totals', Icons.grid_view_outlined),
          const SizedBox(height: 5),
          _sw('Grand Totals — Rows', true),
          _sw('Grand Totals — Columns', true),
          _sw('Subtotals', false),
        ],
      ),
    );
  }

  Widget _hdr(String t, IconData i) {
    return Row(
      children: [
        Icon(i, size: 12, color: Colors.grey.shade700),
        const SizedBox(width: 5),
        Text(t, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Colors.grey.shade800)),
      ],
    );
  }

  Widget _sw(String l, bool v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(l, style: const TextStyle(fontSize: 14, color: Color(0xFF444444)))),
          SizedBox(
            height: 22,
            width: 32,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: v,
                onChanged: (_) {},
                activeColor: const Color(0xFF2E7D32),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _ic(AggregationType t) {
    switch (t) {
      case AggregationType.sum: return Icons.add;
      case AggregationType.average: return Icons.show_chart;
      case AggregationType.count: return Icons.tag;
      case AggregationType.min: return Icons.arrow_downward;
      case AggregationType.max: return Icons.arrow_upward;
      default: return Icons.functions;
    }
  }
}
