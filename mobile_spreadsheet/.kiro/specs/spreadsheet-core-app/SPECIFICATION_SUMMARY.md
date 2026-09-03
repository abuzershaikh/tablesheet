# 📋 Mobile Spreadsheet - Complete Specification Summary

## 📱 Project Overview

**Name**: Mobile Spreadsheet  
**Package**: com.tablenotes.sheets.excelsheet.spreadsheet  
**Platform**: Android Only (API 24+)  
**Tech Stack**: Flutter + Kotlin + C++ NDK + Vulkan  
**Status**: ✅ Requirements & Design Complete  

---

## 🎯 Core Features

### 1. **Home Page** - FAB & Sheet Cards
```
Features:
├── Floating Action Button (FAB) - Bottom Right
│   ├── Create New Sheet
│   ├── Import from Excel (.xlsx, .xls)
│   ├── Import from CSV
│   ├── Import from Google Forms
│   └── Import from REST API
│
├── Sheet Preview Cards (Grid/List View)
│   ├── Thumbnail (first 5×5 cells)
│   ├── Sheet name
│   ├── Last modified date
│   ├── File size & row/column count
│   ├── 3-dot menu (Open, Rename, Delete, Duplicate, Share)
│   ├── Tap → Open editor
│   ├── Long-press → Multi-select
│   └── Swipe-left → Delete with 5s undo
│
└── Search & Sort
    ├── Search by name
    └── Sort: Name, Date Modified, Date Created
```

### 2. **Spreadsheet Editor** - Main Grid
```
Layout:
┌─────────────────────────────────────────┐
│ 🔙  Sheet Name (4)              🔍     │  ← App Bar
├─────────────────────────────────────────┤
│ ☰  Column 1  Column 2  Column 3  +     │  ← Column Headers
├──┬──────────┬──────────┬──────────┬────┤
│1 │ Cell A1  │ Cell B1  │ Cell C1  │    │
├──┼──────────┼──────────┼──────────┼────┤
│2 │ Cell A2  │ Cell B2  │ Cell C2  │    │
├──┼──────────┼──────────┼──────────┼────┤
│3 │ Cell A3  │ Cell B3  │ Cell C3  │    │
├──┼──────────┼──────────┼──────────┼────┤
│+ │          │          │          │    │  ← Add Row
│  │   Scrollable Grid Area         │    │
├─────────────────────────────────────────┤
│  Sheet1  Sheet2  Sheet3  +              │  ← Sheet Tabs
├─────────────────────────────────────────┤
│  ⚏   🔽   📋   🔗   ⋮                  │  ← Bottom Toolbar
└─────────────────────────────────────────┘

Features:
├── Default: 1000 rows × 26 columns (A-Z)
├── Expandable dynamically on scroll
├── Cell size: 120dp × 52dp (resizable)
├── Selection: Single, Range, Multi-range
├── Frozen rows/columns support
└── Virtual scrolling (60+ FPS with Vulkan)
```

### 3. **Column Properties** - Bottom Sheet
```
When Column Header Clicked:

┌─────────────────────────────────────────┐
│  ← Edit Column Properties        Save   │
├─────────────────────────────────────────┤
│  Column Name: [Column 1        ✕]      │
│                                         │
│  COLUMN TYPE:                           │
│  [Tt] [$] [📅] [🖼️] [☑️] ...           │
│   ▬▬                                    │
│                                         │
│  COLUMN WIDTH:  1.0                     │
│  [-] ▓▓▓░░░░░░░░░░░░ [+]               │
│                                         │
│  STYLES:                                │
│  [B] [I] [≡] [🎨] [A] [↻]              │
│  [Sample Text Preview______]            │
│                                         │
│  📊 Summary on Graph                    │
│  ➕ Insert Column on left               │
│  👁️ Visible in table          ⭕       │
└─────────────────────────────────────────┘

Properties:
├── Column Name (custom or A, B, C...)
├── Column Type: Text, Amount, Number, Date, Time, Checkbox, Image
├── Width: 0.5x to 5.0x (slider with live preview)
├── Styles: Bold, Italic, Alignment, Colors, Rotation
├── Actions: Insert, Hide/Show, Chart
└── Auto-save on changes
```

