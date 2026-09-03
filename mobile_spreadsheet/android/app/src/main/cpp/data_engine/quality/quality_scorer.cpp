/*
 * quality_scorer.cpp  —  6-Dimension Quality Engine Implementation (Phase 3)
 *
 * SCORING WEIGHTS (can be tuned):
 *   Completeness: 25%  — missing data is the #1 issue
 *   Validity:     25%  — invalid data is equally critical
 *   Consistency:  20%  — format inconsistency causes errors
 *   Uniqueness:   15%  — duplicates inflate counts
 *   Accuracy:     10%  — domain correctness (city names etc.)
 *   Integrity:    5%   — relationship validity
 *
 * RELATED:
 *   data_engine/brain/context_compressor.cpp  uses QualityScorer
 *   data_engine/analyzer/column_analyzer.h    provides ColumnStatistics
 */
#include "quality_scorer.h"
#include <cmath>
#include <sstream>

namespace Filters {

// ─────────────────────────────────────────────────────────────────────────────
// Dimension Computations
// ─────────────────────────────────────────────────────────────────────────────

// File-local JSON escape helper (avoids private member access)
static std::string qEsc(const std::string& s) {
    std::string r;
    for (char c : s) {
        if (c == '"') r += "\\\"";
        else if (c == '\\') r += "\\\\";
        else r += c;
    }
    return r;
}

int QualityScorer::computeCompleteness(const ColumnStatistics& stats) {
    if (stats.totalCells == 0) return 100;
    int nonBlank = stats.totalCells - stats.blankCells;
    return (int)(100.0f * nonBlank / stats.totalCells);
}

int QualityScorer::computeConsistency(const ColumnStatistics& stats) {
    // formatConsistency is already 0-100 int (see column_analyzer.h)
    return std::max(0, std::min(100, stats.formatConsistency));
}

int QualityScorer::computeUniqueness(const ColumnStatistics& stats) {
    if (stats.totalCells == 0) return 100;
    int nonBlank = stats.totalCells - stats.blankCells;
    if (nonBlank == 0) return 100;
    // duplicateCount = number of extra occurrences
    float dupRatio = (float)stats.duplicateCount / nonBlank;
    int score = (int)((1.0f - dupRatio) * 100.0f);
    return std::max(0, std::min(100, score));
}

int QualityScorer::computeValidity(const ColumnStatistics& stats) {
    if (stats.totalCells == 0) return 100;
    int nonBlank = stats.totalCells - stats.blankCells;
    if (nonBlank == 0) return 100;
    int invalid = stats.invalidCount + stats.dirtyCount;
    float invalidRatio = (float)invalid / nonBlank;
    int score = (int)((1.0f - invalidRatio) * 100.0f);
    return std::max(0, std::min(100, score));
}

std::string QualityScorer::scoreToGrade(int score) {
    if (score >= 90) return "A";
    if (score >= 80) return "B";
    if (score >= 70) return "C";
    if (score >= 60) return "D";
    return "F";
}

// ---------------------------------------------------------------------------
// Main Scoring
// ---------------------------------------------------------------------------

QualityReport QualityScorer::score(const ColumnAnalysisResult& analysis) const {
    QualityReport report;
    report.columnLetter = analysis.columnLetter;
    report.headerName   = analysis.headerName;

    const ColumnStatistics& st = analysis.stats;

    // 1. Completeness
    int comp = computeCompleteness(st);
    report.completeness = {"Completeness", comp,
        std::to_string(st.blankCells) + " blank out of " + std::to_string(st.totalCells)};

    // 2. Consistency
    int cons = computeConsistency(st);
    report.consistency = {"Consistency", cons,
        std::to_string((int)(st.formatConsistency * 100)) + "% consistent format"};

    // 3. Uniqueness
    int uniq = computeUniqueness(st);
    report.uniqueness = {"Uniqueness", uniq,
        std::to_string(st.duplicateCount) + " duplicate values"};

    // 4. Validity
    int vald = computeValidity(st);
    report.validity = {"Validity", vald,
        std::to_string(st.invalidCount) + " invalid + " +
        std::to_string(st.dirtyCount) + " dirty values"};

    // 5. Accuracy (domain correctness — placeholder, enhanced later via DictManager)
    // Default 100 unless override from higher modules
    report.accuracy = {"Accuracy", 100, "No domain dictionary checked"};

    // 6. Integrity (relationship validity — placeholder)
    report.integrity = {"Integrity", 100, "Not a foreign-key column"};

    // Weighted overall (weights: 25,20,15,25,10,5)
    float overall =
        comp  * 0.25f +
        cons  * 0.20f +
        uniq  * 0.15f +
        vald  * 0.25f +
        report.accuracy.score   * 0.10f +
        report.integrity.score  * 0.05f;
    report.overallScore = std::max(0, std::min(100, (int)overall));
    report.grade = scoreToGrade(report.overallScore);

    return report;
}

// ---------------------------------------------------------------------------
// JSON Serialization
// ---------------------------------------------------------------------------

std::string QualityScorer::jsonEsc(const std::string& s) {
    std::string r;
    for (char c : s) {
        if (c == '"')  r += "\\\"";
        else if (c == '\\') r += "\\\\";
        else r += c;
    }
    return r;
}

std::string QualityReport::toJson() const {
    std::ostringstream j;
    j << "{"
      << "\"column\":\""  << qEsc(columnLetter) << "\","
      << "\"header\":\""  << qEsc(headerName)   << "\","
      << "\"overall\":"   << overallScore << ","
      << "\"grade\":\""   << grade << "\","
      << "\"dimensions\":["
        << "{\"name\":\"Completeness\",\"score\":" << completeness.score << ",\"detail\":\"" << qEsc(completeness.detail) << "\"},"
        << "{\"name\":\"Consistency\",\"score\":"  << consistency.score  << ",\"detail\":\"" << qEsc(consistency.detail)  << "\"},"
        << "{\"name\":\"Uniqueness\",\"score\":"   << uniqueness.score   << ",\"detail\":\"" << qEsc(uniqueness.detail)   << "\"},"
        << "{\"name\":\"Validity\",\"score\":"     << validity.score     << ",\"detail\":\"" << qEsc(validity.detail)     << "\"},"
        << "{\"name\":\"Accuracy\",\"score\":"     << accuracy.score     << ",\"detail\":\"" << qEsc(accuracy.detail)     << "\"},"
        << "{\"name\":\"Integrity\",\"score\":"    << integrity.score    << ",\"detail\":\"" << qEsc(integrity.detail)    << "\"}"
      << "]"
      << "}";
    return j.str();
}


} // namespace Filters
