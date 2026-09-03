/*
 * group_engine.cpp — Multi-Level Row & Column Grouping Engine Implementation
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#include "group_engine.h"
#include <sstream>
#include <iomanip>
#include <set>

namespace Filters {

static std::string formatDouble(double val) {
    std::ostringstream ss;
    ss << std::fixed << std::setprecision(2) << val;
    return ss.str();
}

PivotTableResult GroupEngine::buildPivotTable(
    const PivotCacheEngine& cache,
    const std::vector<int>& matchingRowIndices,
    const std::vector<int>& rowColIndices,
    const std::vector<int>& colColIndices,
    int valColIndex,
    AggregationType aggType
) {
    PivotTableResult result;
    if (matchingRowIndices.empty()) {
        result.grandTotal = 0.0;
        return result;
    }

    // Map: RowKey -> (ColKey -> list of matching row indices in raw cache)
    std::map<std::vector<std::string>, std::map<std::vector<std::string>, std::vector<int>>> gridMap;
    std::set<std::vector<std::string>> uniqueRowKeys;
    std::set<std::vector<std::string>> uniqueColKeys;

    for (int rIdx : matchingRowIndices) {
        std::vector<std::string> rKey;
        for (int cIdx : rowColIndices) {
            rKey.push_back(cache.getCellValue(rIdx, cIdx));
        }
        if (rKey.empty()) rKey.push_back("Total");

        std::vector<std::string> cKey;
        for (int cIdx : colColIndices) {
            cKey.push_back(cache.getCellValue(rIdx, cIdx));
        }
        if (cKey.empty()) cKey.push_back("Values");

        uniqueRowKeys.insert(rKey);
        uniqueColKeys.insert(cKey);
        gridMap[rKey][cKey].push_back(rIdx);
    }

    std::vector<std::vector<std::string>> sortedRowKeys(uniqueRowKeys.begin(), uniqueRowKeys.end());
    std::vector<std::vector<std::string>> sortedColKeys(uniqueColKeys.begin(), uniqueColKeys.end());

    result.rowHeaderGrid = sortedRowKeys;
    result.colHeaderGrid = sortedColKeys;

    result.dataGrid.resize(sortedRowKeys.size());
    result.rowSubtotals.resize(sortedRowKeys.size(), 0.0);
    result.colSubtotals.resize(sortedColKeys.size(), 0.0);

    for (size_t r = 0; r < sortedRowKeys.size(); ++r) {
        result.dataGrid[r].resize(sortedColKeys.size());
        std::vector<int> allRowIndicesForThisRowKey;

        for (size_t c = 0; c < sortedColKeys.size(); ++c) {
            const auto& cellRowIndices = gridMap[sortedRowKeys[r]][sortedColKeys[c]];
            double val = AggregationEngine::compute(cache, cellRowIndices, valColIndex, aggType);

            result.dataGrid[r][c].value = val;
            result.dataGrid[r][c].formattedValue = formatDouble(val);

            allRowIndicesForThisRowKey.insert(allRowIndicesForThisRowKey.end(), 
                                              cellRowIndices.begin(), cellRowIndices.end());
        }

        result.rowSubtotals[r] = AggregationEngine::compute(cache, allRowIndicesForThisRowKey, valColIndex, aggType);
    }

    for (size_t c = 0; c < sortedColKeys.size(); ++c) {
        std::vector<int> allRowIndicesForThisColKey;
        for (size_t r = 0; r < sortedRowKeys.size(); ++r) {
            const auto& cellRowIndices = gridMap[sortedRowKeys[r]][sortedColKeys[c]];
            allRowIndicesForThisColKey.insert(allRowIndicesForThisColKey.end(),
                                              cellRowIndices.begin(), cellRowIndices.end());
        }
        result.colSubtotals[c] = AggregationEngine::compute(cache, allRowIndicesForThisColKey, valColIndex, aggType);
    }

    result.grandTotal = AggregationEngine::compute(cache, matchingRowIndices, valColIndex, aggType);
    return result;
}

} // namespace Filters
