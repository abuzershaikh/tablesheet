# Spreadsheet Editor UI - Complete Specification

## 📱 Overview
This document details the complete UI design for the spreadsheet editor screen based on Google Sheets/Quick Table style interface.

---

## 🎨 Full Screen Layout

```
┌─────────────────────────────────────────┐
│ 🔙  Quick Table (4)            🔍       │  ← Top App Bar (Blue)
├─────────────────────────────────────────┤
│ ☰  Column 1  Column 2  Column 3  +     │  ← Column Headers
├──┬──────────┬──────────┬──────────┬────┤
│1 │          │          │          │    │
├──┼──────────┼──────────┼──────────┼────┤
│2 │          │          │          │    │  ← Grid Cells
├──┼──────────┼──────────┼──────────┼────┤
│3 │          │          │          │    │
├──┼──────────┼──────────┼──────────┼────┤
│  │          │          │          │    │
│  │          │          │          │    │
│  │    Spreadsheet Grid Area       │    │
│  │    (Scrollable)                │    │
│  │          │          │          │    │
│  │          │          │          │    │
│+ │          │          │          │    │  ← Add Row Button
│  │          │          │          │    │
│  │          │          │          │    │
│  │          │          │          │    │
│  │          │          │          │    │
├─────────────────────────────────────────┤
│  ⚏   🔽   📋   🔗   ⋮                  │  ← Bottom Toolbar
├─────────────────────────────────────────┤
│          ☰   ◻   ◁                     │  ← System Navigation
└─────────────────────────────────────────┘
```

---

## 🎯 Component Breakdown

### 1. Top App Bar (Header)
```
┌─────────────────────────────────────────┐
│ 🔙  Quick Table (4)            🔍       │
└─────────────────────────────────────────┘

Features:
├── Background: Primary Blue (#1976D2)
├── Height: 56dp
├── Elevation: 4dp
│
├── Left Side:
│   ├── Back Arrow (←) - Navigate to home
│   ├── Menu Icon (☰) - Optional hamburger menu
│   └── Sheet Title: "Quick Table (4)"
│       ├── Font: 20sp, Medium weight
│       ├── Color: White
│       └── Badge: (4) = Sheet count or row count
│
└── Right Side:
    ├── Search Icon (🔍) - Find & replace
    ├── More Options (⋮) - 3-dot menu
    │   ├── Share
    │   ├── Export
    │   ├── Print
    │   ├── Properties
    │   └── Settings
    └── Spacing: 16dp from edge
```

**Title Badge Options:**
- `(4)` = Number of sheets
- `(125 rows)` = Total rows
- `Last edited 2 min ago`

---

### 2. Column Headers Row
```
┌─────────────────────────────────────────┐
│ ☰  Column 1  Column 2  Column 3  +     │
└─────────────────────────────────────────┘

Structure:
├── Background: Light Gray (#F5F5F5)
├── Height: 48dp
├── Border Bottom: 1dp solid #E0E0E0
│
├── Menu Icon (☰) - Left corner
│   ├── Size: 24×24dp
│   ├── Opens: Sheet list / View options
│   └── Action: Show all sheets or grid view toggle
│
├── Column Headers (Dynamic)
│   ├── Text: "Column 1", "Column 2", "Column 3"
│   ├── Font: 14sp, Medium weight
│   ├── Color: #424242 (Dark Gray)
│   ├── Padding: 12dp horizontal
│   ├── Min Width: 100dp
│   ├── Max Width: 300dp
│   │
│   ├── Interaction:
│   │   ├── Tap → Open Column Properties Bottom Sheet
│   │   ├── Long Press → Column selection mode
│   │   └── Drag Border → Resize column width
│   │
│   └── Visual States:
│       ├── Normal: #F5F5F5 background
│       ├── Hover: #EEEEEE background
│       ├── Selected: #E3F2FD background (Light Blue)
│       └── Active: #BBDEFB background
│
└── Add Column Button (+)
    ├── Icon: Plus sign
    ├── Size: 40×40dp
    ├── Position: Right-aligned
    ├── Action: Insert new column
    └── Style: Icon only, no background
```

