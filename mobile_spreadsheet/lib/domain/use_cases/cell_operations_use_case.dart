import '../entities/cell_entity.dart';
import '../repositories/cell_repository.dart';

/// Cell address for operations
class CellAddress {
  final String sheetId;
  final String rowId;
  final String columnId;

  const CellAddress({
    required this.sheetId,
    required this.rowId,
    required this.columnId,
  });

  @override
  String toString() => '$sheetId:$rowId:$columnId';
}

/// Cell range for operations
class CellRange {
  final CellAddress startAddress;
  final CellAddress endAddress;

  const CellRange({
    required this.startAddress,
    required this.endAddress,
  });
}

/// Use case for cell operations
class CellOperationsUseCase {
  final CellRepository _cellRepository;

  CellOperationsUseCase(this._cellRepository);

  /// Get cell value by address
  Future<CellOperationResult<String?>> getCellValue(CellAddress address) async {
    try {
      final cell = await _cellRepository.getCellByAddress(
        address.sheetId,
        address.rowId,
        address.columnId,
      );
      
      return CellOperationResult.success(cell?.value);
    } catch (e) {
      return CellOperationResult.failure(
        CellOperationError.unknownError,
        'Failed to get cell value: $e',
      );
    }
  }

  /// Set cell value
  Future<CellOperationResult<void>> setCellValue(
    CellAddress address,
    String value,
  ) async {
    try {
      // Get existing cell or create new one
      var cell = await _cellRepository.getCellByAddress(
        address.sheetId,
        address.rowId,
        address.columnId,
      );

      if (cell == null) {
        // Create new cell
        cell = CellEntity(
          cellId: '${address.sheetId}-${address.rowId}-${address.columnId}',
          sheetId: address.sheetId,
          rowId: address.rowId,
          columnId: address.columnId,
          value: value,
          dataType: _inferDataType(value),
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        );
      } else {
        // Update existing cell
        cell = cell.copyWith(
          value: value,
          dataType: _inferDataType(value),
          modifiedAt: DateTime.now(),
        );
      }

      await _cellRepository.saveCell(cell);
      return CellOperationResult.success(null);
      
    } catch (e) {
      return CellOperationResult.failure(
        CellOperationError.unknownError,
        'Failed to set cell value: $e',
      );
    }
  }

  /// Get cells in range
  Future<CellOperationResult<List<CellEntity>>> getCellRange(
    String sheetId,
    int startRow,
    int endRow,
    int startColumn,
    int endColumn,
  ) async {
    try {
      if (startRow < 0 || endRow < startRow || startColumn < 0 || endColumn < startColumn) {
        return CellOperationResult.failure(
          CellOperationError.invalidRange,
          'Invalid range parameters',
        );
      }

      final cells = await _cellRepository.getCellRange(
        sheetId,
        startRow,
        endRow,
        startColumn,
        endColumn,
      );

      return CellOperationResult.success(cells);
      
    } catch (e) {
      return CellOperationResult.failure(
        CellOperationError.unknownError,
        'Failed to get cell range: $e',
      );
    }
  }

  /// Merge cells (placeholder - will be implemented later)
  Future<CellOperationResult<void>> mergeCells(CellRange range) async {
    try {
      // TODO: Implement cell merging logic
      // For now, just return success
      return CellOperationResult.success(null);
      
    } catch (e) {
      return CellOperationResult.failure(
        CellOperationError.unknownError,
        'Failed to merge cells: $e',
      );
    }
  }

  /// Unmerge cells (placeholder)
  Future<CellOperationResult<void>> unmergeCells(CellAddress address) async {
    try {
      // TODO: Implement cell unmerging logic
      return CellOperationResult.success(null);
      
    } catch (e) {
      return CellOperationResult.failure(
        CellOperationError.unknownError,
        'Failed to unmerge cells: $e',
      );
    }
  }

  /// Apply cell formatting
  Future<CellOperationResult<void>> applyCellFormatting(
    CellAddress address,
    CellFormat format,
  ) async {
    try {
      var cell = await _cellRepository.getCellByAddress(
        address.sheetId,
        address.rowId,
        address.columnId,
      );

      if (cell == null) {
        return CellOperationResult.failure(
          CellOperationError.cellNotFound,
          'Cell not found at address: $address',
        );
      }

      // Apply formatting
      cell = cell.copyWith(
        format: format,
        modifiedAt: DateTime.now(),
      );

      await _cellRepository.saveCell(cell);
      return CellOperationResult.success(null);
      
    } catch (e) {
      return CellOperationResult.failure(
        CellOperationError.unknownError,
        'Failed to apply formatting: $e',
      );
    }
  }

  /// Clear cell content
  Future<CellOperationResult<void>> clearCell(CellAddress address) async {
    try {
      final cell = await _cellRepository.getCellByAddress(
        address.sheetId,
        address.rowId,
        address.columnId,
      );

      if (cell != null) {
        await _cellRepository.deleteCell(cell.cellId);
      }

      return CellOperationResult.success(null);
      
    } catch (e) {
      return CellOperationResult.failure(
        CellOperationError.unknownError,
        'Failed to clear cell: $e',
      );
    }
  }

  /// Infer data type from string value
  CellDataType _inferDataType(String value) {
    if (value.isEmpty) return CellDataType.text;
    
    // Check if it's a number
    final numValue = double.tryParse(value);
    if (numValue != null) return CellDataType.number;
    
    // Check if it's a boolean
    if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
      return CellDataType.boolean;
    }
    
    // Check if it's a date (basic check)
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}');
    if (dateRegex.hasMatch(value)) {
      return CellDataType.date;
    }
    
    // Check if it's a formula
    if (value.startsWith('=')) {
      return CellDataType.formula;
    }
    
    return CellDataType.text;
  }
}

/// Result wrapper for cell operations
class CellOperationResult<T> {
  final bool isSuccess;
  final T? data;
  final CellOperationError? error;
  final String? errorMessage;

  const CellOperationResult.success(this.data)
      : isSuccess = true,
        error = null,
        errorMessage = null;

  const CellOperationResult.failure(this.error, this.errorMessage)
      : isSuccess = false,
        data = null;
}

/// Cell operation error types
enum CellOperationError {
  cellNotFound,
  invalidAddress,
  invalidRange,
  formulaError,
  unknownError,
}