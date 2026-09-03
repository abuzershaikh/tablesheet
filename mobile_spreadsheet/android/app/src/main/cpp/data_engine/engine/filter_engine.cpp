#include "filter_engine.h"

#include "../rules/rule_parser.h"
#include "preview_engine.h"
#include "../../json.hpp"

using json = nlohmann::json;

namespace Filters {

void FilterEngine::addRule(const std::string& sheetId, int col, std::shared_ptr<FilterRule> rule) {
    std::lock_guard<std::mutex> lock(engineMutex);
    sheetFilters[sheetId][col] = rule;
    rowVisibilityCache.erase(sheetId); // Invalidate cache
}

void FilterEngine::addRuleFromJson(const std::string& sheetId, int col, const std::string& jsonRule) {
    auto rule = RuleParser::parse(jsonRule);
    if (rule) {
        addRule(sheetId, col, rule);
    }
}

std::string FilterEngine::getPreviewStats(const std::string& sheetId, int col, const std::string& jsonRule, int totalRows, const std::function<std::string(int, int)>& getCellVal) {
    auto rule = RuleParser::parse(jsonRule);
    auto colCellGetter = [&](int r) { return getCellVal(r, col); };
    PreviewStats stats = PreviewEngine::generatePreview(totalRows, rule, colCellGetter);
    return stats.toJson();
}

void FilterEngine::clearRules(const std::string& sheetId) {
    std::lock_guard<std::mutex> lock(engineMutex);
    sheetFilters.erase(sheetId);
    rowVisibilityCache.erase(sheetId); // Invalidate cache
}

bool FilterEngine::evaluateRow(const std::string& sheetId, int row, const std::function<std::string(int)>& getCellVal) {
    std::lock_guard<std::mutex> lock(engineMutex);
    if (sheetFilters.find(sheetId) == sheetFilters.end()) return true;

    for (const auto& [col, rule] : sheetFilters[sheetId]) {
        std::string cellVal = getCellVal(col);
        FilterContext ctx;
        ctx.row = row;
        ctx.col = col;
        ctx.cellValue = cellVal;
        
        try {
            std::size_t pos;
            ctx.numericValue = std::stod(cellVal, &pos);
            if (pos != cellVal.length()) ctx.numericValue = __builtin_nan("");
        } catch (...) {
            ctx.numericValue = __builtin_nan("");
        }

        if (!rule->evaluate(ctx)) {
            return false;
        }
    }
    return true;
}

const uint8_t* FilterEngine::getVisibleRowsBitmap(const std::string& sheetId, int maxRows, const std::function<std::string(int, int)>& getCellVal, int& outLength) {
    std::lock_guard<std::mutex> lock(engineMutex);
    
    // Check if we need to rebuild the cache
    auto it = rowVisibilityCache.find(sheetId);
    if (it == rowVisibilityCache.end() || it->second.size() != maxRows) {
        std::vector<uint8_t> bitmap(maxRows, 1); // 1 = visible, 0 = hidden
        
        for (int r = 0; r < maxRows; ++r) {
            auto rowGetter = [&](int c) { return getCellVal(r, c); };
            
            bool isVisible = true;
            if (sheetFilters.find(sheetId) != sheetFilters.end()) {
                for (const auto& [col, rule] : sheetFilters[sheetId]) {
                    FilterContext ctx;
                    ctx.row = r;
                    ctx.col = col;
                    ctx.cellValue = rowGetter(col);
                    if (!rule->evaluate(ctx)) {
                        isVisible = false;
                        break;
                    }
                }
            }
            bitmap[r] = isVisible ? 1 : 0;
        }
        
        rowVisibilityCache[sheetId] = std::move(bitmap);
    }
    
    outLength = rowVisibilityCache[sheetId].size();
    return rowVisibilityCache[sheetId].data();
}

void FilterEngine::evaluateSingleRow(const std::string& sheetId, int row, const std::function<std::string(int, int)>& getCellVal) {
    std::lock_guard<std::mutex> lock(engineMutex);
    auto it = rowVisibilityCache.find(sheetId);
    if (it != rowVisibilityCache.end() && row < it->second.size()) {
        auto rowGetter = [&](int c) { return getCellVal(row, c); };
        
        bool isVisible = true;
        if (sheetFilters.find(sheetId) != sheetFilters.end()) {
            for (const auto& [col, rule] : sheetFilters[sheetId]) {
                FilterContext ctx;
                ctx.row = row;
                ctx.col = col;
                ctx.cellValue = rowGetter(col);
                if (!rule->evaluate(ctx)) {
                    isVisible = false;
                    break;
                }
            }
        }
        it->second[row] = isVisible ? 1 : 0;
    }
}

std::string FilterEngine::getHiddenRowsJson(const std::string& sheetId, int maxRows, const std::function<std::string(int, int)>& getCellVal) {
    std::vector<int> hidden;
    
    for (int r = 0; r < maxRows; ++r) {
        auto rowGetter = [&](int c) {
            return getCellVal(r, c);
        };
        
        if (!evaluateRow(sheetId, r, rowGetter)) {
            hidden.push_back(r);
        }
    }
    
    json j = hidden;
    return j.dump();
}

} // namespace Filters
