/*
 * sheet_summarizer.h  —  Whole-Sheet Smart Summary Generator
 *
 * FOLDER CONTEXT:
 *   Lives in:        data_engine/analyzer/
 *   Uses:            data_engine/analyzer/column_analyzer.h  (per-column analysis)
 *   Uses:            data_engine/detector/data_detector.h
 *   Uses:            grid_manager.h  (top-level cpp/)
 *   FFI export:      ffi_bridge.cpp  → summarizeSheet()
 *   AI Agent tool:   local_agent_service.dart → summarize_sheet tool
 *
 * OUTPUT:
 *   Returns SheetSummary struct serializable to JSON.
 *   Also generates a human-readable smartSummary string that the AI
 *   agent can directly show to the user.
 */
#pragma once
#include "column_analyzer.h"
#include <string>
#include <vector>

namespace Filters {

struct SheetSummary {
    int totalRows;
    int totalColumns;
    int totalCells;
    int blankCells;
    std::string qualityScore;                        ///< e.g. "Good (87%)"
    std::vector<ColumnAnalysisResult> columnReports; ///< Per-column analysis
    std::string smartSummary;                        ///< Human-readable one-paragraph summary
    std::string toJson() const;
};

class SheetSummarizer {
public:
    static SheetSummarizer& getInstance() {
        static SheetSummarizer instance;
        return instance;
    }

    /**
     * Analyze every column in the sheet and produce a SheetSummary.
     * @param maxColumns Max columns to analyze (default 26 = A..Z)
     */
    SheetSummary summarize(int maxColumns = 26) const;

private:
    SheetSummarizer() = default;
    static std::string buildSmartSummary(const SheetSummary& s);
};

} // namespace Filters
