# Technical Design Document

## 1. System Overview

This document describes the technical design for the Mobile Spreadsheet application, a high-performance Android spreadsheet app with Vulkan GPU acceleration, comprehensive formula support, and AI agent integration.

### 1.1 Architecture Style

The application follows **Clean Architecture** principles with clear separation of concerns across five distinct layers:

```
┌─────────────────────────────────────────────────────────┐
│                   Presentation Layer                     │
│  (UI, Screens, Widgets, Controllers, State Management)  │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                    Domain Layer                          │
│     (Business Logic, Use Cases, Entities, Rules)        │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                     Data Layer                           │
│   (Repositories, Data Sources, Models, Mappers)         │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                   Services Layer                         │
│  (Storage, Rendering, Formula, API, AI Agent)           │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                     Core Layer                           │
│    (Constants, Utilities, Errors, Theme, Network)       │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Key Design Decisions

1. **Clean Architecture**: Enforces dependency inversion and testability
2. **UUID-based Addressing**: Stable references across operations
3. **Custom Vulkan Engine**: 60-120 FPS rendering, 40% battery savings
4. **GPU Compute**: 10-25x faster formula calculations
5. **Sparse Storage**: Only store non-empty cells in SQLite
6. **Virtual Viewport**: Render only visible cells for constant performance
7. **Texture Atlas**: Pre-rendered text glyphs for fast rendering
8. **Provider Pattern**: Reactive state management
9. **Repository Pattern**: Abstract data access
10. **Command Pattern**: Undo/redo functionality

---

## 2. High-Level Architecture

### 2.1 Complete System Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                         Flutter App                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Presentation Layer (Dart)                    │  │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────────┐   │  │
│  │  │    Home    │  │   Editor   │  │     Import       │   │  │
│  │  │   Screen   │  │   Screen   │  │     Screens      │   │  │
│  │  └─────┬──────┘  └─────┬──────┘  └────────┬─────────┘   │  │
│  │        │               │                   │             │  │
│  │  ┌─────▼───────────────▼───────────────────▼─────────┐   │  │
│  │  │           Controllers (Provider/GetX)             │   │  │
│  │  └─────┬───────────────────────────────────────────┬─┘   │  │
│  └────────┼───────────────────────────────────────────┼─────┘  │
│           │                                           │        │
│  ┌────────▼───────────────────────────────────────────▼─────┐  │
│  │                  Domain Layer (Dart)                     │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │  Use Cases (Business Logic)                      │   │  │
│  │  │  • SheetManagement  • CellOperations             │   │  │
│  │  │  • FormulaEngine    • ImportExport               │   │  │
│  │  │  • APIIntegration   • AIAgent                    │   │  │
│  │  └──────────────────┬───────────────────────────────┘   │  │
│  │                     │                                   │  │
│  │  ┌──────────────────▼───────────────────────────────┐   │  │
│  │  │  Entities (Business Objects)                     │   │  │
│  │  │  • CellEntity  • SheetEntity  • RowEntity        │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │                                      │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │                  Data Layer (Dart)                        │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Repositories (Implementations)                    │  │  │
│  │  └─────┬──────────────────────────────────────────┬───┘  │  │
│  │        │                                          │      │  │
│  │  ┌─────▼─────────────┐          ┌────────────────▼───┐  │  │
│  │  │  Local Data       │          │  Remote Data       │  │  │
│  │  │  Source           │          │  Source            │  │  │
│  │  │  (SQLite)         │          │  (REST API)        │  │  │
│  │  └───────────────────┘          └────────────────────┘  │  │
│  └──────────────────────┬───────────────────────────────────┘  │
│                         │                                      │
│  ┌──────────────────────▼───────────────────────────────────┐  │
│  │               Services Layer (Dart/C++)                   │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │  Storage     │  │   Formula    │  │     API      │   │  │
│  │  │  Service     │  │   Service    │  │   Service    │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │
│  │                                                           │  │
│  │  ┌───────────────────────────────────────────────────┐   │  │
│  │  │        Native Bridge (JNI / FFI)                  │   │  │
│  │  └──────────────────────┬────────────────────────────┘   │  │
│  └─────────────────────────┼────────────────────────────────┘  │
└────────────────────────────┼────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                  Native Layer (C++ / NDK)                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │          Custom Vulkan Rendering Engine                   │  │
│  │  ┌─────────────────┐  ┌─────────────────┐               │  │
│  │  │  Virtual        │  │  Cell Batch     │               │  │
│  │  │  Viewport       │  │  Renderer       │               │  │
│  │  └─────────────────┘  └─────────────────┘               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐               │  │
│  │  │  Texture        │  │  Command        │               │  │
│  │  │  Atlas          │  │  Buffer Pool    │               │  │
│  │  └─────────────────┘  └─────────────────┘               │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │          GPU Compute Engine                               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐               │  │
│  │  │  Formula        │  │  Compute        │               │  │
│  │  │  Compiler       │  │  Shader Exec    │               │  │
│  │  └─────────────────┘  └─────────────────┘               │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   Vulkan Driver                           │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐     │  │
│  │  │  Graphics   │  │   Compute   │  │   Transfer   │     │  │
│  │  │   Queue     │  │    Queue    │  │    Queue     │     │  │
│  │  └─────────────┘  └─────────────┘  └──────────────┘     │  │
│  └───────────────────────────────────────────────────────────┘  │
└────────────────────────────┬─────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────────┐
│               GPU Hardware (Adreno / Mali / PowerVR)             │
└──────────────────────────────────────────────────────────────────┘
```


### 2.2 Data Flow

#### Cell Edit Flow
```
User taps cell
     │
     ▼
PresentationController.selectCell()
     │
     ▼
CellOperationsUseCase.selectCell(cellId)
     │
     ▼
CellRepository.getCellData(cellId)
     │
     ▼
LocalDataSource.queryCell(cellId)  ←─── Cell Cache (50MB LRU)
     │
     ▼
SQLite Database (UUID-indexed)
     │
     ▼
CellEntity returned to UI
     │
     ▼
UI renders selected cell (blue border)

User double-taps → Edit mode
     │
     ▼
FormulaBar appears
     │
     ▼
User types "=SUM(A1:A100)"
     │
     ▼
FormulaService.parseFormula()
     │
     ├─ Syntax validation
     ├─ AST generation
     └─ Dependency tracking
     │
     ▼
FormulaEngine.evaluateFormula()
     │
     ├─ Check if range > 1000 cells
     │      │
     │      ├─ YES → GPU Compute
     │      │         │
     │      │         ├─ Compile to GLSL
     │      │         ├─ Generate SPIR-V
     │      │         ├─ Dispatch compute shader
     │      │         └─ Read GPU result (5ms)
     │      │
     │      └─ NO  → CPU Calculate (50ms)
     │
     ▼
Result displayed in cell
     │
     ▼
StorageService.batchUpdate() ←─── Auto-save queue
     │                              (commits every 30s)
     ▼
SQLite transaction committed
```

#### Rendering Flow
```
Frame Start (16.67ms budget for 60 FPS)
     │
     ▼
VirtualViewport.calculateVisibleCells()
     │  ├─ scrollX, scrollY, zoom
     │  ├─ viewport width, height
     │  └─ Returns: startRow, endRow, startCol, endCol
     │
     ▼
CellBatchRenderer.prepareBatch(visibleCells)
     │
     ├─ For each visible cell:
     │    ├─ Get cell position
     │    ├─ Get cell size
     │    ├─ Get background color
     │    ├─ Get text texture index (from atlas)
     │    └─ Create instance data
     │
     ▼
Upload instance data to GPU (1ms)
     │
     ▼
Vulkan Command Buffer recording:
     │  ├─ Bind graphics pipeline
     │  ├─ Bind descriptor sets (texture atlas)
     │  ├─ Draw instanced (single draw call for all cells)
     │  └─ Draw grid lines (fragment shader)
     │
     ▼
Submit to Graphics Queue (8ms GPU rendering)
     │
     ▼
Swapchain Present (1ms)
     │
     ▼
Frame Complete (~13ms total)
```

---

## 3. Component Design

### 3.1 Presentation Layer

#### Home Screen Component
```
HomeScreen
├── HomeController (Provider)
│   ├── spreadsheetList: List<SpreadsheetEntity>
│   ├── viewMode: GridView / ListView
│   ├── searchQuery: String
│   ├── sortBy: Name / DateModified / DateCreated
│   │
│   ├── loadSpreadsheets()
│   ├── searchSpreadsheets(query)
│   ├── sortSpreadsheets(sortBy)
│   ├── deleteSpreadsheet(id)
│   ├── duplicateSpreadsheet(id)
│   └── createNewSpreadsheet()
│
├── Widgets
│   ├── FABMenu
│   │   ├── CreateNewButton
│   │   ├── ImportExcelButton
│   │   ├── ImportCSVButton
│   │   ├── ImportGoogleFormsButton
│   │   └── ImportAPIButton
│   │
│   ├── SheetCard
│   │   ├── ThumbnailImage (5×5 cells preview)
│   │   ├── SheetName (max 2 lines)
│   │   ├── Metadata (date, size, row/col count)
│   │   ├── QuickActionsMenu (3-dot)
│   │   └── GestureHandlers
│   │       ├── onTap → Open sheet
│   │       ├── onLongPress → Multi-select
│   │       └── onSwipe → Delete with undo
│   │
│   └── SearchBar
│       ├── TextField with filter icon
│       └── Sort/Filter dropdown
│
└── Navigation
    ├── To EditorScreen (on card tap)
    └── To ImportScreens (on FAB menu)
```


