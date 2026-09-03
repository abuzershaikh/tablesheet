import 'dart:collection';
import '../../domain/entities/cell_entity.dart';

/// LRU cache for cell entities with size limit of 50MB
class CellCache {
  static const int maxSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int estimatedCellSizeBytes = 200; // Estimated average cell size
  
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap<String, _CacheEntry>();
  int _currentSizeBytes = 0;
  int _hitCount = 0;
  int _missCount = 0;

  /// Get cell from cache
  CellEntity? get(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      // Move to end (most recently used)
      entry.accessTime = DateTime.now();
      _cache[key] = entry;
      _hitCount++;
      return entry.cell;
    }
    _missCount++;
    return null;
  }

  /// Put cell in cache
  void put(String key, CellEntity cell) {
    final estimatedSize = _estimateCellSize(cell);
    
    // Remove existing entry if it exists
    if (_cache.containsKey(key)) {
      final existingEntry = _cache.remove(key)!;
      _currentSizeBytes -= existingEntry.sizeBytes;
    }

    // Evict entries if necessary to make space
    while (_currentSizeBytes + estimatedSize > maxSizeBytes && _cache.isNotEmpty) {
      _evictLRU();
    }

    // Add new entry
    final entry = _CacheEntry(
      cell: cell,
      sizeBytes: estimatedSize,
      accessTime: DateTime.now(),
    );
    
    _cache[key] = entry;
    _currentSizeBytes += estimatedSize;
  }

  /// Remove cell from cache
  void remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSizeBytes -= entry.sizeBytes;
    }
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
  }

  /// Evict least recently used entry
  void _evictLRU() {
    if (_cache.isEmpty) return;
    
    final firstKey = _cache.keys.first;
    final entry = _cache.remove(firstKey)!;
    _currentSizeBytes -= entry.sizeBytes;
  }

  /// Evict specific number of LRU entries
  void evictLRU(int count) {
    for (int i = 0; i < count && _cache.isNotEmpty; i++) {
      _evictLRU();
    }
  }

  /// Get cache hit rate (0.0 to 1.0)
  double get hitRate {
    final totalRequests = _hitCount + _missCount;
    if (totalRequests == 0) return 0.0;
    return _hitCount / totalRequests;
  }

  /// Get current cache size in bytes
  int get currentSizeBytes => _currentSizeBytes;

  /// Get current number of entries
  int get entryCount => _cache.length;

  /// Get cache statistics
  CacheStats get stats {
    return CacheStats(
      hitCount: _hitCount,
      missCount: _missCount,
      entryCount: entryCount,
      currentSizeBytes: currentSizeBytes,
      maxSizeBytes: maxSizeBytes,
      hitRate: hitRate,
    );
  }

  /// Check if cache contains key
  bool containsKey(String key) => _cache.containsKey(key);

  /// Estimate cell size in bytes
  int _estimateCellSize(CellEntity cell) {
    int size = estimatedCellSizeBytes; // Base size
    
    // Add size for value
    if (cell.value != null) {
      size += cell.value!.length * 2; // UTF-16 approximation
    }
    
    // Add size for formula
    if (cell.formula != null) {
      size += cell.formula!.length * 2;
    }
    
    return size;
  }

  /// Get all keys currently in cache
  List<String> get keys => _cache.keys.toList();

  /// Get cache utilization percentage (0.0 to 1.0)
  double get utilization => currentSizeBytes / maxSizeBytes;
}

/// Cache entry wrapper
class _CacheEntry {
  final CellEntity cell;
  final int sizeBytes;
  DateTime accessTime;

  _CacheEntry({
    required this.cell,
    required this.sizeBytes,
    required this.accessTime,
  });
}

/// Cache statistics
class CacheStats {
  final int hitCount;
  final int missCount;
  final int entryCount;
  final int currentSizeBytes;
  final int maxSizeBytes;
  final double hitRate;

  const CacheStats({
    required this.hitCount,
    required this.missCount,
    required this.entryCount,
    required this.currentSizeBytes,
    required this.maxSizeBytes,
    required this.hitRate,
  });

  @override
  String toString() {
    return 'CacheStats(hits: $hitCount, misses: $missCount, entries: $entryCount, '
           'size: ${(currentSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB/${(maxSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB, '
           'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}