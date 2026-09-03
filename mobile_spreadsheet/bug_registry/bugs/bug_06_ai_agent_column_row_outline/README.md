# BUG-06: AI Agent Column & Row Outline / Border Support Fix

## Bug Summary
**Issue**: The AI Agent was unable to apply column and row outlines or borders when requested by the user.
**Root Causes**:
1. **Flutter Grid Painter (`grid_widget.dart`)**: `_RowPainter` drew base grid lines and cell background colors, but completely ignored custom cell border definitions (`cfStyle['border']`).
2. **C++ JavaScript Engine (`js_engine.cpp`)**: `range.setOutline` was missing from Range JS objects, and `range.setBorder` had incomplete parameter parsing.
3. **AI System Instruction (`local_agent_service.dart`)**: System instructions lacked explicit guidelines for applying column/row borders and outlines via Google Apps Script JS API.

---

## File Locations & Changes
1. [`lib/presentation/editor/widgets/grid_widget.dart`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/lib/presentation/editor/widgets/grid_widget.dart#L2174-L2215)
   - Added rendering of custom top, bottom, left, and right borders in `_RowPainter.paint` when `cfStyle['border']` is present.
2. [`android/app/src/main/cpp/js_engine.cpp`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/android/app/src/main/cpp/js_engine.cpp#L824-L880)
   - Enhanced `js_range_setBorder` to parse boolean parameters (`top, left, bottom, right`) and hex color strings.
   - Implemented `js_range_setOutline` to set outer bounding box borders around a range.
   - Registered `setBorder`, `setBorders`, and `setOutline` in `createRangeObj`.
3. [`lib/domain/services/copilot/local_agent_service.dart`](file:///d:/abuzer%20projects/Table%20sheets%20project/mobile_spreadsheet/lib/domain/services/copilot/local_agent_service.dart#L750-L775)
   - Added explicit system instruction rules instructing Gemini AI on how to invoke `.setBorder(...)` and `.setOutline(...)` for column, row, and range outline formatting requests.

---

## Verification
- `flutter analyze` passed cleanly with 0 compilation errors.
- Both JS engine script execution (`range.setBorder`, `range.setOutline`) and UI canvas rendering now display cell borders dynamically.