#### Editor Screen Component
```
EditorScreen
├── EditorController (Provider)
│   ├── currentSheet: SheetEntity
│   ├── selectedCells: List<CellPosition>
│   ├── editingCell: CellEntity?
│   ├── clipboard: ClipboardData
│   ├── undoStack: List<Command>
│   ├── redoStack: List<Command>
│   ├── scrollX: double
│   ├── scrollY: double
│   ├── zoom: double
│   │
│   ├── selectCell(position)
│   ├── selectRange(start, end)
│   ├── editCell(cell, value)
│   ├── applyFormatting(cells, format)
│   ├── copy()
│   ├── cut()
│   ├── paste()
│   ├── undo()
│   ├── redo()
│   ├── autoFill(from, to)
│   └── updateViewport(scrollX, scrollY, zoom)
│
├── Widgets
│   ├── TopAppBar
│   │   ├── BackButton
│   │   ├── SheetTitle with badge
│   │   └── SearchIcon
│   │
│   ├── FormulaBar (conditional visibility)
│   │   ├── FxIcon (function picker)
│   │   ├── InputField (formula/value)
│   │   ├── ConfirmButton (✓)
│   │   └── CancelButton (✕)
│   │
│   ├── GridWidget (NativeRenderSurface)
│   │   ├── VulkanSurfaceView
│   │   ├── GestureDetector
│   │   │   ├── onTap → selectCell
│   │   │   ├── onDoubleTap → editCell
│   │   │   ├── onLongPress → contextMenu
│   │   │   ├── onPanUpdate → scroll
│   │   │   └── onScaleUpdate → zoom
│   │   │
│   │   ├── ColumnHeaders
│   │   │   ├── onTap → openColumnProperties
│   │   │   └── onDragBorder → resizeColumn
│   │   │
│   │   └── RowHeaders
│   │       ├── onTap → openRowProperties
│   │       └── onDragBorder → resizeRow
│   │
│   ├── SheetTabs (bottom)
│   │   ├── Horizontal scroll
│   │   ├── Active indicator
│   │   ├── Add sheet button (+)
│   │   └── onTap → switchSheet
│   │
│   ├── BottomToolbar
│   │   ├── SortIcon
│   │   ├── FilterIcon
│   │   ├── FormatIcon
│   │   ├── ShareIcon
│   │   └── MoreIcon
│   │
│   └── BottomSheets (modal)
│       ├── ColumnPropertiesSheet
│       │   ├── ColumnNameInput
│       │   ├── ColumnTypeSelector
│       │   ├── WidthSlider
│       │   ├── StylesSection
│       │   └── ActionsList
│       │
│       ├── RowPropertiesSheet
│       │   ├── RowNumberInput
│       │   ├── HeightSlider
│       │   ├── StylesSection
│       │   └── ActionsList
│       │
│       └── ContextMenu
│           ├── Cut / Copy / Paste
│           ├── Delete
│           ├── Insert Link
│           ├── Add Comment
│           ├── Format Cells
│           └── Insert Chart
│
└── State Management
    ├── CellSelectionState
    ├── EditingState
    ├── ViewportState
    ├── UndoRedoState
    └── SheetState
```

### 3.2 Domain Layer

#### Use Cases
```
SheetManagementUseCase
├── createSheet(name)
├── deleteSheet(sheetId)
├── renameSheet(sheetId, newName)
├── duplicateSheet(sheetId)
├── reorderSheets(oldIndex, newIndex)
└── getSheetList()

CellOperationsUseCase
├── getCellValue(cellAddress)
├── setCellValue(cellAddress, value)
├── getCellRange(startAddress, endAddress)
├── selectCell(cellAddress)
├── selectRange(start, end)
├── mergeCells(cellRange)
├── unmergeCells(cellAddress)
└── applyCellFormatting(cellAddress, format)

FormulaEngineUseCase
├── parseFormula(formulaString)
│   ├── Tokenize
│   ├── Build AST
│   ├── Validate syntax
│   └── Return FormulaAST or Error
│
├── evaluateFormula(formulaAST, context)
│   ├── Resolve cell references
│   ├── Execute functions
│   ├── Calculate result
│   └── Return value or Error
│
├── getDependencies(cellAddress)
│   └── Return List<CellAddress>
│
├── recalculateDependents(cellAddress)
│   ├── Get dependency graph
│   ├── Topological sort
│   └── Recalculate in order
│
└── compileFormulaToGPU(formulaAST)
    ├── Generate GLSL code
    ├── Compile to SPIR-V
    └── Return ComputeShader

ImportExportUseCase
├── importExcel(filePath)
│   ├── Parse xlsx/xls
│   ├── Extract sheets
│   ├── Map to entities
│   └── Save to database
│
├── importCSV(filePath)
│   ├── Parse CSV (RFC 4180)
│   ├── Detect headers
│   ├── Map columns
│   └── Create sheet
│
├── exportToExcel(sheetId, outputPath)
├── exportToCSV(sheetId, outputPath)
└── exportToPDF(sheetId, outputPath)

APIIntegrationUseCase
├── configureAPIEndpoint(config)
│   ├── url, method, auth
│   ├── Test connection
│   └── Save endpoint
│
├── fetchAPIData(endpointId)
│   ├── Send request
│   ├── Parse response (JSON/XML)
│   └── Return data
│
├── mapAPIFieldsToColumns(data, mapping)
│   └── Create sheet with mapped data
│
├── scheduleAutoRefresh(endpointId, interval)
└── syncAPIData(endpointId)

AIAgentUseCase
├── getCellValue(sheetId, rowId, columnId)
├── setCellValue(sheetId, rowId, columnId, value)
├── getRowData(sheetId, rowId)
├── getColumnData(sheetId, columnId)
├── getRangeData(sheetId, range)
├── appendRow(sheetId, rowData)
├── updateRow(sheetId, rowId, rowData)
├── deleteRow(sheetId, rowId)
├── queryData(sheetId, filter)
├── getSheetStructure(sheetId)
├── getFormulaDependencies(sheetId)
└── getValidationRules(sheetId, columnId)
```


#### Entities
```dart
// Cell Entity
class CellEntity {
  final String cellId;        // UUID
  final String sheetId;       // UUID
  final String rowId;         // UUID
  final String columnId;      // UUID
  final String? value;
  final String? formula;
  final CellDataType dataType;
  final CellFormat? format;
  final DateTime createdAt;
  final DateTime modifiedAt;
  
  String get address => '$sheetId:$rowId:$columnId';
  bool get hasFormula => formula != null;
  bool get isEmpty => value == null && !hasFormula;
}

// Sheet Entity
class SheetEntity {
  final String sheetId;       // UUID
  final String spreadsheetId;
  final String sheetName;
  final int sheetOrder;
  final int rowCount;
  final int columnCount;
  final DateTime createdAt;
  final DateTime modifiedAt;
}

// Row Entity
class RowEntity {
  final String rowId;         // UUID (persistent)
  final String sheetId;
  final int rowNumber;        // Display position
  final double height;
  final bool visible;
  final CellFormat? defaultFormat;
}

// Column Entity
class ColumnEntity {
  final String columnId;      // UUID
  final String sheetId;
  final String columnName;    // A, B, C, or custom
  final int columnNumber;     // Display position
  final ColumnType columnType;
  final double width;
  final bool visible;
  final CellFormat? defaultFormat;
}

// Spreadsheet Entity
class SpreadsheetEntity {
  final String spreadsheetId;
  final String name;
  final String? thumbnailPath;
  final int fileSize;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime lastOpened;
  final List<SheetEntity> sheets;
}
```

### 3.3 Data Layer

#### Repository Pattern
```dart
// Abstract Repository Interface (Domain Layer)
abstract class CellRepository {
  Future<CellEntity?> getCellById(String cellId);
  Future<CellEntity?> getCellByAddress(String sheetId, String rowId, String columnId);
  Future<List<CellEntity>> getCellRange(String sheetId, CellRange range);
  Future<void> updateCell(CellEntity cell);
  Future<void> updateCells(List<CellEntity> cells);
  Future<void> deleteCell(String cellId);
  Stream<CellEntity> watchCell(String cellId);
}

// Implementation (Data Layer)
class CellRepositoryImpl implements CellRepository {
  final LocalDataSource localDataSource;
  final CellMapper cellMapper;
  final CellCache cache;
  
  @override
  Future<CellEntity?> getCellByAddress(
    String sheetId, 
    String rowId, 
    String columnId
  ) async {
    // Check cache first
    final cacheKey = '$sheetId:$rowId:$columnId';
    if (cache.contains(cacheKey)) {
      return cache.get(cacheKey);
    }
    
    // Query database
    final cellModel = await localDataSource.queryCell(
      sheetId, rowId, columnId
    );
    
    if (cellModel == null) return null;
    
    // Map to entity
    final entity = cellMapper.toEntity(cellModel);
    
    // Cache result
    cache.put(cacheKey, entity);
    
    return entity;
  }
  
  @override
  Future<void> updateCells(List<CellEntity> cells) async {
    // Map to models
    final models = cells.map(cellMapper.toModel).toList();
    
    // Batch update in database
    await localDataSource.batchUpdateCells(models);
    
    // Update cache
    for (final cell in cells) {
      cache.put(cell.address, cell);
    }
  }
  
  @override
  Stream<CellEntity> watchCell(String cellId) {
    return localDataSource.watchCell(cellId)
      .map(cellMapper.toEntity);
  }
}
```

#### Data Sources
```dart
// Local Data Source (SQLite)
class LocalDataSource {
  final Database database;
  
  Future<CellModel?> queryCell(
    String sheetId,
    String rowId, 
    String columnId
  ) async {
    final results = await database.query(
      'cells',
      where: 'sheet_id = ? AND row_id = ? AND column_id = ?',
      whereArgs: [sheetId, rowId, columnId],
    );
    
    if (results.isEmpty) return null;
    
    return CellModel.fromJson(results.first);
  }
  
  Future<void> batchUpdateCells(List<CellModel> cells) async {
    await database.transaction((txn) async {
      for (final cell in cells) {
        await txn.insert(
          'cells',
          cell.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
  
  Stream<CellModel> watchCell(String cellId) {
    return database.watch(
      'cells',
      where: 'cell_id = ?',
      whereArgs: [cellId],
    ).map((result) => CellModel.fromJson(result));
  }
}

// Remote Data Source (REST API)
class RemoteDataSource {
  final Dio httpClient;
  
  Future<APIResponse> fetchAPIData(APIEndpointConfig config) async {
    final response = await httpClient.request(
      config.url,
      options: Options(
        method: config.method,
        headers: _buildHeaders(config.authType, config.authCredentials),
      ),
      queryParameters: config.queryParams,
    );
    
    if (config.responseType == ResponseType.json) {
      return APIResponse.fromJson(response.data);
    } else {
      return APIResponse.fromXml(response.data);
    }
  }
}
```


### 3.4 Services Layer

