  Future<void> pasteData(int startRow, int startColumn, String text) async {
    if (text.trim().isEmpty) return;
    if (!mounted) return;
    
    // UI Feedback for large pastes
    setState(() { _isEvaluating = true; });

    final updates = await CopyPasteEngine.processPasteAsync(
      text, startRow, startColumn, widget.rowCount, widget.columnCount
    );

    if (!mounted) return;
    setState(() {
      _saveSnapshot();
      for (final entry in updates.entries) {
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
  }