**Column Header Variants:**
```dart
// Default state
Container(
  padding: EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: Color(0xFFF5F5F5),
    border: Border(
      right: BorderSide(color: Color(0xFFE0E0E0)),
      bottom: BorderSide(color: Color(0xFFE0E0E0)),
    ),
  ),
  child: Text('Column 1'),
)

// Selected state
Container(
  decoration: BoxDecoration(
    color: Color(0xFFE3F2FD),
    border: Border.all(color: Color(0xFF1976D2), width: 2),
  ),
)
```

---

### 3. Row Headers (Left Side)
```
┌──┐
│1 │
├──┤
│2 │
├──┤
│3 │
├──┤
│4 │
├──┤
│+ │  ← Add Row Button
└──┘

Features:
├── Background: Light Gray (#F5F5F5)
├── Width: 48dp (fixed)
├── Border Right: 1dp solid #E0E0E0
│
├── Row Number Cell:
│   ├── Text: "1", "2", "3"...
│   ├── Font: 14sp, Regular
│   ├── Color: #616161
│   ├── Alignment: Center
│   ├── Height: Matches row height (default 52dp)
│   │
│   ├── Interaction:
│   │   ├── Tap → Select entire row
│   │   ├── Double Tap → Open Row Properties
│   │   └── Long Press → Multi-row selection mode
│   │
│   └── Visual States:
│       ├── Normal: #F5F5F5
│       ├── Hover: #EEEEEE
│       ├── Selected: #E3F2FD (Light Blue)
│       └── Active: #BBDEFB
│
└── Add Row Button (+):
    ├── Position: Fixed at bottom-left
    ├── Size: 48×48dp
    ├── Icon: White plus on blue circle
    ├── Background: #1976D2 (Primary Blue)
    ├── Elevation: 6dp
    ├── Action: Append new row at end
    └── Animation: Scale on press
```

---

### 4. Grid Cells (Main Area)
```
┌────────────┬────────────┬────────────┐
│   Cell     │   Cell     │   Cell     │
│   (Empty)  │   (Empty)  │   (Empty)  │
├────────────┼────────────┼────────────┤
│   Cell     │   Cell     │   Cell     │
│   Data     │   Formula  │   Number   │
└────────────┴────────────┴────────────┘

Cell Specifications:
├── Default Size: 120dp × 52dp
├── Min Size: 60dp × 30dp
├── Max Size: 400dp × 200dp
├── Padding: 8dp
├── Border: 0.5dp solid #E0E0E0
│
├── Content Alignment:
│   ├── Text: Left-aligned, Middle vertical
│   ├── Number: Right-aligned, Middle vertical
│   ├── Date: Center-aligned, Middle vertical
│   └── Checkbox: Center-aligned, Center vertical
│
├── Cell States:
│   ├── Empty:
│   │   ├── Background: White (#FFFFFF)
│   │   └── Placeholder: Faint grid lines
│   │
│   ├── Filled:
│   │   ├── Background: White
│   │   ├── Text: #212121
│   │   └── Border: #E0E0E0
│   │
│   ├── Selected:
│   │   ├── Background: #E3F2FD (Light Blue)
│   │   ├── Border: 2dp solid #1976D2 (Blue)
│   │   ├── Corner Handle: 6×6dp blue square (bottom-right)
│   │   └── Fill Handle: Drag to auto-fill
│   │
│   ├── Editing:
│   │   ├── Background: White
│   │   ├── Border: 2dp solid #4CAF50 (Green)
│   │   ├── Cursor: Blinking cursor
│   │   └── Formula Bar: Active at top
│   │
│   ├── Error:
│   │   ├── Background: #FFEBEE (Light Red)
│   │   ├── Text: #C62828 (Red)
│   │   └── Icon: ⚠️ Warning triangle
│   │
│   └── Formula:
│       ├── Background: White
│       ├── Text: Result in black
│       ├── Indicator: Tiny "fx" badge in corner
│       └── On Edit: Shows formula in cell
│
├── Cell Interactions:
│   ├── Single Tap: Select cell
│   ├── Double Tap: Enter edit mode
│   ├── Long Press: Show context menu
│   ├── Drag: Select range
│   └── Drag Fill Handle: Auto-fill pattern
│
└── Cell Types:
    ├── Text Cell: Left-aligned, wraps if enabled
    ├── Number Cell: Right-aligned, formatted
    ├── Date Cell: Center-aligned, date format
    ├── Checkbox Cell: Centered checkbox
    ├── Image Cell: Thumbnail with expand icon
    └── Formula Cell: Computed value display
```

