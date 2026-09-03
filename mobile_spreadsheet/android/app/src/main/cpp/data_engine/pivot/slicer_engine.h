/*
 * slicer_engine.h — Cross-Filtering & Multi-Slicer Logic
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#pragma once
#include "pivot_cache_engine.h"
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>

namespace Filters {

struct SlicerItemStatus {
    std::string value;
    bool isSelected;
    bool isEnabled; // False if cross-filtered out by OTHER slicers
    int recordCount;
};

class SlicerEngine {
public:
    SlicerEngine() = default;

    void setFilter(int colIndex, const std::vector<std::string>& selectedValues);
    void clearFilter(int colIndex);
    void clearAllFilters();

    const std::unordered_map<int, std::unordered_set<std::string>>& getActiveFilters() const {
        return m_activeFilters;
    }

    std::vector<SlicerItemStatus> getSlicerState(const PivotCacheEngine& cache, int targetColIndex) const;

private:
    std::unordered_map<int, std::unordered_set<std::string>> m_activeFilters;
};

} // namespace Filters
