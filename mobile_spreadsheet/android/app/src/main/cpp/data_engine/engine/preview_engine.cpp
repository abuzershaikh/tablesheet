#include "preview_engine.h"
#include "../../json.hpp"
#include <unordered_set>
#include <chrono>

using json = nlohmann::json;

namespace Filters {

std::string PreviewStats::toJson() const {
    json j;
    j["total"] = total;
    j["matched"] = matched;
    j["hidden"] = hidden;
    j["duplicates"] = duplicates;
    j["blank"] = blank;
    j["invalid"] = invalid;
    j["changed"] = changed;
    j["errors"] = errors;
    j["executionTimeMs"] = executionTimeMs;
    return j.dump();
}

PreviewStats PreviewEngine::generatePreview(
        int totalRows, 
        std::shared_ptr<FilterRule> rule,
        const std::function<std::string(int)>& getCellVal) {
    
    auto startTime = std::chrono::high_resolution_clock::now();
    PreviewStats stats;
    stats.total = totalRows;
    std::unordered_set<std::string> seenValues;

    for (int r = 0; r < totalRows; r++) {
        std::string val = getCellVal(r);
        
        if (val.empty()) {
            stats.blank++;
            stats.hidden++;
            continue;
        }

        if (seenValues.find(val) != seenValues.end()) {
            stats.duplicates++;
        } else {
            seenValues.insert(val);
        }

        if (rule) {
            FilterContext ctx;
            ctx.cellValue = val;
            ctx.row = r;
            ctx.col = 0; // Previews are typically per-column

            if (rule->evaluate(ctx)) {
                stats.matched++;
            } else {
                stats.hidden++;
            }
        } else {
            stats.matched++;
        }
    }

    auto endTime = std::chrono::high_resolution_clock::now();
    stats.executionTimeMs = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();

    return stats;
}

} // namespace Filters
