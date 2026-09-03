/*
 * subtotal_isolator.cpp  —  Subtotal & Report Noise Isolator Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/analyzer/
 */
#include "subtotal_isolator.h"
#include <algorithm>
#include <cctype>
#include <regex>

namespace Filters {

static std::string toLower(const std::string& str) {
    std::string out = str;
    std::transform(out.begin(), out.end(), out.begin(), [](unsigned char c) {
        return std::tolower(c);
    });
    return out;
}

bool SubtotalIsolator::isSubtotalOrNoiseRow(
    const std::vector<std::string>& row,
    std::string* outLabel) const {

    if (row.empty()) return true;

    int nonBlankCount = 0;
    std::string combinedText;

    for (const auto& cell : row) {
        if (!cell.empty()) {
            nonBlankCount++;
            combinedText += " " + toLower(cell);
        }
    }

    if (nonBlankCount == 0) {
        if (outLabel) *outLabel = "BLANK_ROW";
        return true;
    }

    // 1. Decorative border / divider rows (e.g. "----", "====", "****")
    std::regex dividerRegex(R"(^\s*[-=_*#\s]{3,}\s*$)");
    if (nonBlankCount == 1 && std::regex_match(combinedText, dividerRegex)) {
        if (outLabel) *outLabel = "DECORATIVE_DIVIDER";
        return true;
    }

    // 2. Subtotal & Grand Total keywords
    static const std::vector<std::pair<std::string, std::string>> subtotalKeywords = {
        {"subtotal", "SUBTOTAL"},
        {"sub total", "SUBTOTAL"},
        {"sub-total", "SUBTOTAL"},
        {"grand total", "GRAND_TOTAL"},
        {"total:", "TOTAL"},
        {"total summary", "TOTAL"}
    };

    for (const auto& [kw, label] : subtotalKeywords) {
        if (combinedText.find(kw) != std::string::npos) {
            if (outLabel) *outLabel = label;
            return true;
        }
    }

    // 3. Page numbering and print header noise (e.g. "Page 1 of 5", "Printed on 12/04/2024")
    std::regex pageRegex(R"(\bpage\s+\d+(\s+of\s+\d+)?\b|\bprinted\s+(on|by)\b|\bconfidential\b)");
    if (std::regex_search(combinedText, pageRegex)) {
        if (outLabel) *outLabel = "PAGE_METADATA";
        return true;
    }

    return false;
}

SubtotalIsolationResult SubtotalIsolator::isolateSubtotals(
    const std::vector<std::vector<std::string>>& grid,
    bool hasHeader) const {

    SubtotalIsolationResult result;
    if (grid.empty()) return result;

    size_t startRow = hasHeader ? 1 : 0;
    if (hasHeader && !grid.empty()) {
        result.cleanGrid.push_back(grid[0]);
    }

    for (size_t r = startRow; r < grid.size(); r++) {
        std::string label;
        if (isSubtotalOrNoiseRow(grid[r], &label)) {
            SubtotalRow sub;
            sub.originalRowIndex = static_cast<int>(r);
            sub.detectedLabel = label;
            sub.values = grid[r];
            result.isolatedSubtotals.push_back(sub);
            result.removedNoiseRowsCount++;
        } else {
            result.cleanGrid.push_back(grid[r]);
        }
    }

    return result;
}

} // namespace Filters
