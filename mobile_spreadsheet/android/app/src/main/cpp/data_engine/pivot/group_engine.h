/*
 * group_engine.h — Multi-Level Row & Column Grouping Engine
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#pragma once
#include "pivot_cache_engine.h"
#include "aggregation_engine.h"
#include <string>
#include <vector>
#include <map>
#include <memory>

namespace Filters {

struct PivotCell {
    double value;
    std::string formattedValue;
};

struct PivotTableResult {
    std::vector<std::vector<std::string>> rowHeaderGrid; // Row labels per row level
    std::vector<std::vector<std::string>> colHeaderGrid; // Col labels per col level
    std::vector<std::vector<PivotCell>> dataGrid;        // Data cells [row][col]
    std::vector<double> rowSubtotals;
    std::vector<double> colSubtotals;
    double grandTotal;
};

class GroupEngine {
public:
    static PivotTableResult buildPivotTable(
        const PivotCacheEngine& cache,
        const std::vector<int>& matchingRowIndices,
        const std::vector<int>& rowColIndices,
        const std::vector<int>& colColIndices,
        int valColIndex,
        AggregationType aggType
    );
};

} // namespace Filters
