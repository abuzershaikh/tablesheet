/*
 * header_flattener.h  —  Enterprise Multi-Level Merged Header Flattener
 *
 * Folder: android/app/src/main/cpp/data_engine/analyzer/
 *
 * PURPOSE:
 *   Flattens 2-row or 3-row hierarchical/merged headers from complex Excel/PDF/Accounting reports.
 *
 * EXAMPLE:
 *   Row 1: |       2024 Revenue       |       2024 Expenses      |
 *   Row 2: |  Q1  |  Q2  |  Q3  |  Q4 |  Q1  |  Q2  |  Q3  |  Q4 |
 *   Output:
 *   [ "2024_Revenue_Q1", "2024_Revenue_Q2", "2024_Revenue_Q3", "2024_Revenue_Q4",
 *     "2024_Expenses_Q1", "2024_Expenses_Q2", "2024_Expenses_Q3", "2024_Expenses_Q4" ]
 */
#pragma once
#include <string>
#include <vector>

namespace Filters {

struct FlattenedHeaderResult {
    std::vector<std::string> flattenedHeaders;
    int headerRowCount = 1;
    bool wasMultiLevel = false;
};

class HeaderFlattener {
public:
    static HeaderFlattener& getInstance() {
        static HeaderFlattener instance;
        return instance;
    }

    /// Flattens a 2D matrix of header rows into a single list of unique column headers
    FlattenedHeaderResult flatten(const std::vector<std::vector<std::string>>& headerRows,
                                  const std::string& delimiter = "_") const;

    /// Sanitizes a header string into a clean identifier (removes spaces, special symbols)
    static std::string sanitizeHeader(const std::string& name);

private:
    HeaderFlattener() = default;
};

} // namespace Filters
