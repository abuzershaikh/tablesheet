/*
 * context_compressor.h — Sheet Brain Context Compressor (Phase 3)
 *
 * THE PROBLEM:
 *   A sheet with 10,000 rows × 20 columns = 200,000 cells.
 *   Sending raw data to AI → 500,000+ tokens → IMPOSSIBLE.
 *
 * THE SOLUTION:
 *   1. Run ColumnAnalyzer on every column
 *   2. Run SchemaInferrer on the whole sheet
 *   3. Compress everything into a 300-token JSON
 *   4. AI gets: sheetType, columns[], issues[], suggestions[]
 *
 * AI BENEFIT:
 *   Instead of "row1: 9876543210, row2: 9123456789..."
 *   AI gets: {"column":"A","type":"Phone","quality":87,"issues":["3 blank","2 dup"]}
 *   100x fewer tokens → 100x faster reasoning!
 *
 * LIVES IN: data_engine/brain/
 * USED BY:  ffi_bridge.cpp → native_understandSheet()
 *           AI Agent tool: understand_sheet
 */
#pragma once
#include "../analyzer/column_analyzer.h"
#include <string>
#include <vector>
#include <set>

namespace Filters {

// Brief per-column summary for AI context
struct ColumnBrief {
    std::string letter;         // "A"
    std::string header;         // "Phone Number"
    std::string type;           // "Phone Number"
    int quality;                // 0-100
    int total;                  // non-blank cells
    int blank;
    int duplicates;
    int invalid;
    std::string topIssue;       // first issue string
    std::string primaryAction;  // first recommended action
    std::vector<std::string> tags; // ["PII","Contact"]
};

// The compressed AI context object
struct AIContext {
    // Sheet-level
    std::string sheetType;      // "Invoice Database" or "Employee Records"
    int totalRows;
    int totalColumns;
    int totalDataCells;
    int totalBlank;
    int totalDuplicates;
    int overallQuality;         // 0-100
    bool hasHeaderRow;
    std::string currency;       // "INR" / "USD" / ""
    std::string dateFormat;     // "DD-MM-YYYY" / "MM/DD/YYYY"

    // Per-column briefs
    std::vector<ColumnBrief> columns;

    // Top issues across all columns (max 5)
    std::vector<std::string> topIssues;

    // Ranked suggested actions (max 5)
    std::vector<std::string> suggestedActions;

    // Human-readable one-paragraph summary
    std::string smartSummary;

    /// Serialize to compact AI-optimized JSON (< 400 tokens target)
    std::string toJson() const;
    /// Serialize to ultra-compact summary string (< 100 tokens)
    std::string toMiniSummary() const;
};

class ContextCompressor {
public:
    static ContextCompressor& getInstance() {
        static ContextCompressor inst;
        return inst;
    }

    /**
     * Analyze the entire sheet and compress to AIContext.
     * @param maxColumns  Max columns to analyze (default 26 = A-Z)
     * @param maxSamples  Max sample values per column
     */
    AIContext compress(int maxColumns = 26) const;

private:
    ContextCompressor() = default;
    static std::string inferSheetType(const std::vector<ColumnAnalysisResult>& cols);
    static std::string inferCurrency(const std::vector<ColumnAnalysisResult>& cols);
    static std::string inferDateFormat(const std::vector<ColumnAnalysisResult>& cols);
    static ColumnBrief toColumnBrief(const ColumnAnalysisResult& col);
    static std::string jsonEsc(const std::string& s);
};

} // namespace Filters
