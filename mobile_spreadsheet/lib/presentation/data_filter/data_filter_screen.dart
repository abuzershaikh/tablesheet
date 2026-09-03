import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/services/super_engine/ffi_bridge.dart';

class DataFilterScreen extends StatefulWidget {
  final String sheetId;

  const DataFilterScreen({Key? key, this.sheetId = 'default_sheet'}) : super(key: key);

  @override
  _DataFilterScreenState createState() => _DataFilterScreenState();
}

class _DataFilterScreenState extends State<DataFilterScreen> {
  int _selectedCol = 0;
  String _previewStats = "{}";
  String _hiddenRows = "[]";
  String _bitmapResult = "[]";

  void _applyPhoneFilter() {
    // Generate a JSON rule
    final rule = {
      "type": "phone",
      "logic": "AND",
      "conditions": [
        {"field": "country", "operator": "startsWith", "value": "+91"},
        {"field": "length", "operator": "equals", "value": 13} // +91 + 10 digits = 13 length
      ]
    };
    final jsonRule = jsonEncode(rule);

    NativeEngine.filterAddRuleFromJson(widget.sheetId, _selectedCol, jsonRule);
    
    // Get preview
    setState(() {
      _previewStats = NativeEngine.filterGetPreviewStats(widget.sheetId, _selectedCol, jsonRule, 100);
      _hiddenRows = NativeEngine.filterGetHiddenRows(widget.sheetId, 100);
      _bitmapResult = NativeEngine.filterGetVisibleRowsBitmap(widget.sheetId, 100).toList().toString();
    });
  }

  void _clearFilters() {
    NativeEngine.filterClear(widget.sheetId);
    setState(() {
      _previewStats = "{}";
      _hiddenRows = NativeEngine.filterGetHiddenRows(widget.sheetId, 100);
      _bitmapResult = NativeEngine.filterGetVisibleRowsBitmap(widget.sheetId, 100).toList().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Filter Engine')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Column:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<int>(
              value: _selectedCol,
              items: List.generate(5, (index) => DropdownMenuItem(
                value: index,
                child: Text('Column ${String.fromCharCode(65 + index)}'),
              )),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCol = val);
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _applyPhoneFilter,
                  child: const Text('Apply Phone Filter (+91)'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear Filter'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Preview Stats:', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              width: double.infinity,
              child: Text(_previewStats, style: const TextStyle(fontFamily: 'monospace')),
            ),
            const SizedBox(height: 20),
            const Text('Hidden Rows (JSON array):', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              width: double.infinity,
              child: Text(_hiddenRows, style: const TextStyle(fontFamily: 'monospace')),
            ),
            const SizedBox(height: 20),
            const Text('Row Visibility Bitmap (FFI uint8_t):', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              width: double.infinity,
              child: Text(_bitmapResult, style: const TextStyle(fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }
}
