import 'package:flutter/material.dart';
import '../../../../domain/entities/sheet_entity.dart';
import '../../editor_controller.dart';
import '../../../../domain/services/super_engine/ffi_bridge.dart';
import '../../../../domain/services/storage/sheet_data_storage.dart';

class TextToColumnsScreen extends StatefulWidget {
  final EditorController controller;
  final String initialData;
  final int startRow;
  final int startCol;
  final String spreadsheetId;
  final Map<String, String> existingCellData;

  const TextToColumnsScreen({
    Key? key,
    required this.controller,
    required this.initialData,
    required this.startRow,
    required this.startCol,
    required this.spreadsheetId,
    required this.existingCellData,
  }) : super(key: key);

  @override
  State<TextToColumnsScreen> createState() => _TextToColumnsScreenState();
}

class _TextToColumnsScreenState extends State<TextToColumnsScreen> {
  late int _selectedCol;
  late Map<String, String> _workingCellData;
  List<String> _columnData = [];

  bool _useComma = true;
  bool _useSpace = false;
  bool _useTab = false;
  bool _useSemicolon = false;
  bool _usePipe = false;
  String _customDelimiter = '';
  
  String _textQualifier = '"';
  bool _ignoreConsecutive = true;
  bool _splitHorizontal = true;

  List<List<String>> _previewData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCol = widget.startCol;
    _workingCellData = Map<String, String>.from(widget.existingCellData);
    _fetchDataForColumn(_selectedCol);
  }

  String _getColName(int col) {
    String name = '';
    int c = col;
    while (c >= 0) {
      name = String.fromCharCode('A'.codeUnitAt(0) + (c % 26)) + name;
      c = (c ~/ 26) - 1;
    }
    return name;
  }

  Future<void> _fetchDataForColumn(int col) async {
    setState(() => _isLoading = true);
    _columnData.clear();
    
    // Check if we also have saved data on disk if workingCellData is empty
    if (_workingCellData.isEmpty) {
      final diskData = await SheetDataStorage.loadCellData(widget.spreadsheetId);
      if (diskData != null) {
        _workingCellData.addAll(diskData);
      }
    }
    
    if (_workingCellData.isNotEmpty) {
      int maxRow = -1;
      for (var key in _workingCellData.keys) {
        final parts = key.split(':');
        if (parts.length == 2 && int.tryParse(parts[1]) == col) {
          final r = int.tryParse(parts[0]) ?? -1;
          if (r > maxRow) maxRow = r;
        }
      }
      for (int i = 0; i <= maxRow; i++) {
        _columnData.add(_workingCellData['$i:$col'] ?? '');
      }
    }
    
    // Fallback if empty but we have unsaved live data from the selection
    if (_columnData.isEmpty && col == widget.startCol && widget.initialData.isNotEmpty) {
      for (int i = 0; i <= widget.startRow; i++) {
        _columnData.add(i == widget.startRow ? widget.initialData : '');
      }
    }
    
    await _updatePreview();
  }

  String _getDelimiters() {
    String d = '';
    if (_useComma) d += ',';
    if (_useSpace) d += ' ';
    if (_useTab) d += '\t';
    if (_useSemicolon) d += ';';
    if (_usePipe) d += '|';
    d += _customDelimiter;
    return d;
  }

  Future<void> _updatePreview() async {
    final delimiters = _getDelimiters();
    if (delimiters.isEmpty || _columnData.isEmpty) {
      setState(() {
        _previewData = _columnData.map((e) => [e]).toList();
        _isLoading = false;
      });
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      List<List<String>> newPreview = [];
      for (var rowText in _columnData) {
        if (rowText.isEmpty) {
          newPreview.add(['']);
          continue;
        }
        final result = await NativeEngine.splitTextToColumns(
          rowText, 
          delimiters, 
          _ignoreConsecutive, 
          _textQualifier == "none" ? "" : _textQualifier
        );
        if (result.isNotEmpty) {
          newPreview.add(result[0]); // Take the first row of the split result
        } else {
          newPreview.add(['']);
        }
      }
      
      if (mounted) {
        setState(() {
          _previewData = newPreview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewData = _columnData.map((e) => [e]).toList();
          _isLoading = false;
        });
      }
    }
  }

  void _applySplit() async {
    if (_previewData.isEmpty) {
      Navigator.pop(context);
      return;
    }
    
    int c = _selectedCol;
    
    for (int i = 0; i < _previewData.length; i++) {
      if (_previewData[i].isEmpty || (_previewData[i].length == 1 && _previewData[i][0].isEmpty)) continue;
      
      for (int j = 0; j < _previewData[i].length; j++) {
        final val = _previewData[i][j];
        int targetRow = i; // _columnData maps 1:1 with rows from 0 to maxRow
        int targetCol = c;
        
        if (_splitHorizontal) {
          targetCol = c + j;
        } else {
          targetRow = i + j;
          targetCol = c; 
        }
        
        final key = '$targetRow:$targetCol';
        _workingCellData[key] = val;
      }
    }
    
    await SheetDataStorage.saveCellData(widget.spreadsheetId, _workingCellData);
    
    if (mounted) Navigator.pop(context, _workingCellData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Text to Columns'),
        backgroundColor: const Color(0xFF107C41),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _applySplit,
            tooltip: 'Apply',
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings Panel
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Column Selection
                Row(
                  children: [
                    const Icon(Icons.view_column, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Source Column:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _selectedCol,
                      items: List.generate(26, (index) {
                        return DropdownMenuItem(
                          value: index,
                          child: Text('Column ${_getColName(index)}'),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCol = val);
                          _fetchDataForColumn(val);
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                
                // Delimiters
                const Text('Delimiters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(label: const Text('Comma (,)'), selected: _useComma, onSelected: (val) { setState(() => _useComma = val); _updatePreview(); }),
                    FilterChip(label: const Text('Space'), selected: _useSpace, onSelected: (val) { setState(() => _useSpace = val); _updatePreview(); }),
                    FilterChip(label: const Text('Tab'), selected: _useTab, onSelected: (val) { setState(() => _useTab = val); _updatePreview(); }),
                    FilterChip(label: const Text('Semicolon (;)'), selected: _useSemicolon, onSelected: (val) { setState(() => _useSemicolon = val); _updatePreview(); }),
                    FilterChip(label: const Text('Pipe (|)'), selected: _usePipe, onSelected: (val) { setState(() => _usePipe = val); _updatePreview(); }),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Custom Delimiter',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    _customDelimiter = val;
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 24),
                
                // Text Qualifier
                const Text('Text Qualifier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                DropdownButton<String>(
                  value: _textQualifier,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '"', child: Text('Double Quote (")')),
                    DropdownMenuItem(value: "'", child: Text("Single Quote (')")),
                    DropdownMenuItem(value: "none", child: Text('None')),
                  ],
                  onChanged: (val) { if(val != null) { setState(() => _textQualifier = val); _updatePreview(); } },
                ),
                const SizedBox(height: 16),
                
                // Options
                SwitchListTile(
                  title: const Text('Ignore consecutive delimiters'),
                  value: _ignoreConsecutive,
                  onChanged: (val) { setState(() => _ignoreConsecutive = val); _updatePreview(); },
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Split Direction: Horizontal (Columns)'),
                  subtitle: const Text('Turn off to split into rows'),
                  value: _splitHorizontal,
                  onChanged: (val) { setState(() => _splitHorizontal = val); _updatePreview(); },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 2),
          
          // Preview Panel
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFFF3F2F1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Live Data Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _previewData.isEmpty || _previewData.every((r) => r.isEmpty)
                          ? const Center(child: Text('No data to preview', style: TextStyle(color: Colors.grey)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                                  border: TableBorder.all(color: Colors.grey.shade300),
                                  columns: List.generate(
                                    _previewData.isNotEmpty ? _previewData.fold(0, (max, row) => row.length > max ? row.length : max) : 0,
                                    (index) => DataColumn(
                                      label: Text(
                                        _splitHorizontal 
                                          ? 'Col ${_getColName(_selectedCol + index)}'
                                          : 'Row +$index',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      )
                                    ),
                                  ),
                                  rows: List.generate(
                                    _previewData.length,
                                    (rowIndex) {
                                      final maxCols = _previewData.fold(0, (max, row) => row.length > max ? row.length : max);
                                      return DataRow(
                                        cells: List.generate(
                                          maxCols,
                                          (colIndex) => DataCell(Text(colIndex < _previewData[rowIndex].length ? _previewData[rowIndex][colIndex] : '')),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
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
