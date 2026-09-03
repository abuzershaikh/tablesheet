# Implementation Tasks

This document breaks down the Mobile Spreadsheet application into concrete implementation tasks. Each task is atomic, testable, and maps to specific design components.

---

## Phase 1: Foundation (Weeks 1-3)

### TASK-001: Database Schema Setup
**Priority**: Critical  
**Estimate**: 8 hours  
**Dependencies**: None

**Description**: Create SQLite database schema with all tables and indexes for the spreadsheet application.

**Acceptance Criteria**:
- [ ] Create `spreadsheets` table with UUID primary key
- [ ] Create `sheets` table with foreign key to spreadsheets
- [ ] Create `rows` table with UUID and display position
- [ ] Create `columns` table with UUID and display position
- [ ] Create `cells` table with composite index on (sheet_id, row_id, column_id)
- [ ] Create indexes for common queries
- [ ] Add foreign key constraints
- [ ] Write database migration script
- [ ] Test database creation on Android device

**Files to Create**:
- `lib/data/data_sources/database/database_helper.dart`
- `lib/data/data_sources/database/database_schema.dart`
- `test/data/database_test.dart`

---

### TASK-002: Core Domain Entities
**Priority**: Critical  
**Estimate**: 6 hours  
**Dependencies**: None

**Description**: Implement all domain entities with immutable data classes.

**Acceptance Criteria**:
- [ ] Complete CellEntity with UUID, value, formula, format
- [ ] Create SheetEntity with metadata
- [ ] Create RowEntity with height and visibility
- [ ] Create ColumnEntity with width, type, and name
- [ ] Create SpreadsheetEntity with sheet list
- [ ] All entities are immutable
- [ ] Add copyWith methods for updates
- [ ] Add toJson/fromJson methods
- [ ] Write unit tests for all entities

**Files to Create/Update**:
- `lib/domain/entities/cell_entity.dart` (already exists, complete it)
- `lib/domain/entities/sheet_entity.dart`
- `lib/domain/entities/row_entity.dart`
- `lib/domain/entities/column_entity.dart`
- `lib/domain/entities/spreadsheet_entity.dart`
- `test/domain/entities_test.dart`

---

### TASK-003: Data Models and Mappers
**Priority**: Critical  
**Estimate**: 6 hours  
**Dependencies**: TASK-002

**Description**: Create data models for database storage and mappers to convert between entities and models.

**Acceptance Criteria**:
- [ ] Create CellModel with toMap/fromMap
- [ ] Create SheetModel with toMap/fromMap
- [ ] Create RowModel with toMap/fromMap
- [ ] Create ColumnModel with toMap/fromMap
- [ ] Create SpreadsheetModel with toMap/fromMap
- [ ] Implement CellMapper (entity ↔ model)
- [ ] Implement SheetMapper (entity ↔ model)
- [ ] All models map correctly to database columns
- [ ] Write mapper unit tests

**Files to Create**:
- `lib/data/models/cell_model.dart`
- `lib/data/models/sheet_model.dart`
- `lib/data/models/row_model.dart`
- `lib/data/models/column_model.dart`
- `lib/data/models/spreadsheet_model.dart`
- `lib/data/mappers/cell_mapper.dart`
- `lib/data/mappers/sheet_mapper.dart`
- `test/data/mappers_test.dart`

---

### TASK-004: Local Data Source Implementation
**Priority**: Critical  
**Estimate**: 12 hours  
**Dependencies**: TASK-001, TASK-003

**Description**: Implement LocalDataSource with all SQLite CRUD operations.

**Acceptance Criteria**:
- [ ] Implement queryCellByAddress(sheetId, rowId, columnId)
- [ ] Implement batchUpdateCells(List<CellModel>)
- [ ] Implement queryCellRange(sheetId, startRow, endRow, startCol, endCol)
- [ ] Implement createSheet(SheetModel)
- [ ] Implement deleteSheet(sheetId)
- [ ] Implement getAllSpreadsheets()
- [ ] Implement transaction support for batch operations
- [ ] Add proper error handling
- [ ] Use prepared statements to prevent SQL injection
- [ ] Write integration tests with real database

**Files to Create**:
- `lib/data/data_sources/local_data_source.dart`
- `test/data/local_data_source_test.dart`

---

### TASK-005: Cell Cache Implementation
**Priority**: High  
**Estimate**: 6 hours  
**Dependencies**: TASK-002

**Description**: Implement LRU cache for cell entities with 50MB size limit.

**Acceptance Criteria**:
- [ ] Implement LRU eviction algorithm
- [ ] Track cache size in bytes
- [ ] Implement get(key) with access time update
- [ ] Implement put(key, value) with size tracking
- [ ] Implement evictLRU(count) method
- [ ] Auto-evict when size exceeds 50MB
- [ ] Thread-safe operations
- [ ] Cache hit rate tracking
- [ ] Write cache behavior tests

**Files to Create**:
- `lib/data/cache/cell_cache.dart`
- `test/data/cell_cache_test.dart`

---

### TASK-006: Repository Implementations
**Priority**: Critical  
**Estimate**: 10 hours  
**Dependencies**: TASK-004, TASK-005

**Description**: Implement repository pattern for all entities with caching.

**Acceptance Criteria**:
- [ ] Implement CellRepositoryImpl with cache integration
- [ ] Implement SheetRepositoryImpl
- [ ] Implement SpreadsheetRepositoryImpl
- [ ] All methods return Future<T> or Stream<T>
- [ ] Cache is checked before database queries
- [ ] Cache is updated after write operations
- [ ] Proper error handling and propagation
- [ ] Write repository unit tests with mocks

**Files to Create**:
- `lib/data/repositories/cell_repository_impl.dart`
- `lib/data/repositories/sheet_repository_impl.dart`
- `lib/data/repositories/spreadsheet_repository_impl.dart`
- `lib/domain/repositories/cell_repository.dart` (interface)
- `lib/domain/repositories/sheet_repository.dart` (interface)
- `lib/domain/repositories/spreadsheet_repository.dart` (interface)
- `test/data/repositories_test.dart`

---

### TASK-007: Native Bridge Setup (JNI/FFI)
**Priority**: Critical  
**Estimate**: 10 hours  
**Dependencies**: None

**Description**: Setup JNI bridge between Dart and C++ native code.

