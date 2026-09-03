/*
 * sheet_summarizer.cpp  —  Sheet Summary Engine Implementation
 *
 * ALGORITHM:
 *   1. Get sheet dimensions from GridManager
 *   2. For each column A..Z (up to maxColumns), call ColumnAnalyzer
 *   3. Skip entirely-empty columns (totalCells == 0 && blankCells == 0)
 *   4. Calculate overall quality score
 *   5. Build human-readable smartSummary string
 *   6. Return SheetSummary
 */
#include "sheet_summarizer.h"
#include "../../grid_manager.h"
#include <sstream>
#include <algorithm>

namespace Filters {

static std::string colIdxToLetter(int idx) {
    std::string r;
    int c = idx;
    while (c >= 0) {
        r = char('A' + (c % 26)) + r;
        c = c / 26 - 1;
    }
    return r;
}

SheetSummary SheetSummarizer::summarize(int maxColumns) const {
    SheetSummary summary;
    summary.totalRows = 0;
    summary.totalColumns = 0;
    summary.totalCells = 0;
    summary.blankCells = 0;

    // Get sheet dimensions from GridManager
    int lastRow = GridManager::getInstance().getLastRow();
    int lastCol = GridManager::getInstance().getLastColumn();
    summary.totalRows = lastRow;

    // Analyze each column
    ColumnAnalyzer& analyzer = ColumnAnalyzer::getInstance();
    int columnsAnalyzed = 0;
    int totalClean = 0;
    int totalDirty = 0;

    for (int c = 0; c <= std::min(lastCol, maxColumns - 1); c++) {
        std::string colLetter = colIdxToLetter(c);
        ColumnAnalysisResult col = analyzer.analyze(colLetter, true);

        // Skip completely empty columns
        if (col.stats.totalCells == 0 && col.stats.blankCells == 0) continue;

        summary.columnReports.push_back(col);
        summary.totalCells  += col.stats.totalCells;
        summary.blankCells  += col.stats.blankCells;
        totalClean          += col.stats.totalCells - col.stats.dirtyCount;
        totalDirty          += col.stats.dirtyCount;
        columnsAnalyzed++;
    }

    summary.totalColumns = columnsAnalyzed;

    // Quality score
    int total = totalClean + totalDirty;
    if (total > 0) {
        float pct = (float)totalClean / (float)total * 100.0f;
        std::ostringstream qs;
        if (pct >= 90) qs << "Excellent (" << (int)pct << "%";
        else if (pct >= 75) qs << "Good (" << (int)pct << "%";
        else if (pct >= 50) qs << "Fair (" << (int)pct << "%";
        else qs << "Needs Cleaning (" << (int)pct << "%";
        qs << " data quality)";
        summary.qualityScore = qs.str();
    } else {
        summary.qualityScore = "Empty sheet";
    }

    summary.smartSummary = buildSmartSummary(summary);
    return summary;
}

std::string SheetSummarizer::buildSmartSummary(const SheetSummary& s) {
    std::ostringstream out;
    out << "Sheet has " << s.totalRows << " rows and "
        << s.totalColumns << " column(s). ";
    out << "Total data cells: " << s.totalCells << ". ";
    if (s.blankCells > 0) {
        out << s.blankCells << " blank cells found. ";
    }
    out << "Quality: " << s.qualityScore << ". ";

    for (const auto& col : s.columnReports) {
        out << "Column " << col.columnLetter;
        if (!col.headerName.empty()) out << " (\"" << col.headerName << "\")";
        out << ": " << col.dominantTypeName;
        if (col.typeConfidence < 1.0f) {
            out << " (" << (int)(col.typeConfidence * 100) << "% match)";
        }
        if (!col.issues.empty()) {
            out << " — " << col.issues[0];
        }
        out << ". ";
    }
    return out.str();
}

std::string SheetSummary::toJson() const {
    std::ostringstream j;
    j << "{";
    j << "\"total_rows\":" << totalRows << ",";
    j << "\"total_columns\":" << totalColumns << ",";
    j << "\"total_cells\":" << totalCells << ",";
    j << "\"blank_cells\":" << blankCells << ",";
    j << "\"quality_score\":\"" << qualityScore << "\",";
    j << "\"smart_summary\":\"" << smartSummary << "\",";
    j << "\"columns\":[";
    for (size_t i = 0; i < columnReports.size(); i++) {
        if (i) j << ",";
        j << columnReports[i].toJson();
    }
    j << "]";
    j << "}";
    return j.str();
}

} // namespace Filters
