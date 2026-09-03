/*
 * quality_scorer.h  —  6-Dimension Data Quality Scoring Engine (Phase 3)
 *
 * FOLDER CONTEXT:
 *   Lives in:     data_engine/quality/
 *   Uses:         data_engine/analyzer/column_analyzer.h (ColumnAnalysisResult)
 *   Used by:      data_engine/brain/context_compressor.cpp
 *                 ffi_bridge.cpp → native_getQualityScore()
 *
 * SIX DIMENSIONS (ISO 8000 / DAMA standard):
 *   1. Completeness   = non-blank ratio         (missing values penalty)
 *   2. Consistency    = format uniformity        (all phones same format?)
 *   3. Uniqueness     = 1 - duplicate ratio      (how many duplicates?)
 *   4. Validity       = validator pass rate      (are values actually valid?)
 *   5. Accuracy       = domain match rate        (is "Bombay" corrected to "Mumbai"?)
 *   6. Integrity      = relationship validity    (foreign key consistency)
 *
 * OUTPUT:
 *   QualityReport per column with all 6 scores + overall weighted score (0-100)
 *
 * EXAMPLE:
 *   Phone column:
 *     Completeness: 95  (5 blanks out of 100)
 *     Consistency:  80  (some +91, some 0, some bare)
 *     Uniqueness:   90  (10 duplicates)
 *     Validity:     85  (15 fail PhoneValidator — all repeating digits)
 *     Accuracy:     N/A (100 default for phone)
 *     Integrity:    100 (not a FK column)
 *     OVERALL:      90
 */
#pragma once
#include "../analyzer/column_analyzer.h"
#include <string>
#include <vector>

namespace Filters {

struct QualityDimension {
    std::string name;    // "Completeness"
    int score;           // 0-100
    std::string detail;  // "5 missing values out of 100 cells"
};

struct QualityReport {
    std::string columnLetter;
    std::string headerName;

    // 6 quality dimensions
    QualityDimension completeness;   // non-blank ratio
    QualityDimension consistency;    // format uniformity
    QualityDimension uniqueness;     // 1 - duplicate ratio
    QualityDimension validity;       // validator pass rate
    QualityDimension accuracy;       // domain correctness
    QualityDimension integrity;      // relationship validity

    int overallScore;    // weighted average 0-100
    std::string grade;   // "A" (90+), "B" (80+), "C" (70+), "D" (60+), "F" (<60)

    std::string toJson() const;
};

class QualityScorer {
public:
    static QualityScorer& getInstance() {
        static QualityScorer inst;
        return inst;
    }

    /// Score a column using its already-computed ColumnAnalysisResult
    QualityReport score(const ColumnAnalysisResult& analysis) const;

    /// Grade from score (A/B/C/D/F)
    static std::string scoreToGrade(int score);

private:
    QualityScorer() = default;
    static int computeCompleteness(const ColumnStatistics& stats);
    static int computeConsistency(const ColumnStatistics& stats);
    static int computeUniqueness(const ColumnStatistics& stats);
    static int computeValidity(const ColumnStatistics& stats);
    static std::string jsonEsc(const std::string& s);
};

} // namespace Filters