### 4. **Cell Editing**
```
Interactions:
├── Single Tap → Select cell
├── Double Tap → Edit mode (green border)
├── Long Press → Context menu
├── Drag → Select range
└── Drag Fill Handle → Auto-fill pattern

Edit Mode:
├── Formula Bar appears (fx icon + input + ✓✕)
├── In-cell cursor for text editing
├── Auto-complete for functions
├── Real-time formula evaluation
└── Press Enter → Move to cell below
```

### 5. **Formulas & Functions** - 30+ Functions
```
Categories:
├── Math: SUM, AVERAGE, COUNT, MIN, MAX, ROUND, SQRT, POWER, ABS, MOD
├── Text: CONCATENATE, LEFT, RIGHT, MID, LEN, UPPER, LOWER
├── Logical: IF, AND, OR, NOT
├── Date: TODAY, NOW, DATE, YEAR, MONTH, DAY
└── Lookup: VLOOKUP, HLOOKUP, INDEX, MATCH

Features:
├── Formula parser with syntax validation
├── Dependency graph for recalculation
├── Circular reference detection
├── GPU-accelerated bulk calculations
└── Real-time updates on data change
```

---

## 🗄️ Database Schema (SQLite with UUIDs)

### Tables Structure
```sql
-- Sheets
CREATE TABLE sheets (
    sheet_id TEXT PRIMARY KEY,      -- UUID
    spreadsheet_id TEXT,
    sheet_name TEXT,
    created_at INTEGER,
    modified_at INTEGER
);

-- Rows (Persistent UUIDs)
CREATE TABLE rows (
    row_id TEXT PRIMARY KEY,        -- UUID (never changes)
    sheet_id TEXT,
    row_number INTEGER,             -- Display position (changes)
    created_at INTEGER,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id)
);

-- Columns
CREATE TABLE columns (
    column_id TEXT PRIMARY KEY,     -- UUID
    sheet_id TEXT,
    column_name TEXT,               -- A, B, C or custom name
    column_number INTEGER,
    column_type TEXT,               -- text, number, date, etc.
    width REAL DEFAULT 1.0,
    styles_json TEXT,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id)
);

-- Cells (Sparse Storage)
CREATE TABLE cells (
    cell_id TEXT PRIMARY KEY,       -- UUID
    sheet_id TEXT,
    row_id TEXT,
    column_id TEXT,
    value TEXT,
    formula TEXT,
    data_type TEXT,
    format_json TEXT,
    created_at INTEGER,
    modified_at INTEGER,
    FOREIGN KEY (row_id) REFERENCES rows(row_id),
    FOREIGN KEY (column_id) REFERENCES columns(column_id)
);

-- API Endpoints
CREATE TABLE api_endpoints (
    endpoint_id TEXT PRIMARY KEY,
    name TEXT,
    url TEXT,
    method TEXT,
    auth_type TEXT,
    auth_credentials TEXT,
    field_mapping_json TEXT,
    auto_refresh_interval INTEGER,
    last_sync INTEGER
);

-- Google Forms
CREATE TABLE google_forms (
    form_id TEXT PRIMARY KEY,
    form_title TEXT,
    sheet_id TEXT,
    field_mapping_json TEXT,
    auto_sync_enabled INTEGER DEFAULT 0,
    last_sync INTEGER,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id)
);

-- Indexes
CREATE INDEX idx_cells_lookup ON cells(sheet_id, row_id, column_id);
CREATE INDEX idx_rows_sheet ON rows(sheet_id, row_number);
CREATE INDEX idx_columns_sheet ON columns(sheet_id, column_number);
```