#### Storage Service
```dart
class StorageService {
  final Database database;
  final CellCache cache;
  final AutoSaveQueue autoSaveQueue;
  
  // Initialize database
  Future<void> initialize() async {
    await _createTables();
    await _createIndexes();
  }
  
  // Auto-save mechanism
  void enableAutoSave() {
    Timer.periodic(
      Duration(seconds: AppConstants.autoSaveIntervalSeconds),
      (_) => _flushAutoSaveQueue(),
    );
  }
  
  Future<void> _flushAutoSaveQueue() async {
    if (autoSaveQueue.isEmpty) return;
    
    final pendingUpdates = autoSaveQueue.drain();
    
    await database.transaction((txn) async {
      for (final update in pendingUpdates) {
        await txn.insert(
          'cells',
          update.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
  
  // Cache management
  void evictCacheIfNeeded() {
    if (cache.sizeInBytes > AppConstants.maxCellCacheSizeMB * 1024 * 1024) {
      cache.evictLRU(count: 100);
    }
  }
}

// Cell Cache (LRU)
class CellCache {
  final Map<String, CellEntity> _cache = {};
  final LinkedHashMap<String, int> _accessOrder = LinkedHashMap();
  int _sizeInBytes = 0;
  
  bool contains(String key) => _cache.containsKey(key);
  
  CellEntity? get(String key) {
    if (!_cache.containsKey(key)) return null;
    
    // Update access time (LRU)
    _accessOrder.remove(key);
    _accessOrder[key] = DateTime.now().millisecondsSinceEpoch;
    
    return _cache[key];
  }
  
  void put(String key, CellEntity value) {
    _cache[key] = value;
    _accessOrder[key] = DateTime.now().millisecondsSinceEpoch;
    _sizeInBytes += _estimateSize(value);
  }
  
  void evictLRU({required int count}) {
    final keysToRemove = _accessOrder.keys.take(count).toList();
    for (final key in keysToRemove) {
      final cell = _cache.remove(key);
      _accessOrder.remove(key);
      if (cell != null) {
        _sizeInBytes -= _estimateSize(cell);
      }
    }
  }
  
  int _estimateSize(CellEntity cell) {
    // Rough estimation: object overhead + strings
    return 100 + (cell.value?.length ?? 0) + (cell.formula?.length ?? 0);
  }
  
  int get sizeInBytes => _sizeInBytes;
}
```

#### Formula Service
```dart
class FormulaService {
  final FormulaParser parser;
  final FormulaEvaluator evaluator;
  final FormulaCompiler gpuCompiler;
  final DependencyGraph dependencyGraph;
  
  // Parse formula string to AST
  FormulaResult parseFormula(String formulaString) {
    try {
      // Tokenize
      final tokens = parser.tokenize(formulaString);
      
      // Build AST
      final ast = parser.buildAST(tokens);
      
      // Validate
      parser.validate(ast);
      
      return FormulaResult.success(ast);
    } on FormulaError catch (e) {
      return FormulaResult.error(e.message);
    }
  }
  
  // Evaluate formula
  Future<dynamic> evaluateFormula(
    FormulaAST ast,
    EvaluationContext context,
  ) async {
    // Check if should use GPU
    if (await _shouldUseGPU(ast, context)) {
      return _evaluateOnGPU(ast, context);
    } else {
      return _evaluateOnCPU(ast, context);
    }
  }
  
  Future<bool> _shouldUseGPU(FormulaAST ast, EvaluationContext context) async {
    // Check Vulkan availability
    if (!await VulkanSupport.isAvailable()) return false;
    
    // Check if formula involves large range
    final rangeSize = ast.getRangeSize();
    if (rangeSize < AppConstants.minCellsForGPUCompute) return false;
    
    // Check if formula is GPU-compatible
    return ast.isGPUCompatible();
  }
  
  Future<dynamic> _evaluateOnGPU(FormulaAST ast, EvaluationContext context) async {
    // Compile to GPU shader
    final shader = gpuCompiler.compile(ast);
    
    // Get input data
    final inputData = await _prepareInputData(ast, context);
    
    // Execute on GPU
    final result = await NativeRenderEngine.computeFormula(
      shader.spirvCode,
      inputData,
    );
    
    return result;
  }
  
  dynamic _evaluateOnCPU(FormulaAST ast, EvaluationContext context) {
    return evaluator.evaluate(ast, context);
  }
  
  // Track dependencies
  void addDependency(String cellAddress, List<String> dependsOn) {
    dependencyGraph.addNode(cellAddress);
    for (final dep in dependsOn) {
      dependencyGraph.addEdge(dep, cellAddress);
    }
  }
  
  // Recalculate dependents
  Future<void> recalculateDependents(String cellAddress) async {
    // Get all cells that depend on this cell
    final dependents = dependencyGraph.getDependents(cellAddress);
    
    // Topological sort for correct order
    final sortedDependents = dependencyGraph.topologicalSort(dependents);
    
    // Recalculate in order
    for (final dependent in sortedDependents) {
      await _recalculateCell(dependent);
    }
  }
}
```


#### Native Rendering Service
```dart
class NativeRenderingService {
  late int _enginePtr;
  bool _initialized = false;
  
  // Initialize Vulkan engine
  Future<bool> initialize(Surface surface) async {
    try {
      _enginePtr = await _createEngine(surface);
      _initialized = true;
      
      final vulkanSupported = await _isVulkanSupported(_enginePtr);
      
      if (vulkanSupported) {
        print('✓ Vulkan Graphics: ENABLED');
        print('✓ GPU Acceleration: ACTIVE');
      } else {
        print('⚠ Vulkan not supported, using CPU fallback');
      }
      
      return vulkanSupported;
    } catch (e) {
      print('Failed to initialize Vulkan: $e');
      return false;
    }
  }
  
  // Render frame
  void renderFrame(List<CellData> visibleCells) {
    if (!_initialized) return;
    
    // Convert to native format
    final cellFloats = Float32List.fromList(
      visibleCells.expand((cell) => [
        cell.x,
        cell.y,
        cell.width,
        cell.height,
        cell.bgColor.r,
        cell.bgColor.g,
        cell.bgColor.b,
        cell.bgColor.a,
        cell.textureIndex.toDouble(),
      ]).toList(),
    );
    
    _renderFrame(_enginePtr, cellFloats);
  }
  
  // Update viewport
  void updateViewport(double scrollX, double scrollY, double zoom) {
    if (!_initialized) return;
    _setViewport(_enginePtr, scrollX, scrollY, zoom);
  }
  
  // GPU compute for formulas
  Future<double> computeFormula(
    String formula,
    Float32List inputData,
  ) async {
    if (!_initialized) {
      throw Exception('Rendering engine not initialized');
    }
    
    return await _computeFormula(_enginePtr, formula, inputData);
  }
  
  // Cleanup
  void dispose() {
    if (_initialized) {
      _destroyEngine(_enginePtr);
      _initialized = false;
    }
  }
  
  // Native methods (FFI)
  external int _createEngine(Surface surface);
  external bool _isVulkanSupported(int enginePtr);
  external void _renderFrame(int enginePtr, Float32List cellData);
  external void _setViewport(int enginePtr, double x, double y, double zoom);
  external Future<double> _computeFormula(
    int enginePtr,
    String formula,
    Float32List data,
  );
  external void _destroyEngine(int enginePtr);
}
```

### 3.5 Native Layer (C++ / NDK)

#### Custom Render Engine Class
```cpp
// custom_render_engine.h
class CustomRenderEngine {
private:
    // Vulkan components
    VkInstance instance;
    VkPhysicalDevice physicalDevice;
    VkDevice device;
    VkQueue graphicsQueue;
    VkQueue computeQueue;
    VkQueue transferQueue;
    VkSwapchainKHR swapchain;
    
    // Rendering components
    VirtualViewport viewport;
    CellBatchRenderer cellRenderer;
    TextureAtlas textAtlas;
    CommandBufferPool commandPool;
    DescriptorSetPool descriptorPool;
    
    // Compute components
    FormulaCompiler formulaCompiler;
    ComputeShaderExecutor computeExecutor;
    
    // Memory management
    GPUMemoryAllocator memoryAllocator;
    
    // Performance tracking
    FrameStats stats;
    
public:
    CustomRenderEngine();
    ~CustomRenderEngine();
    
    bool initialize(ANativeWindow* surface);
    void renderFrame(const std::vector<CellInstance>& cells);
    void updateViewport(float scrollX, float scrollY, float zoom);
    float executeFormula(const char* formula, const float* data, size_t dataSize);
    void cleanup();
    
private:
    bool createVulkanInstance();
    bool selectPhysicalDevice();
    bool createLogicalDevice();
    bool createSwapchain(ANativeWindow* surface);
    bool createRenderingPipeline();
    bool createComputePipeline();
};

// Implementation highlights
bool CustomRenderEngine::renderFrame(const std::vector<CellInstance>& cells) {
    // Calculate visible cells
    auto visibleCells = viewport.getVisibleCells(scrollX, scrollY, zoom);
    
    // Prepare instance data
    std::vector<CellInstance> instances;
    for (const auto& cell : visibleCells) {
        instances.push_back({
            .position = {cell.x, cell.y},
            .size = {cell.width, cell.height},
            .bgColor = cell.backgroundColor,
            .textureIndex = cell.textTextureIndex,
        });
    }
    
    // Upload to GPU
    cellRenderer.uploadInstances(instances);
    
    // Record command buffer
    VkCommandBuffer cmd = commandPool.acquireBuffer();
    vkBeginCommandBuffer(cmd, &beginInfo);
    
    // Render pass
    vkCmdBeginRenderPass(cmd, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);
    
    // Draw cells (single draw call)
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, cellPipeline);
    vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, 
                            pipelineLayout, 0, 1, &textAtlas.descriptorSet, 0, nullptr);
    vkCmdDrawIndexedIndirect(cmd, instanceBuffer, 0, instances.size(), 
                             sizeof(CellInstance));
    
    // Draw grid lines (shader-based)
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, gridPipeline);
    vkCmdDraw(cmd, 4, 1, 0, 0);  // Full-screen quad
    
    vkCmdEndRenderPass(cmd);
    vkEndCommandBuffer(cmd);
    
    // Submit
    vkQueueSubmit(graphicsQueue, 1, &submitInfo, fence);
    
    // Present
    vkQueuePresentKHR(graphicsQueue, &presentInfo);
    
    // Track stats
    stats.recordFrame();
    
    return true;
}

float CustomRenderEngine::executeFormula(
    const char* formula, 
    const float* data, 
    size_t dataSize
) {
    // Compile formula to compute shader
    auto shader = formulaCompiler.compile(formula);
    
    // Create GPU buffers
    VkBuffer inputBuffer = createBuffer(
        dataSize * sizeof(float),
        VK_BUFFER_USAGE_STORAGE_BUFFER_BIT
    );
    VkBuffer outputBuffer = createBuffer(
        sizeof(float),
        VK_BUFFER_USAGE_STORAGE_BUFFER_BIT
    );
    
    // Upload data
    uploadData(inputBuffer, data, dataSize);
    
    // Execute compute shader
    computeExecutor.execute(shader, inputBuffer, outputBuffer, dataSize);
    
    // Read result
    float result;
    downloadData(outputBuffer, &result, sizeof(float));
    
    return result;
}
```


