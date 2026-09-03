#include "guarded_fill_down.h"
#include "../../grid_manager.h"
#include <algorithm>
#include <cctype>
#include <sstream>

namespace Filters {

bool GuardedFillDown::isSubtotalBoundary(const std::string& text) {
    if (text.empty()) return false;
    std::string lower = text;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

    if (lower.find("total") != std::string::npos ||
        lower.find("subtotal") != std::string::npos ||
        lower.find("grand total") != std::string::npos ||
        lower.find("summary") != std::string::npos ||
        lower.find("average") != std::string::npos ||
        lower.find("closing balance") != std::string::npos ||
        lower.find("opening balance") != std::string::npos ||
        lower.find("net balance") != std::string::npos ||
        lower.find("brought forward") != std::string::npos ||
        lower.find("carried forward") != std::string::npos) {
        return true;
    }
    return false;
}

static std::string getCellStringVal(const std::string& cellRef) {
    if (GridManager::getInstance().isCellEmpty(cellRef)) return "";
    EvalResult res = GridManager::getInstance().evaluateCell(cellRef);
    std::string val;
    if (std::holds_alternative<std::string>(res)) {
        val = std::get<std::string>(res);
    } else if (std::holds_alternative<double>(res)) {
        double d = std::get<double>(res);
        if (d == std::floor(d)) {
            val = std::to_string(static_cast<long long>(d));
        } else {
            std::ostringstream ss;
            ss << d;
            val = ss.str();
        }
    }
    while (!val.empty() && std::isspace(static_cast<unsigned char>(val.front()))) val.erase(0, 1);
    while (!val.empty() && std::isspace(static_cast<unsigned char>(val.back()))) val.pop_back();
    return val;
}

GuardedFillDownResult GuardedFillDown::execute(const std::string& groupCol, const std::string& anchorCol) {
    GuardedFillDownResult res;
    std::string gUpper = groupCol;
    std::string aUpper = anchorCol;
    std::transform(gUpper.begin(), gUpper.end(), gUpper.begin(), ::toupper);
    std::transform(aUpper.begin(), aUpper.end(), aUpper.begin(), ::toupper);

    res.groupColumn = gUpper;
    res.anchorColumn = aUpper;

    if (gUpper.empty() || aUpper.empty()) return res;

    int lastRow = GridManager::getInstance().getLastRow();
    std::string currentParent = "";

    for (int r = 2; r <= lastRow; r++) {
        std::string gRef = gUpper + std::to_string(r);
        std::string aRef = aUpper + std::to_string(r);

        std::string gVal = getCellStringVal(gRef);
        std::string aVal = getCellStringVal(aRef);

        // Check if row contains a subtotal/summary boundary
        if (isSubtotalBoundary(gVal) || isSubtotalBoundary(aVal) ||
            isSubtotalBoundary(getCellStringVal("A" + std::to_string(r))) ||
            isSubtotalBoundary(getCellStringVal("B" + std::to_string(r)))) {
            // Reset propagation on subtotal boundary!
            currentParent = "";
            res.skippedRows++;
            continue;
        }

        if (!gVal.empty()) {
            // New parent value found
            currentParent = gVal;
        } else {
            // Group cell is empty
            if (currentParent.empty()) {
                res.skippedRows++;
                continue;
            }

            // Check anchor cell: child item exists only if anchor has valid data
            if (!aVal.empty()) {
                GridManager::getInstance().setCellConstantString(gRef, currentParent);
                res.filledCount++;
                res.modifiedCells.push_back(gRef);
            } else {
                // Anchor is also blank (spacer row) - DO NOT fill!
                res.skippedRows++;
            }
        }
    }

    return res;
}

std::string GuardedFillDownResult::toJson() const {
    std::string json = "{\"status\":\"SUCCESS\",\"filled_count\":" + std::to_string(filledCount) +
                       ",\"skipped_rows\":" + std::to_string(skippedRows) +
                       ",\"group_column\":\"" + groupColumn + "\"" +
                       ",\"anchor_column\":\"" + anchorColumn + "\",\"modified_cells\":[";
    for (size_t i = 0; i < modifiedCells.size(); i++) {
        if (i > 0) json += ",";
        json += "\"" + modifiedCells[i] + "\"";
    }
    json += "]}";
    return json;
}

} // namespace Filters