### Key Benefits of UUID System
```
✓ IDs never change (even on insert/delete)
✓ Safe for AI agents to reference
✓ Formulas use stable references
✓ Easy to sync across devices
✓ No ID conflicts on merge
```

---

## 🤖 AI Agent Data Access API

### Methods Available
```dart
// Read Operations
getCellValue(sheetId, rowId, columnId) → value
getRowData(sheetId, rowId) → Map<String, dynamic>
getColumnData(sheetId, columnId) → List<dynamic>
getRangeData(sheetId, startRow, startCol, endRow, endCol) → List<List>
queryData(sheetId, filterCriteria) → List<Row>

// Write Operations
setCellValue(sheetId, rowId, columnId, value) → success
updateRow(sheetId, rowId, rowData) → success
appendRow(sheetId, rowData) → newRowId
deleteRow(sheetId, rowId) → success

// Metadata
getSheetStructure(sheetId) → ColumnInfo[]
getFormulaDependencies(sheetId) → DependencyGraph
getCellFormatting(sheetId, rowId, columnId) → FormatInfo
getValidationRules(sheetId, columnId) → ValidationRule[]

// Performance
Read: < 50ms
Write: < 100ms
```

### Cell Addressing Format
```
{sheet_id}:{row_id}:{column_id}

Example:
"a1b2c3d4-e5f6-7890-abcd-ef0123456789:
 r1r2r3r4-r5r6-r7r8-r9r0-r1r2r3r4r5r6:
 c1c2c3c4-c5c6-c7c8-c9c0-c1c2c3c4c5c6"
```

---

## 🌐 Integration Features

### 1. **Google Forms Integration**
```
Features:
├── OAuth 2.0 authentication
├── List available forms
├── Import all responses with metadata
├── Support: Multiple choice, Checkbox, Text, Ratings
├── Auto-sync every 15 minutes (optional)
├── Store form_id for re-sync
└── Map fields → columns automatically

Data Imported:
├── Response timestamp
├── Responder email
├── Response ID
├── All form fields
└── Response metadata
```

### 2. **REST API Integration**
```
Features:
├── REST API configuration dialog
├── Support: GET requests with params
├── Auth: API Key, Bearer Token, Basic Auth
├── Parse: JSON & XML responses
├── Field mapping UI (API → Columns)
├── Save endpoints for reuse
├── Auto-refresh with custom intervals
└── Response history with timestamps

Workflow:
1. Enter API URL
2. Configure auth
3. Test connection
4. View response preview
5. Map fields to columns
6. Import data
7. Schedule auto-refresh (optional)
```

### 3. **Excel/CSV Import**
```
Excel (.xlsx, .xls):
├── Parse multiple sheets
├── Import data + basic formatting
├── Preserve formulas (basic)
├── Convert dates properly
└── Preview before import

CSV:
├── RFC 4180 compliant parser
├── Auto-detect delimiter
├── Header row detection
├── Encoding support (UTF-8, etc.)
└── Preview with column mapping
```

---

## ⚡ Performance Features (Vulkan GPU)

### Rendering Performance
```
Without Vulkan:  30-45 FPS (CPU rendering)
With Vulkan:     60-120 FPS (GPU rendering)

Optimization:
├── Virtual viewport (only render visible cells)
├── Cell recycling (reuse widgets)
├── Pre-rendering adjacent cells
├── GPU command buffers
├── Async rendering pipeline
└── Memory pooling

Battery Impact:
├── CPU Only:  15-20% per hour
├── GPU Mode:  8-12% per hour
└── Savings:   40-50% less battery
```

### Calculation Performance
```
GPU Compute Shaders:
├── SUM(10K cells):     50ms → 5ms  (10x faster)
├── AVERAGE(10K cells): 50ms → 5ms  (10x faster)
├── Matrix 100×100:     500ms → 20ms (25x faster)
└── Bulk operations:    200ms → 15ms (13x faster)

Trigger:
├── Use GPU if range > 1000 cells
├── Parallel reduction algorithms
├── Fallback to CPU if GPU unavailable
└── Automatic optimization
```