---

## 4. Database Schema Design

### 4.1 SQLite Tables

```sql
-- Spreadsheets (top-level documents)
CREATE TABLE spreadsheets (
    spreadsheet_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    thumbnail_path TEXT,
    file_size INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    last_opened INTEGER NOT NULL
);

CREATE INDEX idx_spreadsheets_modified ON spreadsheets(modified_at DESC);
CREATE INDEX idx_spreadsheets_name ON spreadsheets(name COLLATE NOCASE);

-- Sheets (tabs within spreadsheet)
CREATE TABLE sheets (
    sheet_id TEXT PRIMARY KEY,
    spreadsheet_id TEXT NOT NULL,
    sheet_name TEXT NOT NULL,
    sheet_order INTEGER NOT NULL,
    row_count INTEGER DEFAULT 1000,
    column_count INTEGER DEFAULT 26,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    FOREIGN KEY (spreadsheet_id) REFERENCES spreadsheets(spreadsheet_id) ON DELETE CASCADE
);

CREATE INDEX idx_sheets_spreadsheet ON sheets(spreadsheet_id, sheet_order);

-- Rows (persistent row tracking)
CREATE TABLE rows (
    row_id TEXT PRIMARY KEY,
    sheet_id TEXT NOT NULL,
    row_number INTEGER NOT NULL,
    height REAL DEFAULT 52.0,
    visible INTEGER DEFAULT 1,
    format_json TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_rows_sheet_number ON rows(sheet_id, row_number);
CREATE INDEX idx_rows_sheet ON rows(sheet_id);

-- Columns (persistent column tracking)
CREATE TABLE columns (
    column_id TEXT PRIMARY KEY,
    sheet_id TEXT NOT NULL,
    column_name TEXT NOT NULL,
    column_number INTEGER NOT NULL,
    column_type TEXT DEFAULT 'text',
    width REAL DEFAULT 120.0,
    visible INTEGER DEFAULT 1,
    format_json TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_columns_sheet_number ON columns(sheet_id, column_number);
CREATE INDEX idx_columns_sheet ON columns(sheet_id);

-- Cells (sparse storage - only non-empty cells)
CREATE TABLE cells (
    cell_id TEXT PRIMARY KEY,
    sheet_id TEXT NOT NULL,
    row_id TEXT NOT NULL,
    column_id TEXT NOT NULL,
    value TEXT,
    formula TEXT,
    data_type TEXT DEFAULT 'text',
    format_json TEXT,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE,
    FOREIGN KEY (row_id) REFERENCES rows(row_id) ON DELETE CASCADE,
    FOREIGN KEY (column_id) REFERENCES columns(column_id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_cells_address ON cells(sheet_id, row_id, column_id);
CREATE INDEX idx_cells_sheet ON cells(sheet_id);
CREATE INDEX idx_cells_row ON cells(row_id);
CREATE INDEX idx_cells_column ON cells(column_id);

-- Formula Dependencies
CREATE TABLE formula_dependencies (
    dependent_cell_id TEXT NOT NULL,
    referenced_cell_id TEXT NOT NULL,
    PRIMARY KEY (dependent_cell_id, referenced_cell_id),
    FOREIGN KEY (dependent_cell_id) REFERENCES cells(cell_id) ON DELETE CASCADE,
    FOREIGN KEY (referenced_cell_id) REFERENCES cells(cell_id) ON DELETE CASCADE
);

CREATE INDEX idx_dependencies_referenced ON formula_dependencies(referenced_cell_id);

-- API Endpoints (REST API configurations)
CREATE TABLE api_endpoints (
    endpoint_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    method TEXT DEFAULT 'GET',
    auth_type TEXT,
    auth_credentials TEXT,
    query_params_json TEXT,
    field_mapping_json TEXT,
    auto_refresh_interval INTEGER,
    last_sync INTEGER,
    created_at INTEGER NOT NULL
);

-- Google Forms (Forms integration)
CREATE TABLE google_forms (
    form_id TEXT PRIMARY KEY,
    form_title TEXT NOT NULL,
    sheet_id TEXT NOT NULL,
    field_mapping_json TEXT,
    auto_sync_enabled INTEGER DEFAULT 0,
    sync_interval INTEGER DEFAULT 900,
    last_sync INTEGER,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

-- Undo/Redo History
CREATE TABLE command_history (
    command_id TEXT PRIMARY KEY,
    sheet_id TEXT NOT NULL,
    command_type TEXT NOT NULL,
    command_data_json TEXT NOT NULL,
    executed_at INTEGER NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

CREATE INDEX idx_command_history_sheet ON command_history(sheet_id, executed_at DESC);
```

### 4.2 Data Access Patterns

```sql
-- Get cell by address (most common query)
SELECT c.* 
FROM cells c
WHERE c.sheet_id = ? 
  AND c.row_id = ? 
  AND c.column_id = ?;

-- Get visible cells in range (for rendering)
SELECT c.*
FROM cells c
INNER JOIN rows r ON c.row_id = r.row_id
INNER JOIN columns col ON c.column_id = col.column_id
WHERE c.sheet_id = ?
  AND r.row_number BETWEEN ? AND ?
  AND col.column_number BETWEEN ? AND ?
  AND r.visible = 1
  AND col.visible = 1;

-- Get all formulas in sheet (for recalculation)
SELECT cell_id, formula
FROM cells
WHERE sheet_id = ? AND formula IS NOT NULL;

-- Get formula dependencies
SELECT fd.referenced_cell_id
FROM formula_dependencies fd
WHERE fd.dependent_cell_id = ?;

-- Get dependents of a cell
SELECT fd.dependent_cell_id
FROM formula_dependencies fd
WHERE fd.referenced_cell_id = ?;
```

---

## 5. State Management Design

### 5.1 Provider Architecture

```dart
// Root Provider Setup
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
        Provider<FormulaService>(
          create: (_) => FormulaService(),
        ),
        Provider<NativeRenderingService>(
          create: (_) => NativeRenderingService(),
        ),
        
        // Repositories
        ProxyProvider<StorageService, CellRepository>(
          update: (_, storage, __) => CellRepositoryImpl(storage),
        ),
        ProxyProvider<StorageService, SheetRepository>(
          update: (_, storage, __) => SheetRepositoryImpl(storage),
        ),
        
        // Use Cases
        ProxyProvider2<CellRepository, FormulaService, CellOperationsUseCase>(
          update: (_, cellRepo, formulaService, __) =>
              CellOperationsUseCase(cellRepo, formulaService),
        ),
        
        // Controllers
        ChangeNotifierProvider<HomeController>(
          create: (context) => HomeController(
            context.read<SheetRepository>(),
          ),
        ),
        
        ChangeNotifierProxyProvider<CellOperationsUseCase, EditorController>(
          create: (context) => EditorController(
            context.read<CellOperationsUseCase>(),
            context.read<NativeRenderingService>(),
          ),
          update: (_, cellOps, editor) =>
              editor?..updateUseCase(cellOps) ?? EditorController(cellOps, null),
        ),
      ],
      child: MyApp(),
    ),
  );
}

// Editor Controller (Reactive State)
class EditorController extends ChangeNotifier {
  final CellOperationsUseCase _cellOperations;
  final NativeRenderingService _renderingService;
  
  SheetEntity? _currentSheet;
  List<CellPosition> _selectedCells = [];
  CellEntity? _editingCell;
  double _scrollX = 0.0;
  double _scrollY = 0.0;
  double _zoom = 1.0;
  
  // Command pattern for undo/redo
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];
  
  // Getters
  SheetEntity? get currentSheet => _currentSheet;
  List<CellPosition> get selectedCells => _selectedCells;
  CellEntity? get editingCell => _editingCell;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  
  // Select cell
  Future<void> selectCell(CellPosition position) async {
    _selectedCells = [position];
    
    // Update viewport
    _renderingService.updateViewport(_scrollX, _scrollY, _zoom);
    
    notifyListeners();
  }
  
  // Edit cell
  Future<void> editCell(CellEntity cell, String newValue) async {
    final command = EditCellCommand(
      cellId: cell.cellId,
      oldValue: cell.value,
      newValue: newValue,
      cellOperations: _cellOperations,
    );
    
    await command.execute();
    _undoStack.add(command);
    _redoStack.clear();
    
    notifyListeners();
  }
  
  // Undo
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    
    final command = _undoStack.removeLast();
    await command.undo();
    _redoStack.add(command);
    
    notifyListeners();
  }
  
  // Redo
  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    
    final command = _redoStack.removeLast();
    await command.execute();
    _undoStack.add(command);
    
    notifyListeners();
  }
  
  // Update viewport
  void updateViewport(double scrollX, double scrollY, double zoom) {
    _scrollX = scrollX;
    _scrollY = scrollY;
    _zoom = zoom;
    
    _renderingService.updateViewport(scrollX, scrollY, zoom);
    
    // No need to notify listeners - rendering is immediate
  }
}
```


### 5.2 Command Pattern for Undo/Redo

