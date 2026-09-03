/*
 * record_stitcher.cpp  —  Multi-Line Record Stitcher Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "record_stitcher.h"
#include <algorithm>
#include <cctype>

namespace Filters {

int RecordStitcher::detectAnchorColumn(
    const std::vector<std::vector<std::string>>& grid,
    bool hasHeader) const {

    if (grid.empty()) return -1;

    size_t colCount = 0;
    for (const auto& r : grid) {
        if (r.size() > colCount) colCount = r.size();
    }
    if (colCount == 0) return -1;

    size_t startRow = hasHeader ? 1 : 0;
    size_t totalDataRows = grid.size() - startRow;
    if (totalDataRows < 2) return 0; // Trivial

    DataDetector& detector = DataDetector::getInstance();
    int bestCol = 0;
    float bestScore = -1.0f;

    for (size_t c = 0; c < colCount; c++) {
        int filledCount = 0;
        int dateCount = 0;
        int idCount = 0;
        int alternatingCount = 0;

        bool prevFilled = false;
        for (size_t r = startRow; r < grid.size(); r++) {
            bool isFilled = (c < grid[r].size() && !grid[r][c].empty());
            if (isFilled) {
                filledCount++;
                DataType dt = detector.detect(grid[r][c]);
                if (dt == DataType::DATE) dateCount++;
                if (dt == DataType::NUMBER) idCount++;
            }
            if (r > startRow && (isFilled != prevFilled)) {
                alternatingCount++;
            }
            prevFilled = isFilled;
        }

        // An ideal anchor column is filled on 30%-70% of rows (not 100% full, not 0%),
        // has Date or ID types, and exhibits high alternating/periodicity.
        float fillRatio = static_cast<float>(filledCount) / static_cast<float>(totalDataRows);
        float score = 0.0f;

        if (fillRatio >= 0.2f && fillRatio <= 0.8f) {
            score += 2.0f;
        }
        if (dateCount > 0) score += 3.0f * (static_cast<float>(dateCount) / (filledCount + 1));
        if (idCount > 0) score += 2.0f * (static_cast<float>(idCount) / (filledCount + 1));
        score += static_cast<float>(alternatingCount) / static_cast<float>(totalDataRows);

        if (score > bestScore) {
            bestScore = score;
            bestCol = static_cast<int>(c);
        }
    }

    return bestCol;
}

StitchResult RecordStitcher::stitchGrid(
    const std::vector<std::vector<std::string>>& grid,
    bool hasHeader,
    int explicitAnchorCol) const {

    StitchResult result;
    if (grid.empty()) return result;

    size_t colCount = 0;
    for (const auto& r : grid) {
        if (r.size() > colCount) colCount = r.size();
    }
    if (colCount == 0) return result;

    int anchorCol = (explicitAnchorCol >= 0) ? explicitAnchorCol : detectAnchorColumn(grid, hasHeader);
    if (anchorCol < 0) anchorCol = 0;

    result.report.totalOriginalRows = static_cast<int>(grid.size());
    result.report.detectedAnchorCol = anchorCol;

    size_t startRow = hasHeader ? 1 : 0;

    // Preserve header if present
    if (hasHeader && !grid.empty()) {
        result.cleanGrid.push_back(grid[0]);
        // Normalize column count
        while (result.cleanGrid.back().size() < colCount) {
            result.cleanGrid.back().push_back("");
        }
    }

    std::vector<std::string> currentParentRow;
    bool hasActiveParent = false;

    for (size_t r = startRow; r < grid.size(); r++) {
        const auto& row = grid[r];

        // Check if row is completely empty
        bool allEmpty = true;
        for (const auto& cell : row) {
            if (!cell.empty()) { allEmpty = false; break; }
        }
        if (allEmpty) {
            result.report.eliminatedChildRows++;
            continue;
        }

        // Check anchor cell
        bool hasAnchorVal = (anchorCol < static_cast<int>(row.size()) && !row[anchorCol].empty());

        if (hasAnchorVal || !hasActiveParent) {
            // Flush previous parent row
            if (hasActiveParent) {
                result.cleanGrid.push_back(currentParentRow);
                result.report.stitchedRowsCount++;
            }

            // Start new parent row
            currentParentRow = row;
            while (currentParentRow.size() < colCount) {
                currentParentRow.push_back("");
            }
            hasActiveParent = true;
        } else {
            // This is a child row to be stitched into the parent row
            result.report.eliminatedChildRows++;
            for (size_t c = 0; c < colCount; c++) {
                if (c < row.size() && !row[c].empty()) {
                    if (currentParentRow[c].empty()) {
                        currentParentRow[c] = row[c];
                    } else if (currentParentRow[c] != row[c]) {
                        // Concatenate textually
                        currentParentRow[c] += " - " + row[c];
                    }
                }
            }
        }
    }

    if (hasActiveParent) {
        result.cleanGrid.push_back(currentParentRow);
        result.report.stitchedRowsCount++;
    }

    return result;
}

} // namespace Filters
