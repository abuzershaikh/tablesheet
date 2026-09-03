#ifndef FILTER_ENGINE_H
#define FILTER_ENGINE_H

#include "data_engine/rules/filter_rule.h"
#include <vector>
#include <memory>
#include <unordered_map>
#include <string>
#include <mutex>
#include <functional>

namespace Filters {

class FilterEngine {
public:
    static FilterEngine& getInstance() {
        static FilterEngine instance;
        return instance;
    }

    void addRule(const std::string& sheetId, int col, std::shared_ptr<FilterRule> rule);
    
    // Parses a JSON string rule and adds it
    void addRuleFromJson(const std::string& sheetId, int col, const std::string& jsonRule);

    // Get preview stats without applying
    std::string getPreviewStats(const std::string& sheetId, int col, const std::string& jsonRule, int totalRows, const std::function<std::string(int, int)>& getCellVal);

    void clearRules(const std::string& sheetId);
    
    // Evaluate if a row should be visible. Returns true if visible.
    bool evaluateRow(const std::string& sheetId, int row, const std::function<std::string(int)>& getCellVal);

    // Returns a JSON array of hidden row indices (Legacy)
    std::string getHiddenRowsJson(const std::string& sheetId, int maxRows, const std::function<std::string(int, int)>& getCellVal);

    // High performance FFI Bitmap approach: Returns a pointer to a bool/byte array
    // The caller takes ownership of the memory, or it is stored in the cache.
    // For FFI, we return a struct or pointer. We'll return a raw pointer and its size as an out parameter.
    const uint8_t* getVisibleRowsBitmap(const std::string& sheetId, int maxRows, const std::function<std::string(int, int)>& getCellVal, int& outLength);

    // Incremental update
    void evaluateSingleRow(const std::string& sheetId, int row, const std::function<std::string(int, int)>& getCellVal);

private:
    FilterEngine() = default;
    
    // Maps sheetId -> (columnIndex -> rule)
    std::unordered_map<std::string, std::unordered_map<int, std::shared_ptr<FilterRule>>> sheetFilters;
    
    // Cache for visible row bitmap: Maps sheetId -> bitmap
    std::unordered_map<std::string, std::vector<uint8_t>> rowVisibilityCache;
    
    std::mutex engineMutex;
};

} // namespace Filters

#endif // FILTER_ENGINE_H
