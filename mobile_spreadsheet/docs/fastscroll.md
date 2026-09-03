# Fast Scroll Optimization Guide

This document explains the techniques used to achieve buttery-smooth 60+ FPS scrolling in the `GridWidget` of our spreadsheet application, and provides troubleshooting steps if scrolling performance degrades in the future.

## How Fast Scroll was Achieved (The CustomPainter Approach)

Previously, the grid was built using standard Flutter widgets for every cell (e.g., `Container`, `GestureDetector`, `BoxDecoration`, `Text`). In a grid with many columns (e.g., 26 columns), this resulted in:
*   **Massive Widget Count:** ~26 widgets per row. If 20 rows are visible, that's over 500 widgets being built, laid out, and painted continuously during a vertical scroll.
*   **High CPU/Memory Overhead:** Flutter's framework had to manage the state and layout for hundreds of individual elements every frame.

**The Solution:**
We transitioned from a "widget-per-cell" architecture to a **"CustomPainter-per-row"** architecture.
1.  **Single Widget per Row:** Instead of building 26 cell widgets, each row in the `ListView.builder` now consists of a single `CustomPaint` widget.
2.  **Direct Canvas Drawing:** The `_RowPainter` class manually draws the cell backgrounds, borders, and text directly onto the GPU canvas using raw `Canvas.drawRect` and `TextPainter.paint` calls.
3.  **Shared Resources:** We use static, shared `Paint` and `TextPainter` instances to eliminate the overhead of creating new painting objects for every cell.
4.  **Result:** Widget count dropped by ~98% (~1560 widgets to ~20 widgets). Scrolling skip-frames dropped from 68-99 to 0.

## Troubleshooting: What to do if scrolling becomes slow again

If future code changes cause the grid scrolling to become choppy or slow ("atak atak kar chal raha hai"), follow these steps to diagnose and fix the issue:

### 1. Check for Accidental Rebuilds (`setState` Abuse)
*   **Symptom:** The entire `GridWidget` or `ListView` is rebuilding on every scroll tick.
*   **Fix:** Ensure `setState` is only called when absolutely necessary (e.g., cell selection, data edit). **Never** call `setState` inside a scroll listener (like `AnimatedBuilder` attached to a `ScrollController`) if it wraps the entire `ListView`. (This was the cause of a previous stutter issue).

### 2. Verify `CustomPainter` Logic
*   **Symptom:** The `_RowPainter` is doing too much work or re-calculating things unnecessarily.
*   **Fix:**
    *   Check the `shouldRepaint` method in `_RowPainter`. It should only return `true` if the specific row's data, selection state, or dimensions have changed. If it always returns `true`, performance will tank.
    *   Ensure no new objects (like `Paint` or `TextStyle`) are being instantiated *inside* the `paint` method loop. Always reuse static or final instances.
    *   Avoid calling `TextPainter.layout()` more than necessary. It is the most expensive operation in the painter.

### 3. Avoid Re-introducing Heavy Widgets inside the List
*   **Symptom:** Someone added a complex widget (like an `AnimatedContainer`, `Shadow`, or deeply nested `Row`/`Column`) back into the `ListView.builder` item builder.
*   **Fix:** Keep the `itemBuilder` returning only the `CustomPaint` (and maybe a single `GestureDetector`). If complex overlays are needed (like the editing `TextField`), render them conditionally via a `Stack` only for the currently active row, not every row.

### 4. Profile the App
*   **Crucial Rule:** NEVER judge performance in Debug mode. Debug mode has huge overhead.
*   **Action:** Run the app in Profile mode: `flutter run --profile` or Release mode: `flutter run --release`.
*   **Tools:** Use the Flutter DevTools Performance overlay. Check if the red bars (jank) are on the **UI Thread** (too many widgets/logic) or the **Raster Thread** (drawing too many complex shapes/shadows).

### 5. Check `addAutomaticKeepAlives`
*   **Symptom:** Memory usage keeps growing as you scroll down.
*   **Fix:** Ensure `addAutomaticKeepAlives: false` is set on the `ListView.builder`. We don't want Flutter keeping off-screen rows alive in memory when using thousands of rows.

---
**Summary Rule of Thumb:** To keep it fast, draw it on the canvas. Don't build widgets for cells.
