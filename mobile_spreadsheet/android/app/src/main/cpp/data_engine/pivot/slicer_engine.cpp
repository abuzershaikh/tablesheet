/*
 * slicer_engine.cpp — Cross-Filtering & Multi-Slicer Logic Implementation
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#include "slicer_engine.h"

namespace Filters {

void SlicerEngine::setFilter(int colIndex, const std::vector<std::string>& selectedValues) {
    if (selectedValues.empty()) {
        m_activeFilters.erase(colIndex);
    } else {
        m_activeFilters[colIndex] = std::unordered_set<std::string>(selectedValues.begin(), selectedValues.end());
    }
}

void SlicerEngine::clearFilter(int colIndex) {
    m_activeFilters.erase(colIndex);
}

void SlicerEngine::clearAllFilters() {
    m_activeFilters.clear();
}

std::vector<SlicerItemStatus> SlicerEngine::getSlicerState(const PivotCacheEngine& cache, int targetColIndex) const {
    std::vector<SlicerItemStatus> result;
    const auto& uniqueVals = cache.getUniqueValues(targetColIndex);
    if (uniqueVals.empty()) return result;

    // Cross-filtering: Filter dataset using ALL filters EXCEPT targetColIndex
    std::unordered_map<int, std::unordered_set<std::string>> otherFilters = m_activeFilters;
    otherFilters.erase(targetColIndex);

    std::vector<int> matchingRows = cache.getMatchingRowIndices(otherFilters);

    // Count records per value in matching rows
    std::unordered_map<std::string, int> valueCounts;
    for (int r : matchingRows) {
        const std::string& val = cache.getCellValue(r, targetColIndex);
        valueCounts[val]++;
    }

    // Check currently selected items for targetColIndex
    auto selIt = m_activeFilters.find(targetColIndex);
    bool hasTargetSelection = (selIt != m_activeFilters.end() && !selIt->second.empty());

    result.reserve(uniqueVals.size());
    for (const auto& val : uniqueVals) {
        SlicerItemStatus item;
        item.value = val;
        
        auto countIt = valueCounts.find(val);
        item.recordCount = (countIt != valueCounts.end()) ? countIt->second : 0;
        item.isEnabled = (item.recordCount > 0);

        if (hasTargetSelection) {
            item.isSelected = (selIt->second.find(val) != selIt->second.end());
        } else {
            item.isSelected = true; // Default: all selected if no filter specified
        }

        result.push_back(item);
    }

    return result;
}

} // namespace Filters
