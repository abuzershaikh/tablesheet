import 'package:flutter/material.dart';
import '../models/pivot_designer_state.dart';
import '../widgets/draggable_field_item.dart';
import '../widgets/pivot_drop_zone.dart';

class FieldsTab extends StatefulWidget {
  final PivotDesignerState state;

  const FieldsTab({super.key, required this.state});

  @override
  State<FieldsTab> createState() => _FieldsTabState();
}

class _FieldsTabState extends State<FieldsTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.state.availableColumns.where((c) => c.toLowerCase().contains(_q.toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose fields to add:', style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600)),
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: TextField(
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search fields...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, size: 14, color: Colors.grey.shade400),
                prefixIconConstraints: const BoxConstraints(minWidth: 28),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 125,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: c.length,
              itemBuilder: (_, i) => DraggableFieldItem(fieldName: c[i]),
            ),
          ),
          Divider(height: 10, color: Colors.grey.shade300, thickness: 0.5),
          Text('Drag fields between areas below:', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  PivotDropZone(title: 'Filters', icon: Icons.filter_alt_outlined, items: widget.state.slicerFields, onAccept: widget.state.addFieldToSlicers, onRemove: widget.state.removeFieldFromSlicers),
                  PivotDropZone(title: 'Rows', icon: Icons.view_headline, items: widget.state.rowFields, onAccept: widget.state.addFieldToRows, onRemove: widget.state.removeFieldFromRows),
                  PivotDropZone(title: 'Columns', icon: Icons.view_column_outlined, items: widget.state.colFields, onAccept: widget.state.addFieldToCols, onRemove: widget.state.removeFieldFromCols),
                  PivotDropZone(
                    title: 'Values',
                    icon: Icons.functions,
                    items: widget.state.dataFields.map((f) => '${widget.state.aggType.name} of $f').toList(),
                    subtitle: widget.state.aggType.name.toUpperCase(),
                    onAccept: widget.state.addFieldToData,
                    onRemove: (item) {
                      final f = widget.state.dataFields.firstWhere((f) => item.contains(f), orElse: () => '');
                      if (f.isNotEmpty) widget.state.removeFieldFromData(f);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
