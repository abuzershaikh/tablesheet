# Column & Row Properties Bottom Sheet - UI Specification

## Overview
When user taps on a Column Header (A, B, C...) or Row Header (1, 2, 3...), a Material Design 3 bottom sheet slides up from the bottom of the screen, allowing the user to configure all properties of that column or row.

---

## 🎨 Column Properties Bottom Sheet

### Layout Structure

```
┌─────────────────────────────────────────┐
│  ← Edit Column Properties        Save   │  ← Title Bar
├─────────────────────────────────────────┤
│                                         │
│  Column Name                            │
│  ┌─────────────────────────────────┐   │
│  │ Column 1                    ✕   │   │  ← Text Input with Clear
│  └─────────────────────────────────┘   │
│                                         │
│  COLUMN TYPE                            │
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐       │
│  │ Tt │  │ $ │  │ 📅 │  │ 🖼️ │       │  ← Type Icons
│  └────┘  └────┘  └────┘  └────┘       │
│   Text   Amount  Date    Image         │
│   ▬▬▬▬                                  │  ← Selected Indicator
│                                         │
│  COLUMN WIDTH    1.0                    │
│  ┌─┐ ▓▓░░░░░░░░░░░░░░░░░ ┌─┐          │
│  │-│ ═══════════════════ │+│          │  ← Slider
│  └─┘                     └─┘          │
│                                         │
│  STYLES                                 │
│  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐             │
│  │B│ │I│ │≡│ │🎨│ │A│ │↻│             │  ← Formatting Buttons
│  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘             │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Sample Text                     │   │  ← Preview
│  └─────────────────────────────────┘   │
│                                         │
│  📊 Summary on Graph                    │  ← Action Items
│                                         │
│  ➕ Insert Column on left               │
│                                         │
│  👁️ Visible in table          ⭕       │  ← Toggle Switch
│                                         │
└─────────────────────────────────────────┘
```

### Components Detail

#### 1. **Title Bar**
- **Back Button** (←): Left-aligned, dismisses sheet without saving
- **Title**: "Edit Column Properties" or dynamic "Column A Properties"
- **Save Button**: Right-aligned, primary color, saves changes and closes

#### 2. **Column Name Input**
```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Column Name',
    hintText: 'Column 1',
    suffixIcon: IconButton(
      icon: Icon(Icons.clear),
      onPressed: () => clearColumnName(),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
    ),
  ),
)
```

#### 3. **Column Type Selector**
Visual chip-based selector with icons:

| Type | Icon | Description |
|------|------|-------------|
| Text | `Tt` | Plain text data |
| Amount | `$` | Currency/monetary values |
| Number | `123` | Numeric values |
| Date | `📅` | Date values |
| Time | `🕐` | Time values |
| Duration | `⏱️` | Time duration |
| Checkbox | `☑️` | Boolean checkbox |
| Image | `🖼️` | Image attachments |

```dart
Row(
  children: [
    ColumnTypeChip(
      icon: Icons.text_fields,
      label: 'Text',
      selected: columnType == ColumnType.text,
      onTap: () => setColumnType(ColumnType.text),
    ),
    // ... more chips
  ],
)
```

#### 4. **Column Width Slider**
```
┌─────────────────────────────────────┐
│ COLUMN WIDTH    1.0                 │
│ ┌─┐ ▓▓▓▓░░░░░░░░░░░░░░ ┌─┐         │
│ │-│ ═════════════════ │+│         │
│ └─┘                   └─┘         │
└─────────────────────────────────────┘

Features:
- Minus button: Decrease width by 0.1
- Plus button: Increase width by 0.1
- Slider: Continuous adjustment (0.5 to 5.0)
- Live preview: Column width updates in real-time
- Current value displayed above slider
```

```dart
Row(
  children: [
    IconButton(
      icon: Icon(Icons.remove_circle_outline),
      onPressed: () => decreaseWidth(),
    ),
    Expanded(
      child: Slider(
        value: columnWidth,
        min: 0.5,
        max: 5.0,
        divisions: 45,
        label: columnWidth.toStringAsFixed(1),
        onChanged: (value) => updateColumnWidth(value),
      ),
    ),
    IconButton(
      icon: Icon(Icons.add_circle_outline),
      onPressed: () => increaseWidth(),
    ),
  ],
)
```

#### 5. **Styles Section**
```
┌─────────────────────────────────────┐
│ STYLES                              │
│ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐           │
│ │B│ │I│ │≡│ │🎨│ │A│ │↻│           │
│ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘           │
│                                     │
│ ┌───────────────────────────────┐   │
│ │ Sample Text                   │   │
│ └───────────────────────────────┘   │
└─────────────────────────────────────┘

Buttons:
- B: Bold
- I: Italic
- ≡: Alignment (Left/Center/Right)
- 🎨: Background Color Picker
- A: Text Color Picker
- ↻: Text Rotation (0°, 90°, -90°)
```

#### 6. **Action Items**
```
📊 Summary on Graph
   └─ Enable/configure chart generation for column

➕ Insert Column on left
   └─ Inserts new column to the left

👁️ Visible in table    ⭕ ON
   └─ Toggle to hide/show column
```

---

## 🎨 Row Properties Bottom Sheet

Similar design but with row-specific options:

```
┌─────────────────────────────────────────┐
│  ← Edit Row Properties           Save   │
├─────────────────────────────────────────┤
│                                         │
│  Row Number                             │
│  ┌─────────────────────────────────┐   │
│  │ 5                           ✕   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ROW HEIGHT    30px                     │
│  ┌─┐ ▓▓░░░░░░░░░░░░░░░░░ ┌─┐          │
│  │-│ ═══════════════════ │+│          │
│  └─┘                     └─┘          │
│                                         │
│  STYLES                                 │
│  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐                 │
│  │B│ │I│ │🎨│ │A│ │⬆️│                 │
│  └─┘ └─┘ └─┘ └─┘ └─┘                 │
│                                         │
│  ⬆️ Insert Row Above                    │
│                                         │
│  ⬇️ Insert Row Below                    │
│                                         │
│  🗑️ Delete Row                          │
│                                         │
│  👁️ Visible in table          ⭕       │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🎯 Interaction Flow

### Opening Bottom Sheet
1. User taps Column Header (e.g., "B")
2. Bottom sheet animates up from bottom (300ms ease-out)
3. Background grid dims with semi-transparent overlay
4. Current column properties populate the form fields

### Editing Properties
1. User changes Column Name → updates in real-time in preview
2. User selects Column Type → icon highlights, type stored
3. User adjusts Width slider → column width updates live in background grid
4. User applies Styles → preview text updates immediately

### Saving Changes
1. User taps "Save" button
2. All changes committed to database
3. Grid re-renders with new properties
4. Bottom sheet animates down (250ms ease-in)
5. Success snackbar appears: "Column properties updated"

### Canceling Changes
1. User taps back button or outside sheet
2. Confirmation dialog: "Discard changes?"
3. If yes: Sheet closes without saving
4. If no: Returns to editing

---

## 💾 Data Structure

### Column Properties Object
```dart
class ColumnProperties {
  final String columnId;        // UUID
  final String columnName;      // Custom name or letter (A, B, C)
  final ColumnType type;        // Text, Amount, Date, etc.
  final double width;           // 0.5 to 5.0 (multiplier)
  final TextStyle textStyle;    // Bold, italic, font
  final Color? backgroundColor;
  final Color? textColor;
  final TextAlign alignment;
  final int rotation;           // 0, 90, -90 degrees
  final bool visible;           // Show/hide column
  final bool summaryOnGraph;    // Chart generation enabled
  
  ColumnProperties({...});
}

enum ColumnType {
  text,
  amount,
  number,
  date,
  time,
  duration,
  checkbox,
  image,
}
```

### Row Properties Object
```dart
class RowProperties {
  final String rowId;           // UUID
  final int rowNumber;          // Display number
  final double height;          // Pixels (20-200)
  final TextStyle textStyle;
  final Color? backgroundColor;
  final bool visible;
  
  RowProperties({...});
}
```

---

## 🎨 Material Design 3 Styling

### Colors
```dart
// Primary Actions
primaryColor: Color(0xFF1976D2)
primaryVariant: Color(0xFF004BA0)

// Bottom Sheet
surfaceColor: Colors.white
backgroundDim: Colors.black.withOpacity(0.5)

// Interactive Elements
chipSelectedColor: Color(0xFFE3F2FD)
chipUnselectedColor: Color(0xFFF5F5F5)
sliderActiveColor: Color(0xFF4CAF50)
sliderInactiveColor: Color(0xFFE0E0E0)

// Text
primaryText: Color(0xFF212121)
secondaryText: Color(0xFF757575)
```

### Typography
```dart
titleLarge: TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w600,
)

bodyMedium: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
)

labelSmall: TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.5,
)
```

### Spacing
- Padding: 16dp horizontal, 12dp vertical
- Between sections: 24dp
- Between items: 12dp
- Button height: 48dp
- Slider track height: 4dp

---

## 📱 Responsive Behavior

### Phone (Portrait)
- Bottom sheet height: 75% of screen
- Scrollable content if needed
- Full-width components

### Tablet (Landscape)
- Bottom sheet max width: 600dp
- Centered horizontally
- Side padding: 24dp

### Gestures
- **Swipe down**: Dismiss sheet (with confirmation if edited)
- **Tap outside**: Dismiss sheet
- **Drag slider**: Live width adjustment
- **Long-press style button**: Show tooltip

---

## 🧪 Validation Rules

### Column Name
- Max length: 50 characters
- Allowed: Alphanumeric, spaces, hyphens, underscores
- Not allowed: Special characters (!, @, #, etc.)
- Default: Column letter if empty

### Column Width
- Min: 0.5 (50% of default)
- Max: 5.0 (500% of default)
- Step: 0.1
- Default: 1.0

### Row Height
- Min: 20px
- Max: 200px
- Step: 1px
- Default: 30px

---

## 🚀 Performance Considerations

1. **Real-time Updates**: Use debouncing for slider (100ms)
2. **Preview Rendering**: Update only preview, not full grid until save
3. **Animation**: Use GPU-accelerated transforms
4. **Memory**: Cache current state for undo/redo
5. **Database**: Batch update all properties in single transaction

---

## 🎯 Accessibility

- **VoiceOver/TalkBack**: All buttons labeled
- **Touch targets**: Minimum 48×48dp
- **Color contrast**: WCAG AA compliant
- **Focus order**: Logical tab sequence
- **Screen reader**: Announces property changes

---

## 📝 Example Usage

```dart
// Open column properties
void onColumnHeaderTap(String columnId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ColumnPropertiesSheet(
      columnId: columnId,
      initialProperties: getColumnProperties(columnId),
      onSave: (properties) {
        updateColumnProperties(columnId, properties);
        Navigator.pop(context);
      },
    ),
  );
}
```

---

**Status**: ✅ Specification Complete  
**Version**: 1.0  
**Last Updated**: July 24, 2026
