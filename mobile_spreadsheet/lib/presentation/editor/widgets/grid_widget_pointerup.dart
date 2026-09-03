  void _onPointerUp(PointerUpEvent event) {
    if (_handleTouched && _isDragFilling &&
        _selectedRow != null && _selectedColumn != null && _fillTargetRow != null) {
      final startRow = _selectedRow!;
      final endRow = _fillTargetRow!;
      final col = _selectedColumn!;
      if (endRow > startRow) {
        // Show slide menu before acting
        final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final position = RelativeRect.fromRect(
          Rect.fromPoints(event.position, event.position),
          Offset.zero & overlay.size,
        );
        showMenu(
          context: context,
          position: position,
          items: [
            const PopupMenuItem(value: 'copy', child: Text('Copy')),
            const PopupMenuItem(value: 'autofill', child: Text('AutoFill')),
          ],
        ).then((value) {
          if (value == 'autofill') {
            _commitAutoFillBackground(startRow, endRow, col);
          } else if (value == 'copy') {
            _commitCopyBackground(startRow, endRow, col);
          }
        });
      }
    }
    setState(() {
      _handleTouched = false;
      _isDragFilling = false;
      _fillTargetRow = null;
    });
  }

  Future<void> _commitAutoFillBackground(int startRow, int endRow, int col) async {
    _saveSnapshot();
    setState(() { _isEvaluating = true; });

    final sourceValues = <String>[];
    int r = startRow;
    while (r <= endRow) {
      final val = getCellValue(r, col);
      if (val.isNotEmpty) {
        sourceValues.add(val);
        r++;
        if (sourceValues.length >= 20) break;
      } else {
        break;
      }
    }

    if (sourceValues.isEmpty) {
      final val = getCellValue(startRow, col);
      if (val.isNotEmpty) sourceValues.add(val);
    }

    if (sourceValues.isNotEmpty) {
      final generatedCells = await CopyPasteEngine.processAutoFillAsync(startRow, endRow, col, sourceValues);
      
      if (!mounted) return;
      setState(() {
        for (final entry in generatedCells.entries) {
          if (entry.value.isNotEmpty) {
            _cellData[entry.key] = entry.value;
          } else {
            _cellData.remove(entry.key);
          }
        }
        _dataVersion++;
        _recalculateAll();
        widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
      });
    } else {
      setState(() { _isEvaluating = false; });
    }
  }

  Future<void> _commitCopyBackground(int startRow, int endRow, int col) async {
    _saveSnapshot();
    setState(() { _isEvaluating = true; });

    // Copying just duplicates the source cell over the range
    final sourceVal = getCellValue(startRow, col);
    if (sourceVal.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        for (int r = startRow + 1; r <= endRow; r++) {
          final key = '${r}:${col}';
          _cellData[key] = sourceVal;
        }
        _dataVersion++;
        _recalculateAll();
        widget.onCellDataChanged?.call(Map.unmodifiable(_cellData));
      });
    } else {
      setState(() { _isEvaluating = false; });
    }
  }
