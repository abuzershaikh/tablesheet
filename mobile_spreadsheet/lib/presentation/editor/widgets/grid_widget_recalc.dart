  bool _isEvaluating = false;

  Future<void> _recalculateAll() async {
    // We clear spill data but keep _evaluatedData intact so the UI shows
    // the previous answers or raw formulas as text while computing.
    // _evaluatedData.clear(); // DO NOT CLEAR, allows fallback to old answers
    _spillData.clear();
    
    // Step 1: Push everything to C++ Grid Manager
    NativeEngine.clearGrid();
    
    _cellData.forEach((key, val) {
      final parts = key.split(':');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      final cellRef = FormulaUtils.cellRefFromCoords(r, c);
      
      final trimmed = val.trim();

      if (trimmed.startsWith('=')) {
        NativeEngine.setCellFormula(cellRef, trimmed);
      } else {
        final num = double.tryParse(trimmed);
        if (num != null) {
          NativeEngine.setCellConstant(cellRef, num);
        } else {
          NativeEngine.setCellConstantString(cellRef, val);
        }
      }
    });

    if (!mounted) return;
    setState(() { _isEvaluating = true; });

    // Step 2: Trigger Engine Calculation on background thread to avoid freezing UI
    final resultJson = await NativeEngine.calculateAllAsync();
    
    if (!mounted) return;
    setState(() {
      _isEvaluating = false;
      _evaluatedData.clear(); // Now clear it just before parsing new results
      
      int maxRequiredRow = 0;
      int maxRequiredCol = 0;

      if (resultJson.isNotEmpty && resultJson != "{}") {
        try {
          final Map<String, dynamic> parsed = json.decode(resultJson);
          parsed.forEach((cellRef, value) {
            final coords = FormulaUtils.coordsFromCellRef(cellRef);
            if (coords != null) {
              final key = '\:\';
              
              if (value is Map && value['type'] == 'spill') {
                 final List<dynamic> data = value['data'];
                 maxRequiredRow = math.max(maxRequiredRow, coords.\ + data.length);
                 int maxColInSpill = 0;
                 for (int r = 0; r < data.length; r++) {
                   final rowList = data[r] as List;
                   maxColInSpill = math.max(maxColInSpill, coords.\ + rowList.length);
                 }
                 maxRequiredCol = math.max(maxRequiredCol, maxColInSpill);
                 
                 bool blocked = false;
                 // Check for spill blocks
                 for (int r = 0; r < data.length; r++) {
                   final rowList = data[r] as List;
                   for (int c = 0; c < rowList.length; c++) {
                     if (r == 0 && c == 0) continue;
                     final targetKey = '\:\';
                     final existingContent = _cellData[targetKey];
                     if (existingContent != null && existingContent.isNotEmpty) {
                       blocked = true;
                       break;
                     }
                   }
                   if (blocked) break;
                 }
                 
                 if (blocked) {
                   _evaluatedData[key] = '#SPILL!';
                 } else {
                   _evaluatedData[key] = data[0][0].toString();
                   for (int r = 0; r < data.length; r++) {
                     final rowList = data[r] as List;
                     for (int c = 0; c < rowList.length; c++) {
                       if (r == 0 && c == 0) continue;
                       final targetKey = '\:\';
                       _spillData[targetKey] = rowList[c].toString();
                     }
                   }
                 }
              } else {
                _evaluatedData[key] = value.toString();
              }
            }
          });
        } catch (e) {
          debugPrint('Engine JSON Parse Error: \');
        }
      }

      if (maxRequiredRow > widget.rowCount || maxRequiredCol > widget.columnCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (maxRequiredRow > widget.rowCount) {
            widget.onRowCountRequired?.call(maxRequiredRow + 20);
          }
          if (maxRequiredCol > widget.columnCount) {
            widget.onColumnCountRequired?.call(maxRequiredCol + 5);
          }
        });
      }
    });
  }
