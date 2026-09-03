/*
 * header_flattener.cpp  —  Enterprise Multi-Level Merged Header Flattener Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/analyzer/
 */
#include "header_flattener.h"
#include <algorithm>
#include <map>
#include <cctype>

namespace Filters {

std::string HeaderFlattener::sanitizeHeader(const std::string& name) {
    if (name.empty()) return "Column";
    std::string clean;
    bool lastWasUnderscore = false;

    for (char c : name) {
        if (std::isalnum(static_cast<unsigned char>(c))) {
            clean += c;
            lastWasUnderscore = false;
        } else if (std::isspace(static_cast<unsigned char>(c)) || c == '_' || c == '-' || c == '/' || c == '.') {
            if (!lastWasUnderscore && !clean.empty()) {
                clean += '_';
                lastWasUnderscore = true;
            }
        }
    }

    while (!clean.empty() && clean.back() == '_') clean.pop_back();
    return clean.empty() ? "Column" : clean;
}

FlattenedHeaderResult HeaderFlattener::flatten(
    const std::vector<std::vector<std::string>>& headerRows,
    const std::string& delimiter) const {

    FlattenedHeaderResult res;
    if (headerRows.empty()) return res;

    res.headerRowCount = static_cast<int>(headerRows.size());
    res.wasMultiLevel = (headerRows.size() > 1);

    // Find max column count
    size_t colCount = 0;
    for (const auto& row : headerRows) {
        if (row.size() > colCount) colCount = row.size();
    }
    if (colCount == 0) return res;

    // Build a forward-filled matrix for parent headers (span filling)
    std::vector<std::vector<std::string>> matrix(headerRows.size(), std::vector<std::string>(colCount, ""));

    for (size_t r = 0; r < headerRows.size(); r++) {
        std::string lastParent = "";
        for (size_t c = 0; c < colCount; c++) {
            std::string val = (c < headerRows[r].size()) ? headerRows[r][c] : "";
            // Trim whitespace
            while (!val.empty() && std::isspace(static_cast<unsigned char>(val.front()))) val.erase(0, 1);
            while (!val.empty() && std::isspace(static_cast<unsigned char>(val.back()))) val.pop_back();

            if (!val.empty()) {
                lastParent = val;
                matrix[r][c] = val;
            } else if (!lastParent.empty() && r < headerRows.size() - 1) {
                // Forward fill merged parent headers only on non-leaf levels
                matrix[r][c] = lastParent;
            } else {
                matrix[r][c] = "";
            }
        }
    }

    // Combine column parts vertically
    std::vector<std::string> rawCombined;
    for (size_t c = 0; c < colCount; c++) {
        std::string combined = "";
        for (size_t r = 0; r < headerRows.size(); r++) {
            const std::string& part = matrix[r][c];
            if (!part.empty()) {
                if (combined.empty()) {
                    combined = part;
                } else if (combined != part && part != "Total" && part != "Value") {
                    combined += delimiter + part;
                } else if (combined != part) {
                    combined += delimiter + part;
                }
            }
        }
        rawCombined.push_back(combined.empty() ? ("Column_" + std::to_string(c + 1)) : sanitizeHeader(combined));
    }

    // Ensure uniqueness (add _1, _2 if duplicates exist)
    std::map<std::string, int> nameCounts;
    for (const auto& name : rawCombined) {
        nameCounts[name]++;
    }

    std::map<std::string, int> seenCounts;
    for (const auto& name : rawCombined) {
        if (nameCounts[name] > 1) {
            seenCounts[name]++;
            if (seenCounts[name] == 1) {
                res.flattenedHeaders.push_back(name);
            } else {
                res.flattenedHeaders.push_back(name + "_" + std::to_string(seenCounts[name]));
            }
        } else {
            res.flattenedHeaders.push_back(name);
        }
    }

    return res;
}

} // namespace Filters