### Data Handling
```
Capacity:
├── Cells: 100,000+ (with smooth scrolling)
├── Rows: 10,000+ (60 FPS maintained)
├── Sheets: 50 per spreadsheet
└── Memory: 50MB cell cache

Storage:
├── Sparse storage (only non-empty cells)
├── Lazy loading on scroll
├── Batch commits every 30s
├── Indexed queries (<10ms)
└── Auto-save without UI lag
```

---

## 🏗️ Code Architecture (Feature-Based)

### Folder Structure
```
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── utils/
│   └── network/
│
├── data/
│   ├── models/                  # Data classes
│   ├── repositories/            # Implementations
│   ├── data_sources/
│   │   ├── local/              # SQLite ops
│   │   └── remote/             # API calls
│   └── mappers/                # DTO ↔ Entity
│
├── domain/
│   ├── entities/               # Business objects
│   ├── repositories/           # Interfaces
│   └── use_cases/
│       ├── sheet_management/
│       ├── cell_operations/
│       ├── formula_engine/
│       ├── import_export/
│       ├── api_integration/    # 🆕 REST API
│       └── ai_agent/           # 🆕 AI Access
│
├── presentation/
│   ├── home/
│   │   ├── widgets/
│   │   │   ├── fab_menu.dart
│   │   │   ├── sheet_card.dart
│   │   │   └── search_bar.dart
│   │   ├── home_screen.dart
│   │   └── home_controller.dart
│   │
│   ├── editor/
│   │   ├── widgets/
│   │   │   ├── grid/
│   │   │   │   ├── cell_widget.dart
│   │   │   │   ├── column_header.dart
│   │   │   │   └── row_header.dart
│   │   │   ├── toolbar/
│   │   │   │   ├── top_toolbar.dart
│   │   │   │   └── bottom_toolbar.dart
│   │   │   ├── formula_bar/
│   │   │   │   └── formula_bar.dart
│   │   │   └── cell_editor/
│   │   │       └── editor_widget.dart
│   │   ├── bottom_sheets/
│   │   │   ├── column_properties.dart
│   │   │   └── row_properties.dart
│   │   ├── editor_screen.dart
│   │   └── editor_controller.dart
│   │
│   ├── import/
│   │   ├── excel_import/
│   │   ├── csv_import/
│   │   ├── api_import/
│   │   └── google_forms_import/
│   │
│   └── shared/
│       └── widgets/
│
└── services/
    ├── storage_service.dart
    ├── formula_service.dart
    ├── rendering_service.dart
    ├── api_service.dart           # 🆕
    └── ai_agent_service.dart      # 🆕

Benefits:
✓ Feature isolation (easy to update)
✓ Clear separation of concerns
✓ Testable business logic
✓ Scalable architecture
✓ Easy onboarding for new devs
```

---

## 🎨 UI Design System

### Colors
```dart
// Primary
primary:         #1976D2  // Blue
primaryDark:     #004BA0
primaryLight:    #E3F2FD

// Accent
accent:          #4CAF50  // Green
accentDark:      #388E3C
accentLight:     #C8E6C9

// Background
surface:         #FFFFFF  // White
background:      #FAFAFA  // Off-white
header:          #F5F5F5  // Light gray
divider:         #E0E0E0

// Text
textPrimary:     #212121
textSecondary:   #757575
textHint:        #BDBDBD
textError:       #C62828

// Status
success:         #4CAF50
warning:         #FFC107
error:           #F44336
info:            #2196F3
```