```dart
// Command interface
abstract class Command {
  Future<void> execute();
  Future<void> undo();
  String get description;
}

// Edit Cell Command
class EditCellCommand implements Command {
  final String cellId;
  final String? oldValue;
  final String newValue;
  final CellOperationsUseCase cellOperations;
  
  EditCellCommand({
    required this.cellId,
    required this.oldValue,
    required this.newValue,
    required this.cellOperations,
  });
  
  @override
  Future<void> execute() async {
    await cellOperations.setCellValue(cellId, newValue);
  }
  
  @override
  Future<void> undo() async {
    await cellOperations.setCellValue(cellId, oldValue);
  }
  
  @override
  String get description => 'Edit cell';
}

// Format Cells Command
class FormatCellsCommand implements Command {
  final List<String> cellIds;
  final Map<String, CellFormat?> oldFormats;
  final CellFormat newFormat;
  final CellOperationsUseCase cellOperations;
  
  @override
  Future<void> execute() async {
    for (final cellId in cellIds) {
      await cellOperations.applyCellFormatting(cellId, newFormat);
    }
  }
  
  @override
  Future<void> undo() async {
    for (final cellId in cellIds) {
      final oldFormat = oldFormats[cellId];
      if (oldFormat != null) {
        await cellOperations.applyCellFormatting(cellId, oldFormat);
      }
    }
  }
  
  @override
  String get description => 'Format ${cellIds.length} cell(s)';
}

// Insert Row Command
class InsertRowCommand implements Command {
  final String sheetId;
  final int rowIndex;
  final SheetManagementUseCase sheetManagement;
  String? insertedRowId;
  
  @override
  Future<void> execute() async {
    insertedRowId = await sheetManagement.insertRowAt(sheetId, rowIndex);
  }
  
  @override
  Future<void> undo() async {
    if (insertedRowId != null) {
      await sheetManagement.deleteRow(insertedRowId!);
    }
  }
  
  @override
  String get description => 'Insert row';
}
```

---

## 6. Performance Optimization Strategy

### 6.1 Rendering Performance

```
Target: 60 FPS (16.67ms per frame)

Frame Budget Allocation:
┌─────────────────────────────────┐
│ Virtual Viewport Calc:  0.5ms   │  3%
│ Cell Culling:           0.3ms   │  2%
│ Instance Data Upload:   1.0ms   │  6%
│ GPU Rendering:          8.0ms   │  48%
│ Text Rendering:         2.0ms   │  12%
│ UI Overlay:             1.0ms   │  6%
│ Swapchain Present:      1.0ms   │  6%
│ Slack Time:             2.87ms  │  17%
└─────────────────────────────────┘
Total:                    16.67ms

Key Optimizations:
1. Virtual Viewport: Only render ~50-100 visible cells
2. Batch Rendering: Single draw call for all cells
3. Texture Atlas: Pre-rendered text glyphs
4. Command Buffer Reuse: No per-frame allocation
5. Descriptor Pooling: Reuse descriptor sets
6. Memory Aliasing: Share GPU memory blocks
7. Async Transfers: Upload without blocking render
```

### 6.2 Formula Calculation Performance

```
CPU vs GPU Performance:

┌──────────────────┬──────────┬──────────┬─────────┐
│ Operation        │ CPU Time │ GPU Time │ Speedup │
├──────────────────┼──────────┼──────────┼─────────┤
│ SUM(10K cells)   │ 50ms     │ 5ms      │ 10x     │
│ AVERAGE(10K)     │ 50ms     │ 5ms      │ 10x     │
│ Matrix 100×100   │ 500ms    │ 20ms     │ 25x     │
│ Complex Formula  │ 200ms    │ 15ms     │ 13x     │
└──────────────────┴──────────┴──────────┴─────────┘

GPU Compute Strategy:
1. Threshold: Use GPU if range > 1000 cells
2. Parallel Reduction: Tree-based aggregation
3. Shared Memory: 32-thread work groups
4. Async Execution: Don't block UI thread
5. Batch Processing: Multiple formulas in parallel
```

### 6.3 Memory Management

```
Memory Budget:
┌─────────────────────────────┐
│ GPU Memory (Total: 41 MB)   │
├─────────────────────────────┤
│ Vertex Buffers:      4 MB   │
│ Instance Buffers:    2 MB   │
│ Texture Atlas:      16 MB   │
│ Uniform Buffers:     1 MB   │
│ Staging Buffers:     8 MB   │
│ Compute Buffers:    10 MB   │
└─────────────────────────────┘

┌─────────────────────────────┐
│ CPU Memory (Cell Cache)     │
├─────────────────────────────┤
│ Max Cache Size:     50 MB   │
│ Cached Cells:      ~500     │
│ Eviction Policy:    LRU     │
│ Cache Hit Rate:     >90%    │
└─────────────────────────────┘

Cache Strategy:
1. Recently accessed cells stay in cache
2. LRU eviction when cache exceeds 50 MB
3. Prefetch adjacent cells during scroll
4. Cache both cell data and rendered textures
```

### 6.4 Database Performance

```
Query Optimization:
1. UUID-based indexes on all lookups
2. Composite index: (sheet_id, row_id, column_id)
3. Sparse storage: Only non-empty cells stored
4. Batch transactions: Group updates every 30s
5. Prepared statements: Reuse query plans
6. Connection pooling: Single shared connection

Estimated Query Times:
┌─────────────────────────────────┬──────────┐
│ Query Type                      │ Time     │
├─────────────────────────────────┼──────────┤
│ Get cell by address             │ <1ms     │
│ Get cell range (100 cells)      │ <5ms     │
│ Get all formulas in sheet       │ <10ms    │
│ Batch update (100 cells)        │ <20ms    │
│ Full sheet load (1000 cells)    │ <50ms    │
└─────────────────────────────────┴──────────┘
```

---

## 7. Threading Model

```
Thread Architecture:

┌────────────────────────────────────────┐
│           Main UI Thread               │
│  • Flutter widgets                     │
│  • User input handling                 │
│  • State management                    │
│  • UI updates (notifyListeners)        │
└──────┬──────────────────────┬──────────┘
       │                      │
       ▼                      ▼
┌────────────────┐    ┌──────────────────┐
│ Compute Thread │    │  I/O Thread      │
│  • Formula     │    │  • Database      │
│    parsing     │    │    queries       │
│  • Heavy       │    │  • File I/O      │
│    calculations│    │  • Network       │
│  • Data        │    │    requests      │
│    processing  │    │                  │
└──────┬─────────┘    └──────┬───────────┘
       │                     │
       │                     │
       ▼                     │
┌─────────────────────────────┴──────────┐
│      Native Thread (C++ / NDK)         │
│  • Vulkan rendering                    │
│  • GPU command submission              │
│  • Compute shader execution            │
│  • Memory management                   │
└────────────────────────────────────────┘

Thread Communication:
• UI → Compute: Isolates + SendPort
• UI → Native: FFI / JNI
• Compute → Native: Direct calls (isolates)
• All → UI: Streams / Future callbacks
```

---

## 8. Error Handling Strategy

### 8.1 Formula Errors

```dart
enum FormulaErrorType {
  syntaxError,      // Invalid formula syntax
  referenceError,   // Invalid cell reference
  circularError,    // Circular dependency detected
  valueError,       // Wrong data type
  divideByZero,     // Division by zero
  overflow,         // Numeric overflow
}

class FormulaError {
  final FormulaErrorType type;
  final String message;
  final int? position;  // Error position in formula
  
  String get displayMessage {
    switch (type) {
      case FormulaErrorType.syntaxError:
        return '#SYNTAX!';
      case FormulaErrorType.referenceError:
        return '#REF!';
      case FormulaErrorType.circularError:
        return '#CIRCULAR!';
      case FormulaErrorType.valueError:
        return '#VALUE!';
      case FormulaErrorType.divideByZero:
        return '#DIV/0!';
      case FormulaErrorType.overflow:
        return '#NUM!';
    }
  }
}
```

### 8.2 GPU Fallback Strategy

```dart
class GPUFallbackHandler {
  bool _vulkanAvailable = false;
  bool _gpuComputeAvailable = false;
  
  Future<void> initialize() async {
    try {
      _vulkanAvailable = await NativeRenderingService.checkVulkanSupport();
      _gpuComputeAvailable = await NativeRenderingService.checkComputeSupport();
      
      if (!_vulkanAvailable) {
        _showNotification('GPU acceleration not available. Using CPU rendering.');
      }
    } catch (e) {
      _vulkanAvailable = false;
      _gpuComputeAvailable = false;
      _showNotification('Failed to initialize GPU. Using CPU fallback.');
    }
  }
  
  RenderMode get renderMode {
    return _vulkanAvailable ? RenderMode.gpu : RenderMode.cpu;
  }
  
  ComputeMode get computeMode {
    return _gpuComputeAvailable ? ComputeMode.gpu : ComputeMode.cpu;
  }
}
```

### 8.3 Database Error Recovery

```dart
class DatabaseErrorHandler {
  Future<void> handleError(Object error, StackTrace stackTrace) async {
    if (error is SqliteException) {
      switch (error.extendedResultCode) {
        case 11: // SQLITE_CORRUPT
          await _attemptDatabaseRepair();
          break;
        case 13: // SQLITE_FULL
          await _showDiskFullError();
          break;
        case 5: // SQLITE_BUSY
          await _retryTransaction();
          break;
        default:
          await _logError(error, stackTrace);
      }
    }
  }
  
  Future<void> _attemptDatabaseRepair() async {
    try {
      // Try to recover from backup
      await restoreFromBackup();
    } catch (e) {
      // Show user error and offer to create new file
      await _showRecoveryDialog();
    }
  }
}
```

---

## 9. API Contracts

### 9.1 Native Rendering Engine (JNI/FFI)

```cpp
// JNI Interface
extern "C" {
    // Initialization
    JNIEXPORT jlong JNICALL
    Java_RenderEngine_createEngine(JNIEnv* env, jobject obj, jobject surface);
    
    JNIEXPORT jboolean JNICALL
    Java_RenderEngine_initializeVulkan(JNIEnv* env, jobject obj, jlong enginePtr);
    
    // Rendering
    JNIEXPORT void JNICALL
    Java_RenderEngine_renderFrame(
        JNIEnv* env, jobject obj, 
        jlong enginePtr, 
        jfloatArray cellData
    );
    
    JNIEXPORT void JNICALL
    Java_RenderEngine_setViewport(
        JNIEnv* env, jobject obj,
        jlong enginePtr,
        jfloat scrollX, jfloat scrollY, jfloat zoom
    );
    
    // Compute
    JNIEXPORT jfloat JNICALL
    Java_RenderEngine_computeFormula(
        JNIEnv* env, jobject obj,
        jlong enginePtr,
        jstring formula,
        jfloatArray inputData
    );
    
    // Cleanup
    JNIEXPORT void JNICALL
    Java_RenderEngine_destroyEngine(JNIEnv* env, jobject obj, jlong enginePtr);
}
```



### 9.2 AI Agent API Contract

