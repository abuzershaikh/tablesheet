#ifndef TYPE_CACHE_H
#define TYPE_CACHE_H

#include <string>
#include <unordered_map>
#include <mutex>

#include "column_metadata.h"

namespace Filters {

class TypeCache {
public:
    static TypeCache& getInstance() {
        static TypeCache instance;
        return instance;
    }

    // Set the detected type for a column
    void setColumnMetadata(const std::string& sheetId, int col, const ColumnMetadata& metadata);
    void setColumnType(const std::string& sheetId, int col, DataType type, float confidence = 1.0f);

    // Get the cached metadata.
    ColumnMetadata getColumnMetadata(const std::string& sheetId, int col);

    // Invalidate when a cell is edited
    void invalidateColumn(const std::string& sheetId, int col);
    
    // Invalidate entire sheet
    void invalidateSheet(const std::string& sheetId);

private:
    TypeCache() = default;
    
    // Maps sheetId -> (columnIndex -> ColumnMetadata)
    std::unordered_map<std::string, std::unordered_map<int, ColumnMetadata>> cache;
    std::mutex cacheMutex;
};

} // namespace Filters

#endif // TYPE_CACHE_H