### Typography
```dart
// Headings
h1: 24sp, Bold
h2: 20sp, SemiBold
h3: 18sp, Medium

// Body
body1: 16sp, Regular
body2: 14sp, Regular
caption: 12sp, Regular

// Monospace (for formulas)
code: 14sp, Monospace
```

### Component Sizes
```dart
// Cells
defaultCellWidth:   120dp
defaultCellHeight:  52dp
minCellSize:        60dp × 30dp
maxCellSize:        400dp × 200dp

// Headers
appBarHeight:       56dp
columnHeaderHeight: 48dp
rowHeaderWidth:     48dp
formulaBarHeight:   48dp
sheetTabsHeight:    40dp
bottomToolbar:      56dp

// Touch Targets
minTouchTarget:     48dp × 48dp

// Spacing
paddingSmall:       8dp
paddingMedium:      16dp
paddingLarge:       24dp

// Borders
cellBorder:         0.5dp
selectedBorder:     2dp
```

---

## 📊 Requirements Summary

**Total Requirements**: 33  
**Acceptance Criteria**: 350+  
**Key Features**: 15+  

### Categories:
1. ✅ File Management (FAB, Cards, Search)
2. ✅ Grid Structure (Headers, Cells, Selection)
3. ✅ Cell Editing (Input, Formula Bar)
4. ✅ Cell Formatting (Styles, Colors, Alignment)
5. ✅ Data Persistence (SQLite, UUID System)
6. ✅ Formulas (30+ Functions, Parser, Engine)
7. ✅ Vulkan Rendering (60+ FPS, GPU Acceleration)
8. ✅ GPU Calculations (10x faster bulk ops)
9. ✅ Multi-Sheet Management (Tabs, Navigation)
10. ✅ Copy/Cut/Paste (With formula adjustment)
11. ✅ Fill Handle (Pattern detection, Auto-fill)
12. ✅ Find & Replace (Search, Case-sensitive)
13. ✅ Sort & Filter (Column filters, Multi-sort)
14. ✅ Data Validation (Rules, Dropdowns)
15. ✅ Conditional Formatting (Rules, Auto-style)
16. ✅ Charts (Line, Bar, Pie)
17. ✅ Import/Export (Excel, CSV, Forms, API)
18. ✅ Auto-Save (Every 30s, No lag)
19. ✅ Undo/Redo (50 operations)
20. ✅ Performance (Launch <2s, Open <1s)
21. ✅ Material Design 3 (Modern UI)
22. ✅ Sharing (Link, Email, PDF)
23. ✅ FAB Menu (5 quick actions)
24. ✅ Sheet Cards (Preview, Quick actions)
25. ✅ Google Forms (OAuth, Auto-sync)
26. ✅ REST API (Config, Auth, Auto-refresh)
27. ✅ AI Agent API (14 methods, UUID-based)
28. ✅ UUID System (Persistent IDs)
29. ✅ Modular Architecture (Feature-based)
30. ✅ Column Properties (Bottom sheet)
31. ✅ Row Properties (Bottom sheet)
32. ✅ Context Menus (Long-press actions)
33. ✅ Sheet Tabs (Multi-sheet navigation)

---

## 🚀 Performance Targets

### Launch & Load
- App launch: **< 2 seconds**
- Open spreadsheet: **< 1 second**
- Switch sheets: **< 300ms**

### Rendering
- Scrolling FPS: **60+ (up to 120)**
- Cell selection: **< 16ms** (instant)
- Virtual viewport update: **< 16ms**

### Calculations
- Typical formula: **< 100ms**
- Bulk operations (10K cells): **< 50ms** (GPU)
- Recalculation: **< 200ms** (complex)

### Data Operations
- Auto-save: **No visible lag**
- Database query: **< 10ms** (indexed)
- Import 1000 rows: **< 2 seconds**

### Memory
- Cell cache: **Max 50MB**
- Total app: **< 200MB** (typical usage)
- Support: **100,000+ cells**

---

## 📱 Device Requirements