**Acceptance Criteria**:
- [ ] Create NativeRenderEngine Dart class
- [ ] Implement FFI method signatures
- [ ] Create JNI C++ wrapper functions
- [ ] Test simple native call (e.g., getVulkanVersion)
- [ ] Handle native exceptions properly
- [ ] Implement proper memory management
- [ ] Test on Android device
- [ ] Add logging for native calls

**Files to Create/Update**:
- `lib/services/rendering/native_render_engine.dart`
- `android/app/src/main/cpp/jni_bridge.cpp`
- `android/app/src/main/cpp/jni_bridge.h`
- Update `android/app/src/main/cpp/CMakeLists.txt`
- `test/services/native_bridge_test.dart`

---

### TASK-008: Vulkan Initialization
**Priority**: Critical  
**Estimate**: 16 hours  
**Dependencies**: TASK-007

**Description**: Implement Vulkan instance, device, and queue creation in C++.

**Acceptance Criteria**:
- [ ] Create VkInstance with validation layers (debug only)
- [ ] Enumerate and select physical device
- [ ] Create logical device with graphics/compute/transfer queues
- [ ] Check Vulkan API version (1.1+)
- [ ] Implement proper error handling
- [ ] Create CPU fallback if Vulkan unavailable
- [ ] Test on Vulkan-supported device
- [ ] Test fallback on non-Vulkan device
- [ ] Log GPU information (name, driver version)

**Files to Create/Update**:
- Update `android/app/src/main/cpp/vulkan_renderer.cpp`
- Update `android/app/src/main/cpp/vulkan_renderer.h`
- `android/app/src/main/cpp/vulkan_instance.cpp`
- `android/app/src/main/cpp/vulkan_device.cpp`

---


## Phase 2: Core Functionality (Weeks 4-7)

### TASK-009: Home Screen UI
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: TASK-006

**Description**: Create HomeScreen with spreadsheet list and FAB menu.

**Acceptance Criteria**:
- [ ] Create HomeScreen StatefulWidget
- [ ] Implement AppBar with search icon
- [ ] Create SheetCard widget with thumbnail, name, metadata
- [ ] Implement GridView for sheet cards
- [ ] Create FAB with SpeedDial menu (5 options)
- [ ] Add pull-to-refresh functionality
- [ ] Handle empty state (no sheets)
- [ ] Navigation to EditorScreen on card tap
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/home/home_screen.dart`
- `lib/presentation/home/widgets/sheet_card.dart`
- `lib/presentation/home/widgets/fab_menu.dart`
- `test/presentation/home_screen_test.dart`

---

### TASK-010: Home Screen Controller
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-009

**Description**: Implement HomeController using Provider for state management.

**Acceptance Criteria**:
- [ ] Create HomeController extending ChangeNotifier
- [ ] Implement loadSpreadsheets() method
- [ ] Implement searchSpreadsheets(query) method
- [ ] Implement sortSpreadsheets(sortBy) method
- [ ] Implement deleteSpreadsheet(id) with undo
- [ ] Implement duplicateSpreadsheet(id) method
- [ ] Add loading and error states
- [ ] Notify listeners on state changes
- [ ] Write controller unit tests

**Files to Create**:
- `lib/presentation/home/home_controller.dart`
- `test/presentation/home_controller_test.dart`

---

### TASK-011: Editor Screen Layout
**Priority**: Critical  
**Estimate**: 16 hours  
**Dependencies**: None

**Description**: Create EditorScreen layout with all UI components (no functionality yet).

**Acceptance Criteria**:
- [ ] Create EditorScreen StatefulWidget
- [ ] Implement TopAppBar with title and search
- [ ] Create FormulaBar widget (conditionally visible)
- [ ] Create placeholder for GridWidget (NativeRenderSurface)
- [ ] Implement sheet tabs at bottom
- [ ] Create bottom toolbar with 5 icons
- [ ] Add column headers (A, B, C, ...)
- [ ] Add row headers (1, 2, 3, ...)
- [ ] Proper layout with correct spacing
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/editor/editor_screen.dart`
- `lib/presentation/editor/widgets/top_app_bar.dart`
- `lib/presentation/editor/widgets/formula_bar.dart`
- `lib/presentation/editor/widgets/grid_widget.dart`
- `lib/presentation/editor/widgets/sheet_tabs.dart`
- `lib/presentation/editor/widgets/bottom_toolbar.dart`
- `lib/presentation/editor/widgets/column_headers.dart`
- `lib/presentation/editor/widgets/row_headers.dart`
- `test/presentation/editor_screen_test.dart`

---

### TASK-012: Editor Screen Controller
**Priority**: Critical  
**Estimate**: 12 hours  
**Dependencies**: TASK-011

**Description**: Implement EditorController with cell selection, editing, and viewport state.

**Acceptance Criteria**:
- [ ] Create EditorController extending ChangeNotifier
- [ ] Implement selectCell(position) method
- [ ] Implement selectRange(start, end) method
- [ ] Implement editCell(cell, value) method
- [ ] Track selectedCells: List<CellPosition>
- [ ] Track editingCell: CellEntity?
- [ ] Track viewport state (scrollX, scrollY, zoom)
- [ ] Implement updateViewport(x, y, zoom)
- [ ] Add loading and error states
- [ ] Write controller unit tests

**Files to Create**:
- `lib/presentation/editor/editor_controller.dart`
- `test/presentation/editor_controller_test.dart`

---

### TASK-013: Cell Operations Use Case
**Priority**: Critical  
**Estimate**: 10 hours  
**Dependencies**: TASK-006

**Description**: Implement CellOperationsUseCase with all cell manipulation methods.

**Acceptance Criteria**:
- [ ] Implement getCellValue(cellAddress)
- [ ] Implement setCellValue(cellAddress, value)
- [ ] Implement getCellRange(startAddress, endAddress)
- [ ] Implement mergeCells(cellRange)
- [ ] Implement unmergeCells(cellAddress)
- [ ] Implement applyCellFormatting(cellAddress, format)
- [ ] Handle errors (invalid addresses, etc.)
- [ ] Return proper error types
- [ ] Write use case unit tests

**Files to Create**:
- `lib/domain/use_cases/cell_operations_use_case.dart`
- `test/domain/cell_operations_use_case_test.dart`

---

### TASK-014: Sheet Management Use Case
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-006

**Description**: Implement SheetManagementUseCase for sheet CRUD operations.

