/*
 * context_compressor.cpp  —  Sheet Brain Context Compressor (Phase 3)
 *
 * FIELD MAPPING (from column_analyzer.h):
 *   ColumnAnalysisResult::columnLetter     → ColumnBrief::letter
 *   ColumnAnalysisResult::headerName       → ColumnBrief::header
 *   ColumnAnalysisResult::dominantTypeName → ColumnBrief::type
 *   ColumnAnalysisResult::stats.qualityScore → ColumnBrief::quality
 *   ColumnAnalysisResult::stats.totalCells → ColumnBrief::total
 *   ColumnAnalysisResult::stats.blankCells → ColumnBrief::blank
 *   ColumnAnalysisResult::stats.duplicateCount → ColumnBrief::duplicates
 *   ColumnAnalysisResult::stats.invalidCount   → ColumnBrief::invalid
 *   ColumnAnalysisResult::issues[0]            → ColumnBrief::topIssue
 *   ColumnAnalysisResult::recommendedActions[0]→ ColumnBrief::primaryAction
 *   ColumnAnalysisResult::knowledgeTags        → ColumnBrief::tags
 */
#include "context_compressor.h"
#include "../analyzer/column_analyzer.h"
#include "../../grid_manager.h"
#include <sstream>
#include <algorithm>
#include <cmath>