**Cell Rendering Code:**
```dart
class SpreadsheetCell extends StatelessWidget {
  final CellData data;
  final bool isSelected;
  final bool isEditing;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => selectCell(),
      onDoubleTap: () => enterEditMode(),
      onLongPress: () => showContextMenu(),
      child: Container(
        width: data.width,
        height: data.height,
        decoration: BoxDecoration(
          color: isSelected 
            ? Color(0xFFE3F2FD) 
            : Colors.white,
          border: Border.all(
            color: isEditing 
              ? Color(0xFF4CAF50) 
              : Color(0xFFE0E0E0),
            width: isSelected || isEditing ? 2 : 0.5,
          ),
        ),
        padding: EdgeInsets.all(8),
        child: Align(
          alignment: getAlignment(data.type),
          child: Text(
            data.displayValue,
            style: TextStyle(
              fontSize: 14,
              color: data.hasError 
                ? Color(0xFFC62828) 
                : Color(0xFF212121),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### 5. Formula Bar (Conditional)
```
┌─────────────────────────────────────────┐
│ fx  =SUM(A1:A10)                   ✓  ✕ │
└─────────────────────────────────────────┘

Features:
├── Position: Below column headers (appears on edit)
├── Height: 48dp
├── Background: #FAFAFA
├── Border: 1dp solid #E0E0E0
│
├── Components:
│   ├── Function Icon (fx):
│   │   ├── Size: 20×20dp
│   │   ├── Color: #1976D2
│   │   └── Action: Show function picker
│   │
│   ├── Input Field:
│   │   ├── Expands full width
│   │   ├── Text: Formula or cell value
│   │   ├── Font: 14sp, Monospace
│   │   ├── Placeholder: "Enter value or formula"
│   │   └── Auto-complete: Function suggestions
│   │
│   ├── Confirm Button (✓):
│   │   ├── Color: Green
│   │   └── Action: Apply changes
│   │
│   └── Cancel Button (✕):
│       ├── Color: Red
│       └── Action: Discard changes
│
└── Behavior:
    ├── Shows when cell is selected
    ├── Hides when no cell selected
    ├── Syncs with cell content
    └── Supports multi-line for long formulas
```

---

### 6. Bottom Toolbar
```
┌─────────────────────────────────────────┐
│  ⚏   🔽   📋   🔗   ⋮                  │
└─────────────────────────────────────────┘

Features:
├── Position: Fixed at bottom
├── Height: 56dp
├── Background: #FAFAFA
├── Elevation: 8dp
├── Border Top: 1dp solid #E0E0E0
│
├── Icons (Left to Right):
│   │
│   ├── 1. Sort Icon (⚏):
│   │   ├── Size: 24×24dp
│   │   ├── Action: Show sort options
│   │   └── Options: A→Z, Z→A, Custom
│   │
│   ├── 2. Filter Icon (🔽):
│   │   ├── Size: 24×24dp
│   │   ├── Action: Enable column filters
│   │   ├── Badge: Shows active filter count
│   │   └── Options: Text, Number, Date filters
│   │
│   ├── 3. Format Icon (📋):
│   │   ├── Size: 24×24dp
│   │   ├── Action: Format painter
│   │   └── Options: Copy/paste formatting
│   │
│   ├── 4. Share Icon (🔗):
│   │   ├── Size: 24×24dp
│   │   ├── Action: Share spreadsheet
│   │   └── Options: Link, Email, Export
│   │
│   └── 5. More Options (⋮):
│       ├── Size: 24×24dp
│       ├── Action: Show additional menu
│       └── Options:
│           ├── Freeze rows/columns
│           ├── Protect sheet
│           ├── Conditional formatting
│           ├── Data validation
│           ├── Insert chart
│           └── Sheet settings
│
└── Spacing:
    ├── Between icons: 24dp
    ├── Side padding: 16dp
    └── Icon padding: 12dp (touch target 48dp)
