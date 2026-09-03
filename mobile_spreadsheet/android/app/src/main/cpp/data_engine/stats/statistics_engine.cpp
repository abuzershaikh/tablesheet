#include "statistics_engine.h"
#include "../../json.hpp"
#include <cmath>
#include <algorithm>

using json = nlohmann::json;

namespace Filters {

std::string ColumnStats::toJson() const {
    json j;
    j["count"] = count;
    j["blank"] = blank;
    j["duplicates"] = duplicates;
    j["unique"] = unique;
    j["min"] = min;
    j["max"] = max;
    
    double avg = (count - blank) > 0 ? sum / (count - blank) : 0.0;
    j["average"] = avg;
    
    return j.dump();
}

void StatisticsEngine::processChunk(int column, DataPipeline::PipelineContext& ctx) {
    ColumnStats& stats = statsCache[column];
    
    int endRow = ctx.chunkStartIndex + ctx.chunkRowCount;
    if (endRow > ctx.totalRows) endRow = ctx.totalRows;
    
    for (int r = ctx.chunkStartIndex; r < endRow; ++r) {
        if (r < ctx.rowVisibility.size() && ctx.rowVisibility[r] == 0) continue; // Skip hidden
        
        std::string val = ctx.getCellVal(r, column);
        stats.count++;
        
        if (val.empty()) {
            stats.blank++;
            continue;
        }
        
        stats.frequencyMap[val]++;
        if (stats.frequencyMap[val] == 1) {
            stats.unique++;
        } else if (stats.frequencyMap[val] == 2) {
            stats.duplicates++;
        }
        
        try {
            double d = std::stod(val);
            if (stats.isFirstNumeric) {
                stats.min = d;
                stats.max = d;
                stats.isFirstNumeric = false;
            } else {
                if (d < stats.min) stats.min = d;
                if (d > stats.max) stats.max = d;
            }
            stats.sum += d;
        } catch (...) {
            // Not a number, ignore for numeric stats
        }
    }
}

ColumnStats StatisticsEngine::getStats(int column) const {
    auto it = statsCache.find(column);
    if (it != statsCache.end()) return it->second;
    return ColumnStats();
}

void StatisticsEngine::reset(int column) {
    statsCache.erase(column);
}

} // namespace Filters
