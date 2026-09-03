/*
 * pivot_cache_engine.cpp — C++ Native Pivot Cache Implementation
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#include "pivot_cache_engine.h"
#include <algorithm>

namespace Filters {

const std::string PivotCacheEngine::s_empty = "";

void PivotCacheEngine::clear() {
    m_headers.clear();
    m_headerToIndex.clear();
    m_records.clear();
    m_uniqueValuesCache.clear();
}

void PivotCacheEngine::buildCache(const std::vector<std::string>& headers, 
                                  const std::vector<std::vector<std::string>>& rowData) {
    clear();
    m_headers = headers;
    for (size_t i = 0; i < headers.size(); ++i) {
        m_headerToIndex[headers[i]] = static_cast<int>(i);
    }

    m_records.reserve(rowData.size());
    for (const auto& r : rowData) {
        PivotRecord rec;
        rec.values = r;
        if (rec.values.size() < headers.size()) {
            rec.values.resize(headers.size(), "");
        }
        m_records.push_back(std::move(rec));
    }
}

int PivotCacheEngine::getColumnIndex(const std::string& headerName) const {
    auto it = m_headerToIndex.find(headerName);
    if (it != m_headerToIndex.end()) return it->second;
    return -1;
}

const std::vector<std::string>& PivotCacheEngine::getUniqueValues(int colIndex) const {
    if (colIndex < 0 || colIndex >= getColCount()) {
        static const std::vector<std::string> emptyVec;
        return emptyVec;
    }

    auto cacheIt = m_uniqueValuesCache.find(colIndex);
    if (cacheIt != m_uniqueValuesCache.end()) {
        return cacheIt->second;
    }

    std::unordered_set<std::string> setVals;
    for (const auto& rec : m_records) {
        if (colIndex < static_cast<int>(rec.values.size())) {
            setVals.insert(rec.values[colIndex]);
        }
    }

    std::vector<std::string> uniqueVec(setVals.begin(), setVals.end());
    std::sort(uniqueVec.begin(), uniqueVec.end());

    m_uniqueValuesCache[colIndex] = std::move(uniqueVec);
    return m_uniqueValuesCache[colIndex];
}

const std::vector<std::string>& PivotCacheEngine::getUniqueValues(const std::string& headerName) const {
    int idx = getColumnIndex(headerName);
    return getUniqueValues(idx);
}

std::vector<int> PivotCacheEngine::getMatchingRowIndices(
    const std::unordered_map<int, std::unordered_set<std::string>>& activeFilters) const {
    
    std::vector<int> matchingIndices;
    matchingIndices.reserve(m_records.size());

    for (int r = 0; r < static_cast<int>(m_records.size()); ++r) {
        const auto& rec = m_records[r];
        bool match = true;

        for (const auto& filterPair : activeFilters) {
            int colIdx = filterPair.first;
            const auto& allowedSet = filterPair.second;

            if (allowedSet.empty()) continue; // No restriction

            std::string val = (colIdx >= 0 && colIdx < static_cast<int>(rec.values.size())) ? rec.values[colIdx] : "";
            if (allowedSet.find(val) == allowedSet.end()) {
                match = false;
                break;
            }
        }

        if (match) {
            matchingIndices.push_back(r);
        }
    }
    return matchingIndices;
}

const std::string& PivotCacheEngine::getCellValue(int rowIndex, int colIndex) const {
    if (rowIndex < 0 || rowIndex >= static_cast<int>(m_records.size())) return s_empty;
    const auto& rec = m_records[rowIndex];
    if (colIndex < 0 || colIndex >= static_cast<int>(rec.values.size())) return s_empty;
    return rec.values[colIndex];
}

} // namespace Filters
