/*
 * row_aligner.cpp  —  Enterprise Shifted Row Alignment & Multi-Value Splitter Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "row_aligner.h"
#include <algorithm>
#include <map>
#include <cctype>

namespace Filters {

std::vector<DataType> RowAligner::profileColumnTypes(
    const std::vector<std::vector<std::string>>& grid,
    bool hasHeader) const {

    std::vector<DataType> profile;
    if (grid.empty()) return profile;

    size_t colCount = 0;
    for (const auto& row : grid) {
        if (row.size() > colCount) colCount = row.size();
    }
    if (colCount == 0) return profile;

    profile.resize(colCount, DataType::TEXT);

    size_t startRow = hasHeader ? 1 : 0;
    DataDetector& detector = DataDetector::getInstance();

    for (size_t c = 0; c < colCount; c++) {
        std::map<DataType, int> counts;
        for (size_t r = startRow; r < grid.size(); r++) {
            if (c < grid[r].size() && !grid[r][c].empty()) {
                DataType t = detector.detect(grid[r][c]);
                if (t != DataType::BLANK) {
                    counts[t]++;
                }
            }
        }

        DataType bestType = DataType::TEXT;
        int maxCount = 0;
        for (const auto& [t, cnt] : counts) {
            if (cnt > maxCount) {
                maxCount = cnt;
                bestType = t;
            }
        }
        profile[c] = bestType;
    }

    return profile;
}

float RowAligner::computeRowTypeMatch(const std::vector<std::string>& row,
                                     const std::vector<DataType>& types,
                                     int offset) {
    if (types.empty()) return 0.0f;
    float totalScore = 0.0f;
    int evaluated = 0;

    DataDetector& detector = DataDetector::getInstance();

    for (size_t c = 0; c < types.size(); c++) {
        int cellIdx = static_cast<int>(c) + offset;
        if (cellIdx < 0 || cellIdx >= static_cast<int>(row.size())) {
            continue;
        }

        const std::string& val = row[cellIdx];
        if (val.empty()) continue;

        evaluated++;
        DataType cellType = detector.detect(val);

        if (cellType == types[c]) {
            totalScore += 1.0f;
        } else if (types[c] == DataType::TEXT) {
            totalScore += 0.4f; // Text can accept any string
        } else if (types[c] == DataType::NUMBER && cellType == DataType::CURRENCY) {
            totalScore += 0.9f;
        } else if (types[c] == DataType::CURRENCY && cellType == DataType::NUMBER) {
            totalScore += 0.9f;
        }
    }

    if (evaluated == 0) return 0.0f;
    return totalScore / static_cast<float>(evaluated);
}

std::vector<std::string> RowAligner::alignRow(
    const std::vector<std::string>& row,
    const std::vector<DataType>& expectedTypes,
    int* detectedShift) const {

    if (row.empty() || expectedTypes.empty()) {
        if (detectedShift) *detectedShift = 0;
        return row;
    }

    float score0 = computeRowTypeMatch(row, expectedTypes, 0);
    float scoreR1 = computeRowTypeMatch(row, expectedTypes, 1);  // Right shifted by 1
    float scoreR2 = computeRowTypeMatch(row, expectedTypes, 2);  // Right shifted by 2
    float scoreL1 = computeRowTypeMatch(row, expectedTypes, -1); // Left shifted by 1

    int bestShift = 0;
    float bestScore = score0;

    // A shift must significantly improve matching (> 0.35 gain and >= 0.70 score)
    if (scoreR1 > bestScore + 0.35f && scoreR1 >= 0.70f) {
        bestScore = scoreR1;
        bestShift = 1;
    }
    if (scoreR2 > bestScore + 0.35f && scoreR2 >= 0.70f) {
        bestScore = scoreR2;
        bestShift = 2;
    }
    if (scoreL1 > bestScore + 0.35f && scoreL1 >= 0.70f) {
        bestScore = scoreL1;
        bestShift = -1;
    }

    if (detectedShift) *detectedShift = bestShift;

    if (bestShift == 0) {
        return row;
    }

    std::vector<std::string> aligned(expectedTypes.size(), "");

    if (bestShift > 0) {
        // Right-shifted: slice cells starting at index `bestShift`
        for (size_t c = 0; c < expectedTypes.size(); c++) {
            size_t srcIdx = c + bestShift;
            if (srcIdx < row.size()) {
                aligned[c] = row[srcIdx];
            }
        }
    } else if (bestShift < 0) {
        // Left-shifted: shift cells rightwards
        int absShift = -bestShift;
        for (size_t c = absShift; c < expectedTypes.size(); c++) {
            size_t srcIdx = c - absShift;
            if (srcIdx < row.size()) {
                aligned[c] = row[srcIdx];
            }
        }
    }

    return aligned;
}

std::vector<ShiftedRowReport> RowAligner::detectShiftedRows(
    const std::vector<std::vector<std::string>>& grid,
    bool hasHeader) const {

    std::vector<ShiftedRowReport> reports;
    if (grid.empty()) return reports;

    std::vector<DataType> expectedTypes = profileColumnTypes(grid, hasHeader);
    size_t startRow = hasHeader ? 1 : 0;

    for (size_t r = startRow; r < grid.size(); r++) {
        int shift = 0;
        std::vector<std::string> aligned = alignRow(grid[r], expectedTypes, &shift);

        if (shift != 0) {
            ShiftedRowReport rep;
            rep.rowIndex = static_cast<int>(r);
            rep.detectedShift = shift;
            rep.confidence = 0.85f;
            rep.reason = (shift > 0) ? ("Row is right-shifted by " + std::to_string(shift) + " column(s)")
                                     : ("Row is left-shifted by " + std::to_string(-shift) + " column(s)");
            rep.originalRow = grid[r];
            rep.alignedRow = aligned;
            reports.push_back(rep);
        }
    }

    return reports;
}

std::vector<std::vector<std::string>> RowAligner::alignGrid(
    const std::vector<std::vector<std::string>>& grid,
    bool hasHeader) const {

    if (grid.empty()) return grid;
    std::vector<DataType> expectedTypes = profileColumnTypes(grid, hasHeader);
    std::vector<std::vector<std::string>> result = grid;

    size_t startRow = hasHeader ? 1 : 0;
    for (size_t r = startRow; r < result.size(); r++) {
        int shift = 0;
        std::vector<std::string> aligned = alignRow(result[r], expectedTypes, &shift);
        if (shift != 0) {
            result[r] = aligned;
        }
    }

    return result;
}

std::vector<std::string> RowAligner::splitDelimitedCell(
    const std::string& cell,
    const std::string& customDelimiters) {

    std::vector<std::string> tokens;
    if (cell.empty()) return tokens;

    std::string cur;
    for (char c : cell) {
        if (customDelimiters.find(c) != std::string::npos) {
            // Trim cur
            while (!cur.empty() && std::isspace(static_cast<unsigned char>(cur.front()))) cur.erase(0, 1);
            while (!cur.empty() && std::isspace(static_cast<unsigned char>(cur.back()))) cur.pop_back();
            if (!cur.empty()) {
                tokens.push_back(cur);
                cur.clear();
            }
        } else {
            cur += c;
        }
    }

    while (!cur.empty() && std::isspace(static_cast<unsigned char>(cur.front()))) cur.erase(0, 1);
    while (!cur.empty() && std::isspace(static_cast<unsigned char>(cur.back()))) cur.pop_back();
    if (!cur.empty()) tokens.push_back(cur);

    return tokens;
}

} // namespace Filters
