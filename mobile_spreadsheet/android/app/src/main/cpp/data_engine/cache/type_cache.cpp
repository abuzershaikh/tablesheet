#include "type_cache.h"

namespace Filters {

void TypeCache::setColumnMetadata(const std::string& sheetId, int col, const ColumnMetadata& metadata) {
    std::lock_guard<std::mutex> lock(cacheMutex);
    cache[sheetId][col] = metadata;
}

void TypeCache::setColumnType(const std::string& sheetId, int col, DataType type, float confidence) {
    std::lock_guard<std::mutex> lock(cacheMutex);
    cache[sheetId][col].type = type;
    cache[sheetId][col].confidence = confidence;
}

ColumnMetadata TypeCache::getColumnMetadata(const std::string& sheetId, int col) {
    std::lock_guard<std::mutex> lock(cacheMutex);
    auto sheetIt = cache.find(sheetId);
    if (sheetIt != cache.end()) {
        auto colIt = sheetIt->second.find(col);
        if (colIt != sheetIt->second.end()) {
            return colIt->second;
        }
    }
    ColumnMetadata defaultMeta;
    return defaultMeta;
}

void TypeCache::invalidateColumn(const std::string& sheetId, int col) {
    std::lock_guard<std::mutex> lock(cacheMutex);
    auto sheetIt = cache.find(sheetId);
    if (sheetIt != cache.end()) {
        sheetIt->second.erase(col);
    }
}

void TypeCache::invalidateSheet(const std::string& sheetId) {
    std::lock_guard<std::mutex> lock(cacheMutex);
    cache.erase(sheetId);
}

} // namespace Filters