namespace Filters {

// ─────────────────────────────────────────────────────────────────────────────
// AIContext JSON serialization
// ─────────────────────────────────────────────────────────────────────────────

// Local helper to escape JSON strings (avoids private member access issue)
static std::string jEsc(const std::string& s) {
    std::string r;
    for (char c : s) {
        if (c == '"')  r += "\\\"";
        else if (c == '\\') r += "\\\\";
        else if (c == '\n') r += "\\n";
        else r += c;
    }
    return r;
}

std::string AIContext::toJson() const {
    std::ostringstream o;
    o << "{";
    o << "\"sheetType\":\"" << jEsc(sheetType) << "\",";
    o << "\"totalRows\":"    << totalRows    << ",";
    o << "\"totalColumns\":" << totalColumns << ",";
    o << "\"totalDataCells\":"  << totalDataCells  << ",";
    o << "\"totalBlank\":"      << totalBlank      << ",";
    o << "\"totalDuplicates\":" << totalDuplicates << ",";
    o << "\"overallQuality\":"  << overallQuality  << ",";
    o << "\"hasHeaderRow\":"    << (hasHeaderRow ? "true" : "false") << ",";
    o << "\"currency\":\"" << jEsc(currency) << "\",";

    // columns[]
    o << "\"columns\":[";
    for (size_t i = 0; i < columns.size(); ++i) {
        const auto& c = columns[i];
        o << "{";
        o << "\"col\":\"" << jEsc(c.letter) << "\",";
        o << "\"header\":\"" << jEsc(c.header) << "\",";
        o << "\"type\":\"" << jEsc(c.type) << "\",";
        o << "\"quality\":" << c.quality << ",";
        o << "\"total\":"   << c.total   << ",";
        o << "\"blank\":"   << c.blank   << ",";
        o << "\"dupes\":"   << c.duplicates << ",";
        o << "\"invalid\":" << c.invalid;
        if (!c.topIssue.empty())
            o << ",\"issue\":\"" << jEsc(c.topIssue) << "\"";
        if (!c.primaryAction.empty())
            o << ",\"action\":\"" << jEsc(c.primaryAction) << "\"";
        if (!c.tags.empty()) {
            o << ",\"tags\":[";
            for (size_t t = 0; t < c.tags.size(); ++t) {
                o << "\"" << jEsc(c.tags[t]) << "\"";
                if (t + 1 < c.tags.size()) o << ",";
            }
            o << "]";
        }
        o << "}";
        if (i + 1 < columns.size()) o << ",";
    }
    o << "],";

    // topIssues[]
    o << "\"topIssues\":[";
    for (size_t i = 0; i < topIssues.size(); ++i) {
        o << "\"" << jEsc(topIssues[i]) << "\"";
        if (i + 1 < topIssues.size()) o << ",";
    }
    o << "],";

    // suggestedActions[]
    o << "\"suggestedActions\":[";
    for (size_t i = 0; i < suggestedActions.size(); ++i) {
        o << "\"" << jEsc(suggestedActions[i]) << "\"";
        if (i + 1 < suggestedActions.size()) o << ",";
    }
    o << "],";

    o << "\"smartSummary\":\"" << jEsc(smartSummary) << "\"";
    o << "}";
    return o.str();
}

std::string AIContext::toMiniSummary() const {
    std::ostringstream o;
    o << sheetType << " | " << totalRows << " rows | "
      << totalColumns << " cols | Quality: " << overallQuality << "%";
    if (!topIssues.empty()) o << " | " << topIssues[0];
    return o.str();
}

// ─────────────────────────────────────────────────────────────────────────────
// ContextCompressor helpers
// ─────────────────────────────────────────────────────────────────────────────

std::string ContextCompressor::jsonEsc(const std::string& s) {
    return jEsc(s);
}

std::string ContextCompressor::inferSheetType(
    const std::vector<ColumnAnalysisResult>& cols)
{
    bool hasUUID     = false, hasCurrency = false, hasDate = false;
    bool hasPhone    = false, hasEmail    = false;
    bool hasName     = false, hasNumber   = false;

    for (const auto& c : cols) {
        const std::string& t = c.dominantTypeName;  // CORRECT field name
        if (t == "ID / Code" || t == "UUID")        hasUUID     = true;
        if (t == "Currency")                         hasCurrency = true;
        if (t == "Date")                             hasDate     = true;
        if (t == "Phone Number")                     hasPhone    = true;
        if (t == "Email Address")                    hasEmail    = true;
        if (t == "Person Name" || t == "Name")       hasName     = true;
        if (t == "Number")                           hasNumber   = true;
    }

    if (hasUUID && hasCurrency && hasDate)   return "Invoice Database";
    if (hasUUID && hasName && hasCurrency)   return "Employee Records";
    if (hasPhone && hasEmail && hasName)     return "Customer Database";
    if (hasCurrency && hasDate)              return "Sales Report";
    if (hasNumber && hasCurrency)            return "Inventory";
    if (hasName && hasNumber)                return "Attendance / HR Sheet";
    if (hasCurrency)                         return "Accounting Sheet";
    return "General Spreadsheet";
}

std::string ContextCompressor::inferCurrency(
    const std::vector<ColumnAnalysisResult>& cols)
{
    for (const auto& c : cols) {
        if (c.dominantTypeName == "Currency") {
            // Check samples for INR symbol
            for (const auto& s : c.samples) {
                if (s.find('\xe2') != std::string::npos ||   // ₹ UTF-8
                    s.find("Rs") != std::string::npos ||
                    s.find("INR") != std::string::npos)
                    return "INR";
                if (s.find('$') != std::string::npos) return "USD";
                if (s.find(char(0xc2)) != std::string::npos) return "GBP"; // £
            }
            return "INR"; // Default for this app
        }
    }
    return "";
}

std::string ContextCompressor::inferDateFormat(
    const std::vector<ColumnAnalysisResult>& cols)
{
    for (const auto& c : cols) {
        if (c.dominantTypeName == "Date" && !c.samples.empty()) {
            const std::string& s = c.samples[0];
            int slashes = 0, dashes = 0;
            for (char ch : s) {
                if (ch == '/') slashes++;
                if (ch == '-') dashes++;
            }
            if (slashes == 2) return "DD/MM/YYYY";
            if (dashes  == 2) return "DD-MM-YYYY";
        }
    }
    return "";
}

ColumnBrief ContextCompressor::toColumnBrief(const ColumnAnalysisResult& col) {
    ColumnBrief b;
    b.letter     = col.columnLetter;           // CORRECT
    b.header     = col.headerName;             // CORRECT
    b.type       = col.dominantTypeName;       // CORRECT
    b.quality    = (int)(col.stats.qualityScore);
    b.total      = col.stats.totalCells;
    b.blank      = col.stats.blankCells;
    b.duplicates = col.stats.duplicateCount;
    b.invalid    = col.stats.invalidCount;
    b.topIssue   = col.issues.empty()            ? "" : col.issues[0];
    b.primaryAction = col.recommendedActions.empty() ? "" : col.recommendedActions[0];
    b.tags       = col.knowledgeTags;
    return b;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main compress() function
// ─────────────────────────────────────────────────────────────────────────────

static std::string colIdxToLetterHelper(int idx) {
    std::string r;
    int c = idx;
    while (c >= 0) {
        r = char('A' + (c % 26)) + r;
        c = c / 26 - 1;
    }
    return r;
}

AIContext ContextCompressor::compress(int maxColumns) const {
    AIContext ctx;
    ctx.hasHeaderRow = true;

    auto& gm = GridManager::getInstance();
    int lastRow = gm.getLastRow();
    int lastCol = gm.getLastColumn();

    ctx.totalRows = lastRow;
    ctx.totalColumns = lastCol;

    std::vector<ColumnAnalysisResult> analyses;
    ColumnAnalyzer& analyzer = ColumnAnalyzer::getInstance();

    int numColsToAnalyze = std::min(lastCol > 0 ? lastCol : 1, maxColumns);
    for (int c = 0; c < numColsToAnalyze; c++) {
        std::string colStr = colIdxToLetterHelper(c);
        ColumnAnalysisResult res = analyzer.analyze(colStr, true);
        if (res.stats.totalCells > 0 || res.stats.blankCells > 0 || !res.headerName.empty()) {
            analyses.push_back(res);
        }
    }

    if (ctx.totalColumns == 0) ctx.totalColumns = (int)analyses.size();


    int sumQuality      = 0;
    int sumDuplicates   = 0;
    int sumBlank        = 0;
    int sumDataCells    = 0;

    std::vector<std::string> allIssues;
    std::vector<std::string> allActions;

    for (const auto& a : analyses) {
        ctx.columns.push_back(toColumnBrief(a));
        sumQuality    += (int)(a.stats.qualityScore);
        sumDuplicates += a.stats.duplicateCount;
        sumBlank      += a.stats.blankCells;
        sumDataCells  += a.stats.totalCells;
        for (const auto& iss : a.issues)           allIssues.push_back(iss);
        for (const auto& act : a.recommendedActions) allActions.push_back(act);
    }

    ctx.totalDataCells  = sumDataCells;
    ctx.totalBlank      = sumBlank;
    ctx.totalDuplicates = sumDuplicates;
    ctx.overallQuality  = analyses.empty() ? 100
                          : sumQuality / (int)analyses.size();

    ctx.sheetType   = inferSheetType(analyses);
    ctx.currency    = inferCurrency(analyses);
    ctx.dateFormat  = inferDateFormat(analyses);

    // Top 5 unique issues and actions
    auto dedup = [](std::vector<std::string>& v) {
        std::vector<std::string> out;
        for (auto& s : v) {
            bool found = false;
            for (auto& x : out) if (x == s) { found = true; break; }
            if (!found) out.push_back(s);
            if (out.size() >= 5) break;
        }
        return out;
    };
    ctx.topIssues        = dedup(allIssues);
    ctx.suggestedActions = dedup(allActions);

    // Smart summary
    std::ostringstream ss;
    ss << ctx.sheetType << " with " << ctx.totalColumns << " columns, "
       << ctx.totalRows << " rows. Overall quality: " << ctx.overallQuality << "%.";
    if (!ctx.topIssues.empty()) ss << " Main issue: " << ctx.topIssues[0] << ".";
    ctx.smartSummary = ss.str();

    return ctx;
}

} // namespace Filters