```dart
/// AI Agent REST API (exposed on localhost:8080)
class AIAgentAPI {
  
  /// GET /api/v1/cell/{sheetId}/{rowId}/{columnId}
  /// Returns single cell value
  Future<Response> getCellValue(
    String sheetId,
    String rowId,
    String columnId,
  ) async {
    return Response.json({
      'cellId': '...',
      'sheetId': sheetId,
      'rowId': rowId,
      'columnId': columnId,
      'value': '...',
      'dataType': 'TEXT',
      'formula': null,
    });
  }
  
  /// PUT /api/v1/cell/{sheetId}/{rowId}/{columnId}
  /// Sets single cell value
  Future<Response> setCellValue(
    String sheetId,
    String rowId,
    String columnId,
    String value,
  ) async {
    return Response.json({
      'success': true,
      'cellId': '...',
      'updatedValue': value,
    });
  }
  
  /// GET /api/v1/row/{sheetId}/{rowId}
  /// Returns all cells in a row
  Future<Response> getRowData(String sheetId, String rowId) async {
    return Response.json({
      'rowId': rowId,
      'cells': [
        {'columnId': '...', 'value': '...'},
      ],
    });
  }
  
  /// GET /api/v1/column/{sheetId}/{columnId}
  /// Returns all cells in a column
  Future<Response> getColumnData(String sheetId, String columnId) async {
    return Response.json({
      'columnId': columnId,
      'cells': [
        {'rowId': '...', 'value': '...'},
      ],
    });
  }
  
  /// GET /api/v1/range/{sheetId}?start={cellAddress}&end={cellAddress}
  /// Returns cell range (e.g., A1:C10)
  Future<Response> getRangeData(
    String sheetId,
    String startAddress,
    String endAddress,
  ) async {
    return Response.json({
      'sheetId': sheetId,
      'range': '$startAddress:$endAddress',
      'cells': [
        {'address': 'A1', 'value': '...'},
      ],
    });
  }
  
  /// POST /api/v1/row/{sheetId}
  /// Appends new row
  Future<Response> appendRow(String sheetId, Map<String, dynamic> rowData) async {
    return Response.json({
      'success': true,
      'rowId': '...',
      'insertedAt': 'ISO8601 timestamp',
    });
  }
  
  /// PUT /api/v1/row/{sheetId}/{rowId}
  /// Updates existing row
  Future<Response> updateRow(
    String sheetId,
    String rowId,
    Map<String, dynamic> rowData,
  ) async {
    return Response.json({
      'success': true,
      'rowId': rowId,
      'updatedFields': rowData.keys.toList(),
    });
  }
  
  /// DELETE /api/v1/row/{sheetId}/{rowId}
  /// Deletes row
  Future<Response> deleteRow(String sheetId, String rowId) async {
    return Response.json({
      'success': true,
      'deletedRowId': rowId,
    });
  }
  
  /// POST /api/v1/query/{sheetId}
  /// Query data with filters
  Future<Response> queryData(String sheetId, QueryFilter filter) async {
    return Response.json({
      'results': [
        {'rowId': '...', 'cells': []},
      ],
      'count': 10,
    });
  }
  
  /// GET /api/v1/structure/{sheetId}
  /// Returns sheet structure (columns, rows)
  Future<Response> getSheetStructure(String sheetId) async {
    return Response.json({
      'sheetId': sheetId,
      'columns': [
        {'columnId': '...', 'name': 'A', 'type': 'TEXT', 'width': 120},
      ],
      'rows': [
        {'rowId': '...', 'number': 1, 'height': 52},
      ],
      'totalRows': 1000,
      'totalColumns': 26,
    });
  }
  
  /// GET /api/v1/dependencies/{sheetId}
  /// Returns formula dependency graph
  Future<Response> getFormulaDependencies(String sheetId) async {
    return Response.json({
      'dependencies': [
        {
          'cellId': '...',
          'formula': '=SUM(A1:A10)',
          'dependsOn': ['A1', 'A2', '...', 'A10'],
        },
      ],
    });
  }
  
  /// GET /api/v1/validation/{sheetId}/{columnId}
  /// Returns validation rules for column
  Future<Response> getValidationRules(String sheetId, String columnId) async {
    return Response.json({
      'columnId': columnId,
      'rules': [
        {
          'type': 'NUMBER_RANGE',
          'min': 0,
          'max': 100,
          'errorMessage': 'Value must be between 0 and 100',
        },
      ],
    });
  }
}
```


### 9.3 Google Forms API Integration

```dart
class GoogleFormsIntegration {
  final GoogleSignIn googleSignIn;
  final Dio httpClient;
  
  /// Authenticate with Google OAuth 2.0
  Future<GoogleSignInAccount?> authenticate() async {
    try {
      return await googleSignIn.signIn();
    } catch (error) {
      print('Google Sign-In error: $error');
      return null;
    }
  }
  
  /// Fetch user's Google Forms
  Future<List<GoogleFormMetadata>> getForms(String accessToken) async {
    final response = await httpClient.get(
      'https://forms.googleapis.com/v1/forms',
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    
    return (response.data['forms'] as List)
        .map((f) => GoogleFormMetadata.fromJson(f))
        .toList();
  }
  
  /// Fetch form responses
  Future<List<FormResponse>> getFormResponses(
    String formId,
    String accessToken,
  ) async {
    final response = await httpClient.get(
      'https://forms.googleapis.com/v1/forms/$formId/responses',
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    
    return (response.data['responses'] as List)
        .map((r) => FormResponse.fromJson(r))
        .toList();
  }
  
  /// Map form responses to spreadsheet
  Future<SheetEntity> mapFormToSheet(
    String formId,
    List<FormResponse> responses,
  ) async {
    // Create sheet
    final sheet = await createSheet('Form: $formId');
    
    // Extract questions as column headers
    final questions = responses.first.answers.keys.toList();
    for (int i = 0; i < questions.length; i++) {
      await createColumn(sheet.sheetId, questions[i], i);
    }
    
    // Insert response data as rows
    for (int i = 0; i < responses.length; i++) {
      final response = responses[i];
      for (int j = 0; j < questions.length; j++) {
        final question = questions[j];
        final answer = response.answers[question];
        await setCellValue(
          sheet.sheetId,
          getRowId(i),
          getColumnId(j),
          answer,
        );
      }
    }
    
    return sheet;
  }
  
  /// Auto-sync with Google Forms (real-time updates)
  Stream<FormResponse> watchFormResponses(
    String formId,
    String accessToken,
  ) async* {
    // Use Google Forms Push Notifications API
    await _setupPushNotifications(formId, accessToken);
    
    // Listen for webhook events
    yield* _webhookStream;
  }
}
```

### 9.4 REST API Integration Interface

```dart
class RestAPIIntegration {
  final Dio httpClient;
  
  /// Test API endpoint connectivity
  Future<bool> testConnection(APIEndpointConfig config) async {
    try {
      final response = await httpClient.request(
        config.url,
        options: Options(
          method: config.method,
          headers: _buildHeaders(config),
          validateStatus: (status) => status! < 500,
        ),
      );
      
      return response.statusCode! >= 200 && response.statusCode! < 400;
    } catch (e) {
      return false;
    }
  }
  
  /// Fetch data from REST API
  Future<APIResponse> fetchData(APIEndpointConfig config) async {
    final response = await httpClient.request(
      config.url,
      options: Options(
        method: config.method,
        headers: _buildHeaders(config),
      ),
      queryParameters: config.queryParams,
      data: config.body,
    );
    
    if (config.responseType == ResponseType.json) {
      return APIResponse.fromJson(response.data);
    } else if (config.responseType == ResponseType.xml) {
      return APIResponse.fromXml(response.data);
    } else {
      throw UnsupportedError('Unsupported response type');
    }
  }
  
  /// Map API fields to spreadsheet columns
  Future<FieldMapping> autoMapFields(
    Map<String, dynamic> sampleData,
  ) async {
    final mapping = <String, ColumnMapping>{};
    
    for (final entry in sampleData.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Auto-detect column type
      final columnType = _detectColumnType(value);
      
      mapping[key] = ColumnMapping(
        apiField: key,
        columnName: _humanize(key),
        columnType: columnType,
      );
    }
    
    return FieldMapping(mappings: mapping);
  }
  
  ColumnType _detectColumnType(dynamic value) {
    if (value is int || value is double) return ColumnType.amount;
    if (value is bool) return ColumnType.checkbox;
    if (value is String) {
      if (_isDateString(value)) return ColumnType.date;
      if (_isUrlString(value)) return ColumnType.link;
      if (_isEmailString(value)) return ColumnType.text;
    }
    return ColumnType.text;
  }
  
  Map<String, String> _buildHeaders(APIEndpointConfig config) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    switch (config.authType) {
      case AuthType.none:
        break;
      case AuthType.apiKey:
        headers[config.apiKeyHeader!] = config.apiKey!;
        break;
      case AuthType.bearer:
        headers['Authorization'] = 'Bearer ${config.bearerToken}';
        break;
      case AuthType.basic:
        final credentials = base64Encode(
          utf8.encode('${config.username}:${config.password}'),
        );
        headers['Authorization'] = 'Basic $credentials';
        break;
    }
    
    return headers;
  }
}
```

---

## 10. Security Considerations

### 10.1 Data Security

```dart
class SecurityManager {
  /// Encrypt sensitive data before storage
  Future<String> encryptData(String plaintext) async {
    final key = await _getEncryptionKey();
    final iv = _generateIV();
    
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    
    return '${iv.base64}:${encrypted.base64}';
  }
  
  /// Decrypt sensitive data after retrieval
  Future<String> decryptData(String ciphertext) async {
    final parts = ciphertext.split(':');
    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    
    final key = await _getEncryptionKey();
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    
    return encrypter.decrypt(encrypted, iv: iv);
  }
  
  /// Get encryption key from Android Keystore
  Future<Key> _getEncryptionKey() async {
    // Use Android Keystore for secure key storage
    const keyAlias = 'spreadsheet_encryption_key';
    
    // Check if key exists
    if (await _keyExists(keyAlias)) {
      return await _retrieveKey(keyAlias);
    } else {
      return await _generateAndStoreKey(keyAlias);
    }
  }
}
```

### 10.2 API Security

