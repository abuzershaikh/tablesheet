/*
 * pivot_cache_engine.h — C++ Native Pivot Cache Engine
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#pragma once
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <memory>

namespace Filters {

struct PivotRecord {
    std::vector<std::string> values;
};

class PivotCacheEngine {
public:
    PivotCacheEngine() = default;
    ~PivotCacheEngine() = default;

    void buildCache(const std::vector<std::string>& headers, 
                    const std::vector<std::vector<std::string>>& rowData);

    int getRowCount() const { return static_cast<int>(m_records.size()); }
    int getColCount() const { return static_cast<int>(m_headers.size()); }
    const std::vector<std::string>& getHeaders() const { return m_headers; }
    int getColumnIndex(const std::string& headerName) const;

    const std::vector<std::string>& getUniqueValues(int colIndex) const;
    const std::vector<std::string>& getUniqueValues(const std::string& headerName) const;

    std::vector<int> getMatchingRowIndices(const std::unordered_map<int, std::unordered_set<std::string>>& activeFilters) const;

    const std::string& getCellValue(int rowIndex, int colIndex) const;

    void clear();

private:
    std::vector<std::string> m_headers;
    std::unordered_map<std::string, int> m_headerToIndex;
    std::vector<PivotRecord> m_records;
    mutable std::unordered_map<int, std::vector<std::string>> m_uniqueValuesCache;
    static const std::string s_empty;
};

} // namespace Filters