**Acceptance Criteria**:
- [ ] Implement createSheet(name)
- [ ] Implement deleteSheet(sheetId)
- [ ] Implement renameSheet(sheetId, newName)
- [ ] Implement duplicateSheet(sheetId)
- [ ] Implement reorderSheets(oldIndex, newIndex)
- [ ] Implement getSheetList()
- [ ] Handle errors properly
- [ ] Write use case unit tests

**Files to Create**:
- `lib/domain/use_cases/sheet_management_use_case.dart`
- `test/domain/sheet_management_use_case_test.dart`

---

### TASK-015: Cell Selection and Editing
**Priority**: Critical  
**Estimate**: 10 hours  
**Dependencies**: TASK-012, TASK-013

**Description**: Implement cell selection and editing functionality in GridWidget.

**Acceptance Criteria**:
- [ ] Single cell selection on tap
- [ ] Range selection on drag
- [ ] Selected cell highlights with blue border
- [ ] Double-tap opens edit mode
- [ ] Formula bar appears in edit mode
- [ ] Text input updates cell value
- [ ] Enter key confirms edit
- [ ] Escape key cancels edit
- [ ] Write widget tests

**Files to Update**:
- `lib/presentation/editor/widgets/grid_widget.dart`
- `lib/presentation/editor/editor_controller.dart`
- `test/presentation/cell_selection_test.dart`

---

### TASK-016: Copy, Cut, Paste Implementation
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-015

**Description**: Implement clipboard operations for cells.

**Acceptance Criteria**:
- [ ] Copy selected cells to clipboard
- [ ] Cut selected cells (copy + clear)
- [ ] Paste cells from clipboard
- [ ] Preserve cell formatting on paste
- [ ] Handle range paste (expand to fit)
- [ ] Show paste preview on hover
- [ ] Add keyboard shortcuts (Ctrl+C, Ctrl+V, Ctrl+X)
- [ ] Write clipboard tests

**Files to Create**:
- `lib/services/clipboard/clipboard_service.dart`
- `test/services/clipboard_service_test.dart`

---

### TASK-017: Undo/Redo with Command Pattern
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: TASK-013

**Description**: Implement undo/redo functionality using Command pattern.

**Acceptance Criteria**:
- [ ] Create Command interface
- [ ] Implement SetCellValueCommand
- [ ] Implement DeleteCellCommand
- [ ] Implement MergeCellsCommand
- [ ] Implement FormatCellCommand
- [ ] Create CommandManager with undo/redo stacks
- [ ] Limit undo stack to 100 commands
- [ ] Add keyboard shortcuts (Ctrl+Z, Ctrl+Y)
- [ ] Write command tests

**Files to Create**:
- `lib/domain/commands/command.dart`
- `lib/domain/commands/set_cell_value_command.dart`
- `lib/domain/commands/delete_cell_command.dart`
- `lib/domain/commands/merge_cells_command.dart`
- `lib/domain/commands/format_cell_command.dart`
- `lib/domain/commands/command_manager.dart`
- `test/domain/commands_test.dart`

---

### TASK-018: Formula Parser
**Priority**: Critical  
**Estimate**: 20 hours  
**Dependencies**: None

**Description**: Implement formula tokenizer and AST parser.

**Acceptance Criteria**:
- [ ] Tokenize formula string (operators, functions, references)
- [ ] Build Abstract Syntax Tree (AST)
- [ ] Support operators: +, -, *, /, ^, &
- [ ] Support cell references (A1, $A$1, Sheet1!A1)
- [ ] Support range references (A1:B10)
- [ ] Support function calls (SUM, AVG, etc.)
- [ ] Validate syntax and return errors
- [ ] Handle nested formulas
- [ ] Write parser tests with complex formulas

**Files to Create**:
- `lib/services/formula/formula_parser.dart`
- `lib/services/formula/formula_tokenizer.dart`
- `lib/services/formula/formula_ast.dart`
- `test/services/formula_parser_test.dart`

---

### TASK-019: Formula Evaluator (CPU)
**Priority**: Critical  
**Estimate**: 16 hours  
**Dependencies**: TASK-018

**Description**: Implement formula evaluation engine (CPU only, no GPU yet).