```

---

### 7. Context Menu (Long Press)
```
┌─────────────────────┐
│ ✂️  Cut             │
│ 📋  Copy            │
│ 📄  Paste           │
├─────────────────────┤
│ 🗑️  Delete          │
│ 🔗  Insert Link     │
│ 💬  Add Comment     │
├─────────────────────┤
│ 🎨  Format Cells    │
│ ✓   Data Validation │
│ 📊  Insert Chart    │
└─────────────────────┘

Features:
├── Position: Centered on long-pressed cell
├── Background: White with elevation
├── Border Radius: 8dp
├── Elevation: 16dp
├── Max Width: 220dp
│
├── Menu Items:
│   ├── Height: 48dp each
│   ├── Icon: 24×24dp, left-aligned
│   ├── Text: 16sp, Medium weight
│   ├── Ripple: Material ripple on tap
│   └── Dividers: Between groups
│
└── Behavior:
    ├── Appears on long press (500ms)
    ├── Dismisses on tap outside
    ├── Slides in with animation
    └── Context-aware (different for headers vs cells)
```

---

### 8. Sheet Tabs (Bottom of Grid)
```
┌─────────────────────────────────────────┐
│ Sheet1  Sheet2  Sheet3  +               │
└─────────────────────────────────────────┘

Features:
├── Position: Above bottom toolbar
├── Height: 40dp
├── Background: White
├── Scrollable: Horizontal scroll for many sheets
│
├── Sheet Tab:
│   ├── Min Width: 100dp
│   ├── Max Width: 200dp
│   ├── Padding: 12dp horizontal
│   ├── Font: 14sp, Medium
│   │
│   ├── States:
│   │   ├── Inactive: Gray text (#757575)
│   │   ├── Active: Blue text (#1976D2)
│   │   └── Active Indicator: 2dp blue underline
│   │
│   ├── Interaction:
│   │   ├── Tap: Switch to sheet
│   │   ├── Long Press: Sheet options menu
│   │   └── Drag: Reorder sheets
│   │
│   └── Options Menu:
│       ├── Rename
│       ├── Duplicate
│       ├── Delete
│       ├── Move
│       └── Color code
│
└── Add Sheet Button (+):
    ├── Size: 36×36dp
    ├── Icon: Plus
    ├── Action: Create new sheet
    └── Style: Outlined circle
```

---

## 🎯 Interactive States

### Cell Selection States
```
1. Single Cell Selected:
   ┌────────────┐
   │ ░░░ Data ░░│  ← Blue border + light blue bg
   └────────────┘
     └─ Fill handle (bottom-right corner)

2. Range Selected:
   ┌────────────┬────────────┐
   │ ░░ A1 ░░░░ │ ░░ B1 ░░░░ │
   ├────────────┼────────────┤
   │ ░░ A2 ░░░░ │ ░░ B2 ░░░░ │  ← All cells blue tint
   └────────────┴────────────┘
     Range: A1:B2

3. Multiple Ranges (Ctrl+Click):
   ┌────┬────┬────┐
   │ ░░ │    │ ░░ │  ← Non-contiguous selection
   ├────┼────┼────┤
   │    │ ░░ │    │
   └────┴────┴────┘

4. Editing Mode:
   ┌────────────┐
   │ Data |     │  ← Green border + cursor
   └────────────┘
     Keyboard shown, formula bar active
```

---

## 🎨 Color Palette

### Primary Colors
```dart
primary:       Color(0xFF1976D2)  // Blue
primaryDark:   Color(0xFF004BA0)  // Dark Blue
primaryLight:  Color(0xFFE3F2FD)  // Light Blue
accent:        Color(0xFF4CAF50)  // Green
```

### Background Colors
```dart
surface:       Color(0xFFFFFFFF)  // White
background:    Color(0xFFFAFAFA)  // Off-white
header:        Color(0xFFF5F5F5)  // Light Gray
divider:       Color(0xFFE0E0E0)  // Border Gray
```

### Text Colors
```dart
textPrimary:   Color(0xFF212121)  // Almost Black
textSecondary: Color(0xFF757575)  // Medium Gray
textHint:      Color(0xFFBDBDBD)  // Light Gray
textError:     Color(0xFFC62828)  // Red
```

### Status Colors
```dart
success:       Color(0xFF4CAF50)  // Green
warning:       Color(0xFFFFC107)  // Amber
error:         Color(0xFFF44336)  // Red
info:          Color(0xFF2196F3)  // Blue
```

---

## 📏 Dimensions & Spacing

### Grid Dimensions
```dart
// Cell sizes
defaultCellWidth:  120.dp
defaultCellHeight: 52.dp
minCellWidth:      60.dp
minCellHeight:     30.dp
maxCellWidth:      400.dp
maxCellHeight:     200.dp

// Headers
columnHeaderHeight: 48.dp
rowHeaderWidth:     48.dp

// Borders
cellBorderWidth:   0.5.dp
gridLineColor:     #E0E0E0
```

### Component Heights
```dart
appBarHeight:      56.dp
formulaBarHeight:  48.dp
sheetTabsHeight:   40.dp
bottomToolbar:     56.dp
```

### Spacing
```dart
paddingSmall:   8.dp
paddingMedium:  16.dp
paddingLarge:   24.dp

marginSmall:    4.dp
marginMedium:   8.dp
marginLarge:    16.dp
```

---

## 🚀 Performance Optimizations

### Virtual Scrolling
```dart
// Only render visible cells
class VirtualGrid {
  final int visibleRows = (screenHeight / cellHeight).ceil() + 2;
  final int visibleCols = (screenWidth / cellWidth).ceil() + 2;
  
  List<Cell> getVisibleCells() {
    return cells.where((cell) =>
      cell.row >= scrollRow - 1 &&
      cell.row <= scrollRow + visibleRows &&
      cell.col >= scrollCol - 1 &&
      cell.col <= scrollCol + visibleCols
    ).toList();
  }
}
```

### Cell Recycling
```dart
// Reuse cell widgets instead of creating new ones
ListView.builder(
  itemCount: rowCount,
  itemBuilder: (context, index) => RowWidget(
    key: ValueKey('row_$index'),
    rowData: getRowData(index),
  ),
)
```

### GPU Acceleration
```dart
// Use Vulkan for rendering when available
if (vulkanAvailable) {
  renderWithVulkan(visibleCells);
} else {
  renderWithCPU(visibleCells);
}
```

---

## 📱 Responsive Design

### Phone Portrait (< 600dp width)
- Column width: 100-120dp
- Fewer visible columns (2-3)
- Bottom toolbar: Icon only (no labels)
- Formula bar: Collapsible

### Phone Landscape (< 600dp height)
- More columns visible (4-5)
- Reduced row height (40dp)
- Compact toolbar

### Tablet (≥ 600dp width)
- Column width: 120-150dp
- More columns visible (5-7)
- Bottom toolbar: Icons with labels
- Formula bar: Always visible
- Side panel: Sheet list / properties

---

## ♿ Accessibility

### Screen Reader Support
```dart
Semantics(
  label: 'Cell A1, value: 100',
  hint: 'Double tap to edit',
  child: CellWidget(...),
)
```

### Touch Targets
- Minimum: 48×48dp for all interactive elements
- Headers: 48dp height minimum
- Buttons: 48dp minimum dimension

### Color Contrast
- Text: 4.5:1 minimum contrast ratio
- Icons: 3:1 minimum contrast ratio
- WCAG AA compliant

---

## 🎬 Animations

### Cell Selection
```dart
AnimatedContainer(
  duration: Duration(milliseconds: 150),
  curve: Curves.easeOut,
  decoration: BoxDecoration(
    color: isSelected 
      ? Color(0xFFE3F2FD) 
      : Colors.white,
  ),
)
```

### Sheet Switching
```dart
PageView.builder(
  onPageChanged: (index) => switchSheet(index),
  itemBuilder: (context, index) => SheetWidget(index),
)
```

### Bottom Sheet
```dart
showModalBottomSheet(
  context: context,
  transitionAnimationController: AnimationController(
    duration: Duration(milliseconds: 300),
    vsync: this,
  ),
)
```

---

**Status**: ✅ Complete UI Specification  
**Version**: 1.0  
**Based On**: Quick Table / Google Sheets UI  
**Last Updated**: July 24, 2026