```dart
class APISecurityHandler {
  /// Validate API endpoint before making requests
  bool validateEndpoint(String url) {
    // Only allow HTTPS
    if (!url.startsWith('https://')) {
      throw SecurityException('Only HTTPS endpoints are allowed');
    }
    
    // Block localhost/private IPs
    if (_isPrivateIP(url)) {
      throw SecurityException('Private IP addresses are not allowed');
    }
    
    return true;
  }
  
  /// Sanitize user input to prevent injection attacks
  String sanitizeInput(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
  
  /// Rate limiting for API requests
  bool checkRateLimit(String endpointId) {
    final lastRequest = _lastRequestTime[endpointId];
    if (lastRequest != null) {
      final elapsed = DateTime.now().difference(lastRequest);
      if (elapsed.inMilliseconds < 1000) {
        return false; // Too many requests
      }
    }
    
    _lastRequestTime[endpointId] = DateTime.now();
    return true;
  }
}
```

### 10.3 Permission Management

```dart
class PermissionManager {
  /// Request storage permission (for import/export)
  Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.status;
    
    if (status.isGranted) {
      return true;
    } else {
      final result = await Permission.storage.request();
      return result.isGranted;
    }
  }
  
  /// Request internet permission (for API integration)
  Future<bool> requestInternetPermission() async {
    // Internet permission is declared in AndroidManifest
    // No runtime request needed
    return true;
  }
}
```


---

## 11. Testing Strategy

### 11.1 Unit Testing

```dart
// Test: Formula Evaluation
class FormulaServiceTest {
  late FormulaService formulaService;
  
  setUp() {
    formulaService = FormulaService();
  }
  
  test('SUM function calculates correctly') {
    final formula = '=SUM(1, 2, 3, 4, 5)';
    final result = formulaService.evaluate(formula);
    expect(result, equals(15));
  }
  
  test('Cell reference resolves correctly') {
    final formula = '=A1 + B1';
    final context = {
      'A1': 10,
      'B1': 20,
    };
    final result = formulaService.evaluate(formula, context);
    expect(result, equals(30));
  }
  
  test('Circular reference detection') {
    // A1 = =B1
    // B1 = =A1
    expect(
      () => formulaService.detectCircularReference('A1'),
      throwsA(isA<CircularReferenceError>()),
    );
  }
}

// Test: Cell Operations
class CellRepositoryTest {
  late CellRepository repository;
  
  test('Cell CRUD operations') async {
    // Create
    final cell = CellEntity(
      cellId: uuid.v4(),
      sheetId: 'sheet-1',
      rowId: 'row-1',
      columnId: 'col-1',
      value: 'Test',
      dataType: CellDataType.text,
    );
    
    await repository.updateCell(cell);
    
    // Read
    final retrieved = await repository.getCellById(cell.cellId);
    expect(retrieved, isNotNull);
    expect(retrieved!.value, equals('Test'));
    
    // Update
    final updated = cell.copyWith(value: 'Updated');
    await repository.updateCell(updated);
    
    final retrieved2 = await repository.getCellById(cell.cellId);
    expect(retrieved2!.value, equals('Updated'));
    
    // Delete
    await repository.deleteCell(cell.cellId);
    final retrieved3 = await repository.getCellById(cell.cellId);
    expect(retrieved3, isNull);
  }
}
```

### 11.2 Widget Testing

```dart
// Test: Home Screen
class HomeScreenTest {
  testWidgets('Displays spreadsheet cards', (tester) async {
    // Arrange
    final mockController = MockHomeController();
    when(mockController.spreadsheetList).thenReturn([
      SpreadsheetEntity(
        spreadsheetId: '1',
        name: 'Test Sheet',
        createdAt: DateTime.now(),
      ),
    ]);
    
    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(controller: mockController),
      ),
    );
    
    // Assert
    expect(find.text('Test Sheet'), findsOneWidget);
  });
  
  testWidgets('FAB menu shows all options', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen()));
    
    // Tap FAB
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    
    // Verify menu items
    expect(find.text('Create New'), findsOneWidget);
    expect(find.text('Import Excel'), findsOneWidget);
    expect(find.text('Import CSV'), findsOneWidget);
    expect(find.text('Import Google Forms'), findsOneWidget);
    expect(find.text('Import API'), findsOneWidget);
  });
}

// Test: Editor Screen
class EditorScreenTest {
  testWidgets('Cell selection works', (tester) async {
    await tester.pumpWidget(MaterialApp(home: EditorScreen()));
    
    // Tap cell A1
    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    
    // Verify cell is selected (blue border)
    final cell = tester.widget<Container>(find.byKey(Key('cell-A1')));
    expect(cell.decoration, isA<BoxDecoration>());
    expect((cell.decoration as BoxDecoration).border?.top.color, equals(Colors.blue));
  });
}
```

### 11.3 Integration Testing

```dart
// Test: End-to-End Workflow
class E2ETest {
  testWidgets('Create sheet, add data, save', (tester) async {
    // Launch app
    await tester.pumpWidget(MyApp());
    
    // Create new sheet
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create New'));
    await tester.pumpAndSettle();
    
    // Verify editor screen opens
    expect(find.byType(EditorScreen), findsOneWidget);
    
    // Enter data in A1
    await tester.tap(find.byKey(Key('cell-A1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    
    // Verify data is saved
    expect(find.text('Hello'), findsOneWidget);
    
    // Go back to home
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    
    // Verify sheet appears in list
    expect(find.text('Untitled Sheet'), findsOneWidget);
  });
}
```

### 11.4 Performance Testing

```dart
class PerformanceTest {
  test('Rendering 10,000 cells stays under 16ms per frame') async {
    final stopwatch = Stopwatch()..start();
    
    // Generate 10,000 cells
    final cells = List.generate(10000, (i) {
      return CellData(
        x: (i % 100) * 120.0,
        y: (i ~/ 100) * 52.0,
        width: 120,
        height: 52,
        value: 'Cell $i',
      );
    });
    
    // Render frame
    await renderEngine.renderFrame(cells);
    
    stopwatch.stop();
    
    expect(stopwatch.elapsedMilliseconds, lessThan(16)); // 60 FPS
  });
  
  test('GPU compute is faster than CPU for large ranges') async {
    final range = List.generate(10000, (i) => i.toDouble());
    
    // CPU calculation
    final cpuStopwatch = Stopwatch()..start();
    final cpuResult = range.reduce((a, b) => a + b);
    cpuStopwatch.stop();
    
    // GPU calculation
    final gpuStopwatch = Stopwatch()..start();
    final gpuResult = await renderEngine.computeSum(range);
    gpuStopwatch.stop();
    
    print('CPU: ${cpuStopwatch.elapsedMilliseconds}ms');
    print('GPU: ${gpuStopwatch.elapsedMilliseconds}ms');
    
    expect(gpuResult, equals(cpuResult));
    expect(gpuStopwatch.elapsedMilliseconds, lessThan(cpuStopwatch.elapsedMilliseconds));
  });
}
```

### 11.5 Native Code Testing (C++)

```cpp
// Test: Vulkan Initialization
TEST(VulkanRendererTest, InitializesSuccessfully) {
    VulkanRenderer renderer;
    bool success = renderer.initialize();
    EXPECT_TRUE(success);
    EXPECT_TRUE(renderer.isVulkanSupported());
}

// Test: Cell Batch Rendering
TEST(CellBatchRendererTest, RendersCorrectCellCount) {
    CellBatchRenderer renderer;
    
    std::vector<CellData> cells;
    for (int i = 0; i < 100; i++) {
        cells.push_back(CellData{
            .x = (i % 10) * 120.0f,
            .y = (i / 10) * 52.0f,
            .width = 120,
            .height = 52,
        });
    }
    
    renderer.prepareBatch(cells);
    EXPECT_EQ(renderer.getCellCount(), 100);
}

// Test: Compute Shader Execution
TEST(ComputeEngineTest, CalculatesSumCorrectly) {
    ComputeEngine engine;
    engine.initialize();
    
    std::vector<float> data = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f};
    float result = engine.computeSum(data);
    
    EXPECT_FLOAT_EQ(result, 15.0f);
}
```

---

## 12. Deployment Strategy

### 12.1 Build Configuration

```gradle
// android/app/build.gradle.kts
android {
    compileSdk = 34
    
    defaultConfig {
        applicationId = "com.tablenotes.sheets.excelsheet.spreadsheet"
        minSdk = 24  // Required for Vulkan
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
        
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DANDROID_PLATFORM=android-24"
                )
            }
        }
    }
    
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            signingConfig = signingConfigs.getByName("release")
        }
        
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }
    }
}
```


### 12.2 ProGuard Rules

```proguard
# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep JNI bridge classes
-keep class com.tablenotes.sheets.excelsheet.spreadsheet.NativeRenderEngine { *; }

# Keep model classes
-keep class **.data.models.** { *; }

# Keep Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Vulkan native libraries
-keep class * {
    public static native <methods>;
}
```

### 12.3 Release Checklist

```markdown
## Pre-Release Checklist

### Code Quality
- [ ] All unit tests passing (>95% coverage)
- [ ] All integration tests passing
- [ ] No critical/major bugs open
- [ ] Code review completed
- [ ] Performance benchmarks met (60 FPS, <16ms frames)

### Security
- [ ] API keys removed from codebase
- [ ] ProGuard enabled and configured
- [ ] SSL certificate pinning implemented
- [ ] Data encryption verified
- [ ] Permission requests justified

### Native Layer
- [ ] Vulkan fallback tested on non-Vulkan devices
- [ ] Memory leaks checked (Valgrind)
- [ ] Crash reports enabled (Crashlytics)
- [ ] NDK version locked in build.gradle

### Testing
- [ ] Tested on Android 7.0 (API 24)
- [ ] Tested on Android 14 (API 34)
- [ ] Tested on low-end device (2GB RAM)
- [ ] Tested on high-end device (8GB RAM)
- [ ] Tested with 10,000+ cell spreadsheets
- [ ] Import/Export tested with real Excel files

### Documentation
- [ ] README.md updated
- [ ] API documentation generated
- [ ] User guide written
- [ ] Changelog updated

### Play Store
- [ ] App icon (512×512 PNG)
- [ ] Feature graphic (1024×500)
- [ ] Screenshots (4-8 images)
- [ ] Store listing text written
- [ ] Privacy policy URL added
- [ ] App category selected
- [ ] Content rating obtained
```