### Minimum
- Android 7.0 (API 24)
- 2GB RAM
- 100MB free storage
- ARM or x86 processor

### Recommended (for Vulkan)
- Android 9.0+ (API 28+)
- 4GB+ RAM
- Vulkan 1.1+ GPU
- Snapdragon 600+ / Mali G71+ GPU

### Supported Devices
✅ Samsung Galaxy S7+ (2016+)  
✅ Google Pixel (all)  
✅ OnePlus 3+ (2016+)  
✅ Most 2017+ flagships  

---

## ✅ Implementation Checklist

### Phase 1: Foundation (Weeks 1-2)
- [ ] Setup Flutter project structure
- [ ] Implement modular architecture
- [ ] Setup SQLite database with UUID schema
- [ ] Create data models and repositories
- [ ] Implement storage service

### Phase 2: Basic UI (Weeks 3-4)
- [ ] Home screen with FAB
- [ ] Sheet cards (grid/list view)
- [ ] Basic grid rendering
- [ ] Column/row headers
- [ ] Cell selection
- [ ] Navigation between screens

### Phase 3: Core Editing (Weeks 5-6)
- [ ] Cell input and editing
- [ ] Formula bar
- [ ] Basic formulas (SUM, AVERAGE, etc.)
- [ ] Formula parser
- [ ] Copy/cut/paste
- [ ] Undo/redo

### Phase 4: Advanced Features (Weeks 7-8)
- [ ] Column properties bottom sheet
- [ ] Row properties bottom sheet
- [ ] Cell formatting (colors, fonts)
- [ ] Fill handle with auto-fill
- [ ] Context menus
- [ ] Sort and filter

### Phase 5: Vulkan Integration (Weeks 9-10)
- [ ] Vulkan renderer setup
- [ ] Virtual viewport rendering
- [ ] GPU-accelerated scrolling
- [ ] GPU compute shaders
- [ ] Performance optimization

### Phase 6: Import/Export (Weeks 11-12)
- [ ] Excel import/export
- [ ] CSV import/export
- [ ] Google Forms integration
- [ ] REST API integration
- [ ] Field mapping UI

### Phase 7: AI Agent API (Week 13)
- [ ] AI agent service
- [ ] Data access methods
- [ ] UUID-based addressing
- [ ] Metadata access
- [ ] Documentation

### Phase 8: Polish & Testing (Weeks 14-16)
- [ ] Performance testing
- [ ] UI/UX refinement
- [ ] Bug fixes
- [ ] Accessibility
- [ ] Documentation
- [ ] Beta testing

---

## 📚 Documentation Files

1. ✅ `requirements.md` - Complete requirements (33 requirements, 350+ criteria)
2. ✅ `COLUMN_PROPERTIES_UI.md` - Column/Row properties design
3. ✅ `SPREADSHEET_EDITOR_UI.md` - Main editor UI spec
4. ✅ `CUSTOM_RENDERING_ENGINE.md` - **Custom Vulkan graphics engine** ⭐
5. ✅ `SPECIFICATION_SUMMARY.md` - This file
6. ⏳ `design.md` - Technical design (Next step)
7. ⏳ `tasks.md` - Implementation tasks (After design)

---

## 🎯 Next Steps

1. **Review Specifications**
   - Read all requirement documents
   - Verify completeness
   - Request changes if needed

2. **Generate Technical Design**
   - System architecture
   - Component diagrams
   - Data flow
   - API contracts
   - Performance strategy

3. **Create Task Breakdown**
   - Detailed implementation tasks
   - Dependencies
   - Time estimates
   - Milestones

4. **Start Implementation**
   - Follow modular architecture
   - Test each feature
   - Iterate based on feedback

---

**Status**: ✅ Specifications Complete  
**Version**: 1.0  
**Last Updated**: July 24, 2026  
**Ready For**: Technical Design Phase

🚀 **Let's build an amazing spreadsheet app!**
