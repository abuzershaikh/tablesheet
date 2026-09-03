/*
 * subtotal_isolator.h  —  Subtotal & Report Noise Isolator
 *
 * Identifies and isolates repetitive header/footer artifacts, "Sub Total: ...",
 * "Page X of Y", and decorative dashed lines from spreadsheet tables.
 *
 * Folder: android/app/src/main/cpp/data_engine/analyzer/
 */
#ifndef SUBTOTAL_ISOLATOR_H
#define SUBTOTAL_ISOLATOR_H

#include <string>
#include <vector>

namespace Filters {

struct SubtotalRow {
    int originalRowIndex = 0;
    std::string detectedLabel;
    std::vector<std::string> values;
};

struct SubtotalIsolationResult {
    std::vector<std::vector<std::string>> cleanGrid;
    std::vector<SubtotalRow> isolatedSubtotals;
    int removedNoiseRowsCount = 0;
};

class SubtotalIsolator {
public:
    static SubtotalIsolator& getInstance() {
        static SubtotalIsolator instance;
        return instance;
    }

    // Isolate subtotal and noise rows from table grid
    SubtotalIsolationResult isolateSubtotals(
        const std::vector<std::vector<std::string>>& grid,
        bool hasHeader = true) const;

    // Check if a single row matches subtotal or report noise patterns
    bool isSubtotalOrNoiseRow(
        const std::vector<std::string>& row,
        std::string* outLabel = nullptr) const;

private:
    SubtotalIsolator() = default;
};

} // namespace Filters

#endif // SUBTOTAL_ISOLATOR_H
