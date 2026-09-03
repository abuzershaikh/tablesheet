import '../../domain/entities/cell_entity.dart';
import '../../domain/repositories/cell_repository.dart';
import '../data_sources/local_data_source.dart';
import '../mappers/cell_mapper.dart';
import '../cache/cell_cache.dart';

/// Implementation of CellRepository with caching
class CellRepositoryImpl implements CellRepository {
  final LocalDataSource _localDataSource;
  final CellCache _cache;

  CellRepositoryImpl(this._localDataSource, this._cache);

  @override
  Future<CellEntity?> getCellByAddress(String sheetId, String rowId, String columnId) async {
    final cacheKey = '$sheetId:$rowId:$columnId';
    
    // Check cache first
    final cachedCell = _cache.get(cacheKey);
    if (cachedCell != null) {
      return cachedCell;
    }

    try {
      // Query from database
      final cellModel = await _localDataSource.queryCellByAddress(sheetId, rowId, columnId);
      if (cellModel == null) return null;

      // Convert to entity and cache
      final cellEntity = CellMapper.toEntity(cellModel);
      _cache.put(cacheKey, cellEntity);
      
      return cellEntity;
    } catch (e) {
      throw Exception('Failed to get cell: $e');
    }
  }

  @override
  Future<List<CellEntity>> getCellRange(String sheetId, int startRow, int endRow, int startCol, int endCol) async {
    try {
      final cellModels = await _localDataSource.queryCellRange(
        sheetId, 
        startRow, 
        endRow, 
        startCol, 
        endCol,
      );

      final entities = CellMapper.toEntities(cellModels);
      
      // Cache the retrieved cells
      for (final entity in entities) {
        final cacheKey = '${entity.sheetId}:${entity.rowId}:${entity.columnId}';
        _cache.put(cacheKey, entity);
      }

      return entities;
    } catch (e) {
      throw Exception('Failed to get cell range: $e');
    }
  }

  @override
  Future<List<CellEntity>> getCellsBySheet(String sheetId) async {
    try {
      final cellModels = await _localDataSource.getCellsBySheet(sheetId);
      final entities = CellMapper.toEntities(cellModels);
      
      // Cache all retrieved cells
      for (final entity in entities) {
        final cacheKey = '${entity.sheetId}:${entity.rowId}:${entity.columnId}';
        _cache.put(cacheKey, entity);
      }

      return entities;
    } catch (e) {
      throw Exception('Failed to get cells by sheet: $e');
    }
  }

  @override
  Future<void> saveCell(CellEntity cell) async {
    try {
      final cellModel = CellMapper.toModel(cell);
      await _localDataSource.insertOrUpdateCell(cellModel);
      
      // Update cache
      final cacheKey = '${cell.sheetId}:${cell.rowId}:${cell.columnId}';
      _cache.put(cacheKey, cell);
      
    } catch (e) {
      throw Exception('Failed to save cell: $e');
    }
  }

  @override
  Future<void> saveCells(List<CellEntity> cells) async {
    try {
      final cellModels = CellMapper.toModels(cells);
      await _localDataSource.batchUpdateCells(cellModels);
      
      // Update cache for all saved cells
      for (final cell in cells) {
        final cacheKey = '${cell.sheetId}:${cell.rowId}:${cell.columnId}';
        _cache.put(cacheKey, cell);
      }
      
    } catch (e) {
      throw Exception('Failed to save cells: $e');
    }
  }

  @override
  Future<void> deleteCell(String cellId) async {
    try {
      await _localDataSource.deleteCell(cellId);
      
      // Remove from cache - we need to find the cache key
      // This is inefficient, but necessary since we only have cellId
      final keys = _cache.keys;
      for (final key in keys) {
        final cell = _cache.get(key);
        if (cell != null && cell.cellId == cellId) {
          _cache.remove(key);
          break;
        }
      }
      
    } catch (e) {
      throw Exception('Failed to delete cell: $e');
    }
  }

  @override
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics
  CacheStats get cacheStats => _cache.stats;
}