**Acceptance Criteria**:
- [ ] Implement SUM, AVG, COUNT, MIN, MAX functions
- [ ] Implement IF, AND, OR, NOT functions
- [ ] Implement VLOOKUP, HLOOKUP functions
- [ ] Implement DATE, TODAY, NOW functions
- [ ] Implement TEXT, CONCATENATE functions
- [ ] Resolve cell references from context
- [ ] Handle error types (#REF!, #VALUE!, #DIV/0!)
- [ ] Support nested function calls
- [ ] Write evaluator tests

**Files to Create**:
- `lib/services/formula/formula_evaluator.dart`
- `lib/services/formula/functions/math_functions.dart`
- `lib/services/formula/functions/logical_functions.dart`
- `lib/services/formula/functions/lookup_functions.dart`
- `lib/services/formula/functions/date_functions.dart`
- `lib/services/formula/functions/text_functions.dart`
- `test/services/formula_evaluator_test.dart`

---

### TASK-020: Dependency Graph
**Priority**: High  
**Estimate**: 10 hours  
**Dependencies**: TASK-018

**Description**: Implement formula dependency tracking and recalculation.

**Acceptance Criteria**:
- [ ] Build dependency graph from formulas
- [ ] Detect circular references
- [ ] Implement topological sort for calculation order
- [ ] Recalculate dependents on cell change
- [ ] Handle cascading updates efficiently
- [ ] Track which cells need recalculation
- [ ] Batch recalculation for performance
- [ ] Write dependency tests

**Files to Create**:
- `lib/services/formula/dependency_graph.dart`
- `test/services/dependency_graph_test.dart`

---

## Phase 3: GPU Acceleration (Weeks 8-10)

### TASK-021: Virtual Viewport System
**Priority**: Critical  
**Estimate**: 12 hours  
**Dependencies**: TASK-008

**Description**: Implement virtual viewport to calculate visible cells.

**Acceptance Criteria**:
- [ ] Calculate visible cell range from scroll position
- [ ] Account for zoom level (0.5x to 2.0x)
- [ ] Add padding (render 2 extra rows/cols off-screen)
- [ ] Update on scroll or zoom change
- [ ] Return startRow, endRow, startCol, endCol
- [ ] Performance: <1ms calculation time
- [ ] Write viewport tests

**Files to Create**:
- `android/app/src/main/cpp/virtual_viewport.cpp`
- `android/app/src/main/cpp/virtual_viewport.h`

---

### TASK-022: Texture Atlas for Text
**Priority**: High  
**Estimate**: 16 hours  
**Dependencies**: TASK-008

**Description**: Implement texture atlas system for pre-rendered text glyphs.

**Acceptance Criteria**:
- [ ] Create 2048×2048 texture atlas
- [ ] Pre-render common characters (A-Z, 0-9, symbols)
- [ ] Store glyph UV coordinates
- [ ] Implement dynamic glyph addition
- [ ] Handle atlas overflow (create new atlas)
- [ ] Use mipmap for different zoom levels
- [ ] Compress texture (BC1/ETC2)
- [ ] Test with 1000+ unique strings

**Files to Create**:
- `android/app/src/main/cpp/texture_atlas.cpp`
- `android/app/src/main/cpp/texture_atlas.h`

---

### TASK-023: Cell Batch Renderer
**Priority**: Critical  
**Estimate**: 20 hours  
**Dependencies**: TASK-021, TASK-022

**Description**: Implement GPU batch rendering for cells.

**Acceptance Criteria**:
- [ ] Pack cell data into instance buffer
- [ ] Single draw call for all visible cells
- [ ] Vertex shader positions cells correctly
- [ ] Fragment shader samples texture atlas
- [ ] Render cell backgrounds with colors
- [ ] Render cell borders
- [ ] Render text from atlas
- [ ] Handle cell selection highlighting
- [ ] Performance: 60 FPS with 10,000 cells

**Files to Create**:
- `android/app/src/main/cpp/cell_batch_renderer.cpp`
- `android/app/src/main/cpp/cell_batch_renderer.h`
- `android/app/src/main/cpp/shaders/cell_vertex.glsl`
- `android/app/src/main/cpp/shaders/cell_fragment.glsl`

---

### TASK-024: Command Buffer Pooling
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-023

**Description**: Implement command buffer pool for efficient frame rendering.

**Acceptance Criteria**:
- [ ] Create pool of 3 command buffers
- [ ] Rotate buffers each frame
- [ ] Wait for fence before reuse
- [ ] Record commands efficiently
- [ ] Submit to graphics queue
- [ ] Handle swapchain recreation
- [ ] Write pool tests

**Files to Create**:
- `android/app/src/main/cpp/command_buffer_pool.cpp`
- `android/app/src/main/cpp/command_buffer_pool.h`

---

### TASK-025: Swapchain and Presentation
**Priority**: Critical  
**Estimate**: 12 hours  
**Dependencies**: TASK-024

**Description**: Implement Vulkan swapchain for presenting frames.

**Acceptance Criteria**:
- [ ] Create swapchain with double/triple buffering
- [ ] Handle window resize events
- [ ] Implement proper synchronization (fences, semaphores)
- [ ] Present frames to screen
- [ ] Handle swapchain out-of-date errors
- [ ] Support VSync and immediate modes
- [ ] Measure frame time
- [ ] Target 60 FPS

**Files to Create**:
- `android/app/src/main/cpp/swapchain.cpp`
- `android/app/src/main/cpp/swapchain.h`

---

### TASK-026: GPU Compute Setup
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: TASK-008

**Description**: Setup compute queue and compute pipeline for formula calculations.

**Acceptance Criteria**:
- [ ] Create compute queue
- [ ] Create compute pipeline
- [ ] Implement buffer allocation for input/output
- [ ] Write simple compute shader (test with sum)
- [ ] Dispatch compute shader
- [ ] Read results back to CPU
- [ ] Handle compute errors
- [ ] Benchmark compute vs CPU

**Files to Create**:
- `android/app/src/main/cpp/compute_engine.cpp`
- `android/app/src/main/cpp/compute_engine.h`
- `android/app/src/main/cpp/shaders/sum_compute.glsl`

---

### TASK-027: Formula to GLSL Compiler
**Priority**: High  
**Estimate**: 20 hours  
**Dependencies**: TASK-018, TASK-026

**Description**: Compile formula AST to GLSL compute shader.

**Acceptance Criteria**:
- [ ] Convert formula AST to GLSL code
- [ ] Support SUM, AVG, COUNT functions
- [ ] Support basic operators (+, -, *, /)
- [ ] Generate SPIR-V bytecode
- [ ] Handle ranges as input buffers
- [ ] Return error if formula not GPU-compatible
- [ ] Test with complex formulas
- [ ] Verify correctness vs CPU

**Files to Create**:
- `lib/services/formula/formula_compiler.dart`
- `android/app/src/main/cpp/glsl_generator.cpp`
- `android/app/src/main/cpp/glsl_generator.h`
- `test/services/formula_compiler_test.dart`

---

### TASK-028: GPU Compute Integration
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: TASK-027

**Description**: Integrate GPU compute with formula evaluator.

**Acceptance Criteria**:
- [ ] Check if formula should use GPU (range size > 1000)
- [ ] Compile formula to GLSL
- [ ] Prepare input data from cells
- [ ] Execute compute shader
- [ ] Read result back
- [ ] Fallback to CPU if GPU fails
- [ ] Benchmark: 10x speedup for large ranges
- [ ] Write integration tests

**Files to Update**:
- `lib/services/formula/formula_evaluator.dart`
- `lib/services/rendering/native_render_engine.dart`
- `test/services/gpu_compute_integration_test.dart`

---

### TASK-029: Performance Profiling
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-025, TASK-028

**Description**: Profile rendering and compute performance, optimize bottlenecks.

**Acceptance Criteria**:
- [ ] Measure frame time (target <16ms)
- [ ] Measure GPU compute time
- [ ] Measure CPU compute time
- [ ] Identify bottlenecks (CPU profiler)
- [ ] Optimize hot paths
- [ ] Test on low-end device (2GB RAM)
- [ ] Test on high-end device (8GB RAM)
- [ ] Document performance benchmarks

**Files to Create**:
- `docs/PERFORMANCE_BENCHMARKS.md`

---

### TASK-030: Memory Optimization
**Priority**: High  
**Estimate**: 10 hours  
**Dependencies**: TASK-023

**Description**: Optimize memory usage for large spreadsheets.

**Acceptance Criteria**:
- [ ] Cell cache limited to 50MB
- [ ] LRU eviction working correctly
- [ ] GPU memory limited to 41MB
- [ ] Texture compression enabled
- [ ] Sparse storage (only non-empty cells)
- [ ] Auto-save queue limited to 1000 updates
- [ ] Total memory usage <200MB for 10K cells
- [ ] Test with 100K cells spreadsheet

**Files to Update**:
- `lib/data/cache/cell_cache.dart`
- `android/app/src/main/cpp/texture_atlas.cpp`
- `lib/services/storage/storage_service.dart`

---


## Phase 4: Advanced Features (Weeks 11-13)

### TASK-031: Excel Import Library Integration
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: TASK-006

**Description**: Integrate excel package for reading .xlsx and .xls files.

**Acceptance Criteria**:
- [ ] Read .xlsx files using excel package
- [ ] Read .xls files using excel package
- [ ] Extract sheet names
- [ ] Extract cell values with types
- [ ] Extract cell formatting (colors, fonts)
- [ ] Handle merged cells
- [ ] Handle formulas (preserve as text)
- [ ] Handle large files (>10MB)
- [ ] Test with real Excel files

**Files to Create**:
- `lib/services/import_export/excel_import_service.dart`
- `test/services/excel_import_service_test.dart`

---

### TASK-032: Excel Import Use Case
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-031

**Description**: Implement ImportExcelUseCase to convert Excel files to spreadsheet entities.

**Acceptance Criteria**:
- [ ] Parse Excel file
- [ ] Create SpreadsheetEntity
- [ ] Create SheetEntity for each Excel sheet
- [ ] Create CellEntity for each Excel cell
- [ ] Map Excel formatting to app formatting
- [ ] Generate UUIDs for all entities
- [ ] Save to database
- [ ] Return success/error
- [ ] Write use case tests

**Files to Create**:
- `lib/domain/use_cases/import_excel_use_case.dart`
- `test/domain/import_excel_use_case_test.dart`

---

### TASK-033: Excel Export Implementation
**Priority**: High  
**Estimate**: 10 hours  
**Dependencies**: TASK-031

**Description**: Implement Excel export functionality.

**Acceptance Criteria**:
- [ ] Create .xlsx file from spreadsheet
- [ ] Export all sheets
- [ ] Export cell values and types
- [ ] Export cell formatting (colors, fonts)
- [ ] Export formulas
- [ ] Handle merged cells
- [ ] Set column widths
- [ ] Test file opens in Excel/Google Sheets

**Files to Create**:
- `lib/services/import_export/excel_export_service.dart`
- `lib/domain/use_cases/export_excel_use_case.dart`
- `test/services/excel_export_service_test.dart`

---

### TASK-034: CSV Import/Export
**Priority**: Medium  
**Estimate**: 8 hours  
**Dependencies**: None

**Description**: Implement CSV import and export (RFC 4180 compliant).

**Acceptance Criteria**:
- [ ] Parse CSV files (RFC 4180)
- [ ] Detect headers automatically
- [ ] Handle quoted fields with commas
- [ ] Handle different encodings (UTF-8, UTF-16)
- [ ] Export to CSV with proper quoting
- [ ] Handle large CSV files (>1MB)
- [ ] Test with various CSV formats

**Files to Create**:
- `lib/services/import_export/csv_service.dart`
- `lib/domain/use_cases/import_csv_use_case.dart`
- `lib/domain/use_cases/export_csv_use_case.dart`
- `test/services/csv_service_test.dart`

---

### TASK-035: PDF Export
**Priority**: Low  
**Estimate**: 10 hours  
**Dependencies**: None

**Description**: Implement PDF export using pdf package.

**Acceptance Criteria**:
- [ ] Create PDF from spreadsheet
- [ ] Render cells as table
- [ ] Preserve cell formatting
- [ ] Handle page breaks
- [ ] Add headers and footers
- [ ] Set page size (A4, Letter)
- [ ] Export selected range or entire sheet
- [ ] Test PDF opens correctly

**Files to Create**:
- `lib/services/import_export/pdf_export_service.dart`
- `lib/domain/use_cases/export_pdf_use_case.dart`
- `test/services/pdf_export_service_test.dart`

---

### TASK-036: Import Screen UI
**Priority**: Medium  
**Estimate**: 8 hours  
**Dependencies**: TASK-032, TASK-034

**Description**: Create ImportScreen for Excel/CSV file selection.

**Acceptance Criteria**:
- [ ] File picker integration
- [ ] Show file preview (first 5 rows)
- [ ] Import progress indicator
- [ ] Error handling UI
- [ ] Success message
- [ ] Navigation to imported sheet
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/import/import_screen.dart`
- `lib/presentation/import/import_controller.dart`
- `test/presentation/import_screen_test.dart`

---

### TASK-037: Column Properties Bottom Sheet
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: TASK-011

**Description**: Create ColumnPropertiesSheet with all properties.

**Acceptance Criteria**:
- [ ] Show on column header tap
- [ ] Column name input field
- [ ] Column type selector (8 types dropdown)
- [ ] Width slider with live preview
- [ ] Bold/Italic toggle buttons
- [ ] Background color picker
- [ ] Text color picker
- [ ] Alignment buttons (left, center, right)
- [ ] Insert column button
- [ ] Hide/Show column toggle
- [ ] Generate chart button
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/editor/widgets/column_properties_sheet.dart`
- `lib/presentation/editor/widgets/color_picker.dart`
- `test/presentation/column_properties_test.dart`

---

### TASK-038: Row Properties Bottom Sheet
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-037

**Description**: Create RowPropertiesSheet similar to column properties.

**Acceptance Criteria**:
- [ ] Show on row header tap
- [ ] Row number display (read-only)
- [ ] Height slider with live preview
- [ ] Bold/Italic toggle buttons
- [ ] Background color picker
- [ ] Insert row button
- [ ] Hide/Show row toggle
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/editor/widgets/row_properties_sheet.dart`
- `test/presentation/row_properties_test.dart`

---

### TASK-039: Column/Row Resize via Drag
**Priority**: Medium  
**Estimate**: 10 hours  
**Dependencies**: TASK-011

**Description**: Implement column and row resizing by dragging borders.

**Acceptance Criteria**:
- [ ] Detect drag on column border
- [ ] Show resize cursor on hover
- [ ] Update column width in real-time
- [ ] Same for row height
- [ ] Minimum width: 50dp
- [ ] Maximum width: 500dp
- [ ] Persist width/height to database
- [ ] Write resize tests

**Files to Update**:
- `lib/presentation/editor/widgets/column_headers.dart`
- `lib/presentation/editor/widgets/row_headers.dart`
- `test/presentation/resize_test.dart`

---

### TASK-040: Data Validation Rules
**Priority**: Medium  
**Estimate**: 12 hours  
**Dependencies**: TASK-013

**Description**: Implement data validation for cells.

**Acceptance Criteria**:
- [ ] Number range validation (min, max)
- [ ] Date range validation
- [ ] Text length validation
- [ ] Dropdown list validation
- [ ] Custom formula validation
- [ ] Show error message on invalid input
- [ ] Prevent invalid input (optional)
- [ ] Store validation rules in database
- [ ] Write validation tests

**Files to Create**:
- `lib/domain/entities/validation_rule.dart`
- `lib/services/validation/validation_service.dart`
- `test/services/validation_service_test.dart`

---

### TASK-041: Conditional Formatting
**Priority**: Low  
**Estimate**: 12 hours  
**Dependencies**: TASK-013

**Description**: Implement conditional formatting for cells.

**Acceptance Criteria**:
- [ ] Color scale (red to green)
- [ ] Data bars (progress bar in cell)
- [ ] Icon sets (arrows, flags)
- [ ] Custom rules (if value > X, color red)
- [ ] Apply to range
- [ ] Update formatting on cell value change
- [ ] Store rules in database
- [ ] Write formatting tests

**Files to Create**:
- `lib/domain/entities/conditional_format.dart`
- `lib/services/formatting/conditional_format_service.dart`
- `test/services/conditional_format_test.dart`

---

### TASK-042: Auto-fill (Drag Corner)
**Priority**: Medium  
**Estimate**: 10 hours  
**Dependencies**: TASK-015

**Description**: Implement auto-fill by dragging cell corner.

**Acceptance Criteria**:
- [ ] Detect drag on cell corner handle
- [ ] Show preview of filled cells
- [ ] Copy value to range
- [ ] Smart fill (detect pattern: 1, 2, 3, ...)
- [ ] Smart fill for dates (Mon, Tue, Wed, ...)
- [ ] Smart fill for formulas (increment refs)
- [ ] Confirm on release
- [ ] Write auto-fill tests

**Files to Update**:
- `lib/presentation/editor/widgets/grid_widget.dart`
- `lib/services/auto_fill/auto_fill_service.dart`
- `test/services/auto_fill_test.dart`

---

### TASK-043: Basic Charting
**Priority**: Low  
**Estimate**: 16 hours  
**Dependencies**: TASK-013

**Description**: Implement basic chart generation (bar and line charts).

**Acceptance Criteria**:
- [ ] Select data range for chart
- [ ] Generate bar chart
- [ ] Generate line chart
- [ ] Chart title and axis labels
- [ ] Chart colors
- [ ] Embed chart in sheet
- [ ] Export chart as image
- [ ] Write chart tests

**Files to Create**:
- `lib/services/charting/chart_generator.dart`
- `lib/presentation/editor/widgets/chart_widget.dart`
- `test/services/chart_generator_test.dart`

---

## Phase 5: Integration Features (Weeks 14-15)

### TASK-044: Google OAuth Integration
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: None

**Description**: Implement Google OAuth 2.0 authentication.

**Acceptance Criteria**:
- [ ] Add google_sign_in package
- [ ] Configure OAuth consent screen
- [ ] Implement sign-in flow
- [ ] Get access token
- [ ] Refresh token automatically
- [ ] Handle sign-out
- [ ] Store tokens securely (encrypted)
- [ ] Write OAuth tests

**Files to Create**:
- `lib/services/auth/google_auth_service.dart`
- `test/services/google_auth_service_test.dart`

---

### TASK-045: Google Forms API Integration
**Priority**: High  
**Estimate**: 16 hours  
**Dependencies**: TASK-044

**Description**: Fetch Google Forms and responses using Google Forms API.

**Acceptance Criteria**:
- [ ] List user's Google Forms
- [ ] Fetch form structure (questions)
- [ ] Fetch form responses
- [ ] Parse form data to JSON
- [ ] Handle pagination (large response count)
- [ ] Handle API errors
- [ ] Write API integration tests

**Files to Create**:
- `lib/services/integrations/google_forms_service.dart`
- `lib/data/models/google_form_model.dart`
- `test/services/google_forms_service_test.dart`

---

### TASK-046: Google Forms Mapping
**Priority**: High  
**Estimate**: 10 hours  
**Dependencies**: TASK-045

**Description**: Map Google Form responses to spreadsheet.

**Acceptance Criteria**:
- [ ] Create sheet for form
- [ ] Map questions to columns
- [ ] Map responses to rows
- [ ] Handle multiple choice (comma-separated)
- [ ] Handle timestamps
- [ ] Update sheet on new responses
- [ ] Write mapping tests

**Files to Create**:
- `lib/domain/use_cases/import_google_forms_use_case.dart`
- `test/domain/import_google_forms_use_case_test.dart`

---

### TASK-047: Google Forms Auto-sync
**Priority**: Medium  
**Estimate**: 12 hours  
**Dependencies**: TASK-046

**Description**: Implement auto-sync for Google Forms (real-time updates).

**Acceptance Criteria**:
- [ ] Setup webhook for form responses
- [ ] Listen for new response events
- [ ] Append new responses to sheet
- [ ] Show notification on new response
- [ ] Allow user to enable/disable auto-sync
- [ ] Write auto-sync tests

**Files to Create**:
- `lib/services/sync/forms_sync_service.dart`
- `test/services/forms_sync_service_test.dart`

---

### TASK-048: Google Forms Import Screen
**Priority**: Medium  
**Estimate**: 8 hours  
**Dependencies**: TASK-046

**Description**: Create ImportGoogleFormsScreen UI.

**Acceptance Criteria**:
- [ ] Google Sign-In button
- [ ] List user's forms
- [ ] Show form title and response count
- [ ] Select form to import
- [ ] Show import progress
- [ ] Navigate to imported sheet
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/import/import_google_forms_screen.dart`
- `test/presentation/import_google_forms_test.dart`

---

### TASK-049: REST API Configuration UI
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: None

**Description**: Create API endpoint configuration screen.

**Acceptance Criteria**:
- [ ] URL input field
- [ ] HTTP method selector (GET, POST, PUT, DELETE)
- [ ] Auth type selector (None, API Key, Bearer, Basic)
- [ ] Auth credentials input
- [ ] Headers input (key-value pairs)
- [ ] Query params input (key-value pairs)
- [ ] Test connection button
- [ ] Save endpoint button
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/import/api_config_screen.dart`
- `lib/data/models/api_endpoint_config.dart`
- `test/presentation/api_config_screen_test.dart`

---

### TASK-050: REST API Data Fetching
**Priority**: High  
**Estimate**: 10 hours  
**Dependencies**: TASK-049

**Description**: Implement REST API data fetching using Dio.

**Acceptance Criteria**:
- [ ] Send HTTP request with config
- [ ] Handle different auth types
- [ ] Parse JSON response
- [ ] Parse XML response
- [ ] Handle HTTP errors (4xx, 5xx)
- [ ] Handle network errors (timeout, no connection)
- [ ] Write API fetching tests

**Files to Create**:
- `lib/services/integrations/rest_api_service.dart`
- `test/services/rest_api_service_test.dart`

---

### TASK-051: API Field Mapping
**Priority**: High  
**Estimate**: 12 hours  
**Dependencies**: TASK-050

**Description**: Implement API field to column mapping.

**Acceptance Criteria**:
- [ ] Auto-detect field types (string, number, date)
- [ ] Show field mapping UI
- [ ] Allow manual field-to-column mapping
- [ ] Handle nested JSON objects (flatten)
- [ ] Handle arrays (comma-separated or rows)
- [ ] Create sheet with mapped data
- [ ] Write mapping tests

**Files to Create**:
- `lib/presentation/import/api_field_mapping_screen.dart`
- `lib/services/integrations/field_mapper.dart`
- `test/services/field_mapper_test.dart`

---

### TASK-052: API Auto-refresh
**Priority**: Medium  
**Estimate**: 8 hours  
**Dependencies**: TASK-051

**Description**: Implement scheduled auto-refresh for API data.

**Acceptance Criteria**:
- [ ] Schedule API refresh (every 5 min, 1 hour, etc.)
- [ ] Fetch new data on schedule
- [ ] Update sheet with new data
- [ ] Show notification on update
- [ ] Allow user to enable/disable auto-refresh
- [ ] Write auto-refresh tests

**Files to Create**:
- `lib/services/sync/api_sync_service.dart`
- `test/services/api_sync_service_test.dart`

---

## Phase 6: AI Agent & Polish (Week 16)

### TASK-053: AI Agent REST API Server
**Priority**: High  
**Estimate**: 16 hours  
**Dependencies**: TASK-006

**Description**: Implement REST API server for AI agent access (localhost:8080).

**Acceptance Criteria**:
- [ ] Setup shelf HTTP server
- [ ] Implement GET /api/v1/cell/{sheetId}/{rowId}/{columnId}
- [ ] Implement PUT /api/v1/cell/{sheetId}/{rowId}/{columnId}
- [ ] Implement GET /api/v1/row/{sheetId}/{rowId}
- [ ] Implement GET /api/v1/column/{sheetId}/{columnId}
- [ ] Implement GET /api/v1/range/{sheetId}?start=A1&end=C10
- [ ] Implement POST /api/v1/row/{sheetId} (append row)
- [ ] Implement PUT /api/v1/row/{sheetId}/{rowId} (update row)
- [ ] Implement DELETE /api/v1/row/{sheetId}/{rowId}
- [ ] Implement POST /api/v1/query/{sheetId} (query with filters)
- [ ] Implement GET /api/v1/structure/{sheetId}
- [ ] Implement GET /api/v1/dependencies/{sheetId}
- [ ] Implement GET /api/v1/validation/{sheetId}/{columnId}
- [ ] Add API authentication (token-based)
- [ ] Write API tests

**Files to Create**:
- `lib/services/ai_agent/ai_agent_api.dart`
- `lib/services/ai_agent/api_routes.dart`
- `test/services/ai_agent_api_test.dart`

---

### TASK-054: AI Agent API Documentation
**Priority**: Medium  
**Estimate**: 6 hours  
**Dependencies**: TASK-053

**Description**: Write comprehensive API documentation for AI agents.

**Acceptance Criteria**:
- [ ] Document all 14 API endpoints
- [ ] Include request/response examples
- [ ] Document error codes
- [ ] Provide authentication guide
- [ ] Include rate limiting info
- [ ] Add usage examples (curl, Python)
- [ ] Create Postman collection

**Files to Create**:
- `docs/AI_AGENT_API.md`
- `docs/api_examples/python_client.py`
- `docs/api_examples/curl_examples.sh`
- `docs/postman/ai_agent_api.postman_collection.json`

---

### TASK-055: Onboarding Tutorial
**Priority**: Medium  
**Estimate**: 10 hours  
**Dependencies**: TASK-011

**Description**: Create first-launch onboarding tutorial.

**Acceptance Criteria**:
- [ ] Welcome screen with app features
- [ ] Interactive tutorial (tap here, swipe here)
- [ ] Show key features (formulas, import, GPU)
- [ ] Skip tutorial option
- [ ] Show only once (save preference)
- [ ] Write widget tests

**Files to Create**:
- `lib/presentation/onboarding/onboarding_screen.dart`
- `lib/presentation/onboarding/tutorial_overlay.dart`
- `test/presentation/onboarding_test.dart`

---

### TASK-056: Dark Theme Support
**Priority**: Low  
**Estimate**: 8 hours  
**Dependencies**: TASK-009, TASK-011

**Description**: Add dark theme support.

**Acceptance Criteria**:
- [ ] Define dark color palette
- [ ] Update AppTheme with dark theme
- [ ] Support system theme preference
- [ ] Add theme toggle in settings
- [ ] Update all screens for dark theme
- [ ] Test dark theme on all screens

**Files to Update**:
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/app_colors.dart`

---

### TASK-057: Error Handling and Dialogs
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: TASK-009, TASK-011

**Description**: Implement consistent error handling and user dialogs.

**Acceptance Criteria**:
- [ ] Create ErrorDialog widget
- [ ] Create ConfirmDialog widget
- [ ] Create LoadingDialog widget
- [ ] Show errors from repositories
- [ ] Show errors from use cases
- [ ] User-friendly error messages
- [ ] Write dialog tests

**Files to Create**:
- `lib/presentation/common/error_dialog.dart`
- `lib/presentation/common/confirm_dialog.dart`
- `lib/presentation/common/loading_dialog.dart`
- `test/presentation/dialogs_test.dart`

---

### TASK-058: Loading States and Progress
**Priority**: Medium  
**Estimate**: 6 hours  
**Dependencies**: TASK-009, TASK-011

**Description**: Add loading indicators for async operations.

**Acceptance Criteria**:
- [ ] Show loading on sheet list fetch
- [ ] Show progress on import (0-100%)
- [ ] Show loading on formula calculation
- [ ] Show loading on API fetch
- [ ] Disable UI during operations
- [ ] Write loading tests

**Files to Update**:
- `lib/presentation/home/home_screen.dart`
- `lib/presentation/editor/editor_screen.dart`
- `lib/presentation/import/import_screen.dart`

---

### TASK-059: App Size Optimization
**Priority**: Medium  
**Estimate**: 8 hours  
**Dependencies**: All previous tasks

**Description**: Optimize APK size to <50MB.

**Acceptance Criteria**:
- [ ] Enable ProGuard/R8 shrinking
- [ ] Remove unused resources
- [ ] Compress assets
- [ ] Use vector drawables
- [ ] Split APKs by ABI (arm, arm64)
- [ ] Measure APK size
- [ ] Target <50MB

**Files to Update**:
- `android/app/build.gradle.kts`
- `android/app/proguard-rules.pro`

---

### TASK-060: Final Bug Fixes and Polish
**Priority**: Critical  
**Estimate**: 16 hours  
**Dependencies**: All previous tasks

**Description**: Fix all critical and major bugs, polish UI/UX.

**Acceptance Criteria**:
- [ ] Fix all P0 (critical) bugs
- [ ] Fix all P1 (major) bugs
- [ ] Polish UI animations
- [ ] Improve loading states
- [ ] Add haptic feedback
- [ ] Improve error messages
- [ ] Test on 5+ devices
- [ ] All tests passing

---

## Phase 7: Release Preparation (Week 17)

### TASK-061: Performance Testing
**Priority**: Critical  
**Estimate**: 12 hours  
**Dependencies**: TASK-060

**Description**: Comprehensive performance testing on multiple devices.

**Acceptance Criteria**:
- [ ] Test on Android 7.0 (API 24)
- [ ] Test on Android 14 (API 34)
- [ ] Test on low-end device (2GB RAM)
- [ ] Test on mid-range device (4GB RAM)
- [ ] Test on high-end device (8GB RAM)
- [ ] Test with 1,000 cells
- [ ] Test with 10,000 cells
- [ ] Test with 100,000 cells
- [ ] Measure frame time (target <16ms)
- [ ] Measure memory usage (target <200MB)
- [ ] Document results

**Files to Create**:
- `docs/PERFORMANCE_TEST_RESULTS.md`

---

### TASK-062: Play Store Assets
**Priority**: High  
**Estimate**: 8 hours  
**Dependencies**: None

**Description**: Create all assets for Play Store listing.

**Acceptance Criteria**:
- [ ] App icon (512×512 PNG)
- [ ] Feature graphic (1024×500 PNG)
- [ ] Screenshots (4-8 images, phone)
- [ ] Screenshots (optional, tablet)
- [ ] Promo video (optional, YouTube)

**Files to Create**:
- `play_store_assets/icon.png`
- `play_store_assets/feature_graphic.png`
- `play_store_assets/screenshots/*.png`

---

### TASK-063: Play Store Listing
**Priority**: High  
**Estimate**: 6 hours  
**Dependencies**: TASK-062

**Description**: Write Play Store listing text.

**Acceptance Criteria**:
- [ ] App title (max 50 chars)
- [ ] Short description (max 80 chars)
- [ ] Full description (max 4000 chars)
- [ ] Highlight key features
- [ ] Add keywords for SEO
- [ ] Select category (Productivity)
- [ ] Add content rating
- [ ] Add privacy policy URL

**Files to Create**:
- `docs/PLAY_STORE_LISTING.md`

---

### TASK-064: Privacy Policy
**Priority**: Critical  
**Estimate**: 4 hours  
**Dependencies**: None

**Description**: Write privacy policy document.

**Acceptance Criteria**:
- [ ] What data is collected
- [ ] How data is used
- [ ] Data storage (local only)
- [ ] Third-party services (Google, APIs)
- [ ] User rights
- [ ] Contact information
- [ ] Publish on website or GitHub Pages

**Files to Create**:
- `docs/PRIVACY_POLICY.md`

---

### TASK-065: Signed APK Generation
**Priority**: Critical  
**Estimate**: 4 hours  
**Dependencies**: TASK-060

**Description**: Generate signed release APK for Play Store.

**Acceptance Criteria**:
- [ ] Create keystore file
- [ ] Configure signing in build.gradle
- [ ] Build release APK
- [ ] Test APK installation
- [ ] Verify ProGuard working
- [ ] Measure APK size (<50MB)

**Files to Update**:
- `android/app/build.gradle.kts`
- `android/key.properties` (do not commit)

---

### TASK-066: Play Store Submission
**Priority**: Critical  
**Estimate**: 4 hours  
**Dependencies**: TASK-063, TASK-064, TASK-065

**Description**: Submit app to Play Store (Internal Testing).

**Acceptance Criteria**:
- [ ] Create Play Console account
- [ ] Upload signed APK
- [ ] Fill app details
- [ ] Add screenshots and graphics
- [ ] Submit for review (Internal Testing)
- [ ] Test with internal testers
- [ ] Fix issues from feedback
- [ ] Submit for Production

---

## Summary

**Total Tasks**: 66  
**Estimated Total Time**: ~600 hours (~15 weeks with 1 developer)  

**Critical Path**:
1. Database + Entities (TASK-001 to TASK-006)
2. Native Layer + Vulkan (TASK-007 to TASK-008)
3. UI Foundation (TASK-009 to TASK-015)
4. Formula Engine (TASK-018 to TASK-020)
5. GPU Rendering (TASK-021 to TASK-025)
6. GPU Compute (TASK-026 to TASK-028)
7. Import/Export (TASK-031 to TASK-036)
8. AI Agent API (TASK-053)
9. Release (TASK-061 to TASK-066)

**Risk Areas**:
- Vulkan implementation complexity (TASK-008, TASK-021 to TASK-025)
- GPU compute shader compilation (TASK-027)
- Performance targets (60 FPS, <200MB memory)
- Play Store approval

**Next Steps**:
1. Start with TASK-001 (Database Schema)
2. Proceed sequentially through Phase 1
3. Regularly run tests and benchmarks
4. Adjust estimates based on actual progress
