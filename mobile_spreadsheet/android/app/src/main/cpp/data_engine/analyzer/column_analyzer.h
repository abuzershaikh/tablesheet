/*
 * column_analyzer.h  —  Column-Level Data Intelligence Analyzer (Phase 2)
 *
 * FOLDER CONTEXT:
 *   Lives in:        data_engine/analyzer/
 *   Uses detector:   data_engine/detector/data_detector.h
 *   Uses cleaner:    data_engine/cleaning/data_cleaner.h
 *   Uses GridManager: grid_manager.h  (top-level cpp folder)
 *   Used by FFI:     ffi_bridge.cpp  → analyzeColumn(const char*)
 *   Used by AI Agent: via FFI → local_agent_service.dart → analyze_column tool
 *   Sheet summary:   data_engine/analyzer/sheet_summarizer.h
 *
 * PHASE 2 UPGRADES:
 *   - Composite Types: PRIMARY + SECONDARY type detection
 *   - Full Statistics: duplicates, invalid, missing, format_consistency
 *   - Explainability: reason field per detection
 *   - Knowledge Tags: ["PII", "Contact", "Finance", etc.]
 *   - Recommended Actions list (multiple ranked)
 *   - AI-Optimized JSON output
 */
#pragma once
#include "../cache/column_metadata.h"
#include <string>
#include <vector>
#include <map>

namespace Filters {

// ─────────────────────────────────────────────────────────────────────────────
// DetectionCandidate — one type with its confidence + reason (explainability)
// ─────────────────────────────────────────────────────────────────────────────
struct DetectionCandidate {
    DataType type;
    std::string typeName;   ///< Human-readable e.g. "Phone Number"
    float confidence;       ///< 0.0–1.0
    std::string reason;     ///< "Starts with +91 and 10 valid digits"
};

// ─────────────────────────────────────────────────────────────────────────────
// ColumnStatistics — full quality metrics for the column
// ─────────────────────────────────────────────────────────────────────────────
struct ColumnStatistics {
    int totalCells      = 0;   ///< Non-blank cells
    int blankCells      = 0;   ///< Blank / missing values
    int duplicateCount  = 0;   ///< Duplicate values (excluding blanks)
    int invalidCount    = 0;   ///< Values that fail type-specific validation
    int dirtyCount      = 0;   ///< Values not matching dominant type
    int uniqueCount     = 0;   ///< Distinct non-blank values
    int formatConsistency = 0; ///< 0-100: how uniform formatting is
    float qualityScore  = 0.0f;///< Composite 0-100 quality score
};

// ─────────────────────────────────────────────────────────────────────────────
// ColumnAnalysisResult — full analysis output (AI-Optimized JSON)
// ─────────────────────────────────────────────────────────────────────────────
struct ColumnAnalysisResult {
    // Identity
    std::string columnLetter;           ///< "A", "B", "C"
    std::string headerName;             ///< Row-1 cell value or empty

    // Primary detection
    DataType dominantType;              ///< Most common detected type
    std::string dominantTypeName;       ///< "Phone Number"
    float typeConfidence;               ///< 0.0–1.0 homogeneity of column
    std::string detectionReason;        ///< "95% cells are 10-digit Indian mobiles"

    // Composite / secondary type
    DataType secondaryType;             ///< e.g. PHONE inside a NAME cell
    std::string secondaryTypeName;      ///< "Currency" etc.

    // All type candidates (sorted by confidence desc)
    std::vector<DetectionCandidate> allCandidates;

    // Statistics (Phase 2)
    ColumnStatistics stats;

    // Knowledge tags: ["PII", "Contact", "Customer"]
    std::vector<std::string> knowledgeTags;

    // Sample values (up to 5)
    std::vector<std::string> samples;

    // Issues list (human-readable)
    std::vector<std::string> issues;

    // Ranked recommended actions
    std::vector<std::string> recommendedActions;

    // Missing / dirty cell references for precise AI targeting
    std::vector<std::string> missingCellRefs;
    std::string alertMessage;

    /// Serialize to AI-optimized JSON string
    std::string toJson() const;


};

// ─────────────────────────────────────────────────────────────────────────────
// ColumnAnalyzer — main analysis engine (singleton)
// ─────────────────────────────────────────────────────────────────────────────
class ColumnAnalyzer {
public:
    static ColumnAnalyzer& getInstance() {
        static ColumnAnalyzer instance;
        return instance;
    }

    /**
     * Analyze an entire column by letter (e.g. "A", "B").
     * Reads all cell data from GridManager.
     * @param columnLetter  Case-insensitive column letter(s)
     * @param includeHeader If true, row 1 is treated as header and skipped
     */
    ColumnAnalysisResult analyze(const std::string& columnLetter,
                                  bool includeHeader = true) const;

private:
    ColumnAnalyzer() = default;

    static std::string dataTypeToString(DataType type);
    static std::string suggestReason(DataType type, float confidence,
                                      int total, int matchCount);
    static std::vector<std::string> getKnowledgeTags(DataType type);
    static std::vector<std::string> buildRecommendedActions(
        DataType type, const ColumnStatistics& stats);
    static DataType findSecondaryType(
        const std::vector<DetectionCandidate>& candidates, DataType primary);
    static int computeFormatConsistency(
        const std::vector<std::string>& values, DataType type);
    static float computeQualityScore(const ColumnStatistics& stats, int total);
};

} // namespace Filters