### 12.4 CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
  
  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      
      - name: Setup NDK
        uses: nttld/setup-ndk@v1
        with:
          ndk-version: r25c
      
      - name: Build APK
        run: flutter build apk --release
      
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: build/app/outputs/flutter-apk/app-release.apk
  
  deploy:
    needs: build-android
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Download APK
        uses: actions/download-artifact@v3
        with:
          name: app-release.apk
      
      - name: Deploy to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.tablenotes.sheets.excelsheet.spreadsheet
          releaseFiles: app-release.apk
          track: internal
```

---

## 13. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-3)

**Week 1: Project Setup & Core Architecture**
- ✅ Create Flutter project with package ID
- ✅ Configure Android NDK and CMake
- ✅ Add all dependencies to pubspec.yaml
- ✅ Create folder structure (core, data, domain, presentation, services)
- ✅ Setup constants, theme, and colors
- [ ] Configure SQLite database
- [ ] Create base entities (Cell, Sheet, Row, Column)
- [ ] Implement repository interfaces

**Week 2: Native Layer Foundation**
- [ ] Implement Vulkan initialization in C++
- [ ] Create VulkanRenderer class structure
- [ ] Implement JNI/FFI bridge
- [ ] Test Vulkan availability on device
- [ ] Create CPU fallback renderer
- [ ] Implement basic cell rendering (no GPU)

**Week 3: Data Layer Implementation**
- [ ] Implement database schema creation
- [ ] Create data models for all entities
- [ ] Implement LocalDataSource with SQLite operations
- [ ] Implement CellRepository with cache
- [ ] Implement SheetRepository
- [ ] Add UUID generation for all entities
- [ ] Write unit tests for data layer

### Phase 2: Core Functionality (Weeks 4-7)

**Week 4: Basic UI - Home Screen**
- [ ] Create HomeScreen widget
- [ ] Implement HomeController with Provider
- [ ] Create SheetCard widget with thumbnails
- [ ] Implement FAB menu with 5 options
- [ ] Add search and filter functionality
- [ ] Implement sheet CRUD operations
- [ ] Add navigation to EditorScreen

**Week 5: Basic UI - Editor Screen**
- [ ] Create EditorScreen layout
- [ ] Implement column/row headers
- [ ] Create grid widget with gesture detection
- [ ] Implement cell selection (single/range)
- [ ] Add formula bar (conditional visibility)
- [ ] Implement bottom toolbar with 5 icons
- [ ] Create sheet tabs at bottom

**Week 6: Cell Operations**
- [ ] Implement cell editing (double-tap)
- [ ] Add cell formatting (bold, italic, colors)
- [ ] Implement copy/cut/paste
- [ ] Add cell merging functionality
- [ ] Implement auto-fill (drag corner)
- [ ] Create undo/redo with Command pattern
- [ ] Add context menu on long-press

**Week 7: Formula Engine - CPU Only**
- [ ] Create formula tokenizer
- [ ] Implement AST parser
- [ ] Add formula syntax validation
- [ ] Implement basic functions (SUM, AVG, COUNT, etc.)
- [ ] Add cell reference resolution
- [ ] Implement dependency tracking
- [ ] Add circular reference detection
- [ ] Write formula engine tests

### Phase 3: GPU Acceleration (Weeks 8-10)

**Week 8: Vulkan Graphics Rendering**
- [ ] Implement virtual viewport system
- [ ] Create cell batch renderer
- [ ] Implement texture atlas for text
- [ ] Add GPU buffer management
- [ ] Create Vulkan command buffers
- [ ] Implement swapchain presentation
- [ ] Optimize rendering pipeline
- [ ] Benchmark: Target 60 FPS with 10,000 cells

**Week 9: GPU Compute for Formulas**
- [ ] Implement formula to GLSL compiler
- [ ] Create compute shader templates
- [ ] Add SPIR-V generation
- [ ] Implement compute queue dispatch
- [ ] Add GPU result readback
- [ ] Create fallback mechanism (GPU → CPU)
- [ ] Benchmark: Target 10x speedup

**Week 10: Performance Optimization**
- [ ] Profile memory usage (target <200MB)
- [ ] Optimize cell cache (LRU eviction)
- [ ] Implement sparse storage optimization
- [ ] Add auto-save mechanism (30s interval)
- [ ] Optimize database queries (indexes)
- [ ] Add texture compression
- [ ] Implement command buffer pooling
- [ ] Performance testing on low-end devices

### Phase 4: Advanced Features (Weeks 11-13)

**Week 11: Import/Export**
- [ ] Implement Excel import (.xlsx, .xls)
- [ ] Implement Excel export
- [ ] Implement CSV import (RFC 4180)
- [ ] Implement CSV export
- [ ] Add PDF export functionality
- [ ] Implement thumbnail generation (5×5 cells)
- [ ] Add file picker integration
- [ ] Write import/export tests

**Week 12: Column/Row Properties**
- [ ] Create ColumnPropertiesSheet bottom sheet
- [ ] Implement column type selector (8 types)
- [ ] Add width slider with live preview
- [ ] Create styles section (colors, alignment)
- [ ] Add column actions (insert, hide, chart)
- [ ] Create RowPropertiesSheet (similar)
- [ ] Implement column/row resizing via drag
- [ ] Add column/row insertion/deletion

**Week 13: Data Validation & Formatting**
- [ ] Implement number formatting (currency, %, decimals)
- [ ] Add date/time formatting
- [ ] Create data validation rules UI
- [ ] Implement dropdown lists
- [ ] Add checkbox column type
- [ ] Implement conditional formatting
- [ ] Create chart generation (basic bar/line)
- [ ] Add cell linking

### Phase 5: Integration Features (Weeks 14-15)

**Week 14: Google Forms Integration**
- [ ] Implement Google OAuth 2.0 flow
- [ ] Add Google Sign-In button
- [ ] Fetch user's Google Forms list
- [ ] Implement form response fetching
- [ ] Map form questions to columns
- [ ] Add auto-sync functionality (webhook)
- [ ] Create ImportGoogleFormsScreen
- [ ] Test with real Google Forms

**Week 15: REST API Integration**
- [ ] Create APIEndpointConfig UI
- [ ] Implement endpoint testing
- [ ] Add authentication options (API Key, Bearer, Basic)
- [ ] Implement JSON/XML parsing
- [ ] Create field mapping UI
- [ ] Add auto-refresh scheduling
- [ ] Implement ImportAPIScreen
- [ ] Write API integration tests

### Phase 6: AI Agent & Polish (Week 16)

**Week 16: AI Agent API**
- [ ] Implement AI Agent REST API (14 methods)
- [ ] Add localhost:8080 server
- [ ] Create API documentation
- [ ] Add authentication for API
- [ ] Implement rate limiting
- [ ] Write API client examples
- [ ] Test all 14 endpoints

**Week 16: Final Polish**
- [ ] UI/UX refinements based on testing
- [ ] Add loading states and progress indicators
- [ ] Implement error messages and dialogs
- [ ] Add onboarding tutorial (first launch)
- [ ] Optimize app size (target <50MB)
- [ ] Add dark theme support
- [ ] Final performance testing
- [ ] Fix all critical bugs

### Phase 7: Release Preparation (Week 17)

- [ ] Complete all items in release checklist
- [ ] Generate signed APK
- [ ] Test on 5+ devices
- [ ] Create Play Store listing
- [ ] Write privacy policy
- [ ] Generate app screenshots
- [ ] Submit to Play Store (Internal Testing)
- [ ] Gather feedback from testers
- [ ] Iterate and fix issues
- [ ] Release to Production

---

## 14. Maintenance & Future Enhancements

### 14.1 Monitoring

```dart
class AppMonitoring {
  final FirebaseCrashlytics crashlytics;
  final FirebaseAnalytics analytics;
  
  void initialize() {
    // Crash reporting
    FlutterError.onError = crashlytics.recordFlutterError;
    
    // Performance monitoring
    FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    
    // Custom metrics
    _trackAppLaunch();
    _trackVulkanAvailability();
  }
  
  void trackRenderingPerformance(int frameTimeMs) {
    analytics.logEvent(
      name: 'rendering_performance',
      parameters: {'frame_time_ms': frameTimeMs},
    );
  }
  
  void trackFormulaCalculation(String formulaType, int cellCount, int timeMs) {
    analytics.logEvent(
      name: 'formula_calculation',
      parameters: {
        'formula_type': formulaType,
        'cell_count': cellCount,
        'time_ms': timeMs,
      },
    );
  }
}
```

### 14.2 Future Features

1. **Cloud Sync** (Q2 2027)
   - Firebase Firestore integration
   - Real-time collaboration
   - Conflict resolution

2. **iOS Support** (Q3 2027)
   - Port Vulkan to Metal
   - Adapt UI for iOS guidelines

3. **Advanced Charting** (Q4 2027)
   - Pie charts, scatter plots
   - Chart customization
   - Interactive charts

4. **Macro Recording** (Q1 2028)
   - Record user actions
   - Replay macros
   - Macro library

5. **Plugin System** (Q2 2028)
   - Custom formula functions
   - Third-party integrations
   - Theme plugins

---

## Appendix

### A. Glossary

- **AST**: Abstract Syntax Tree
- **EARS**: Easy Approach to Requirements Syntax
- **FFI**: Foreign Function Interface
- **JNI**: Java Native Interface
- **LRU**: Least Recently Used (cache eviction)
- **NDK**: Native Development Kit
- **SPIR-V**: Standard Portable Intermediate Representation (Vulkan shaders)
- **UUID**: Universally Unique Identifier

### B. References

- [Vulkan Specification](https://www.khronos.org/vulkan/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Android NDK Guide](https://developer.android.com/ndk)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [Google Forms API](https://developers.google.com/forms/api)

### C. Performance Benchmarks

| Metric | Target | Measured |
|--------|--------|----------|
| Frame Time (60 FPS) | <16ms | TBD |
| Frame Time (120 FPS) | <8ms | TBD |
| GPU Compute Speedup | 10-25x | TBD |
| Memory Usage (Idle) | <150MB | TBD |
| Memory Usage (10K cells) | <200MB | TBD |
| App Size | <50MB | TBD |
| Cold Start Time | <2s | TBD |
| Cell Cache Hit Rate | >90% | TBD |
| Database Query Time | <5ms | TBD |

---

**Document Version**: 1.0  
**Last Updated**: January 24, 2027  
**Author**: AI Technical Architect  
**Status**: Complete - Ready for Implementation
