#ifndef PREVIEW_ENGINE_H
#define PREVIEW_ENGINE_H

#include <string>
#include "../rules/filter_rule.h"
#include <memory>
#include <functional>

namespace Filters {

struct PreviewStats {
    int total = 0;
    int matched = 0;
    int hidden = 0;
    int duplicates = 0;
    int blank = 0;
    int invalid = 0;
    int changed = 0;
    int errors = 0;
    long long executionTimeMs = 0;
    
    std::string toJson() const;
};

class PreviewEngine {
public:
    static PreviewStats generatePreview(
        int totalRows, 
        std::shared_ptr<FilterRule> rule,
        const std::function<std::string(int)>& getCellVal);
};

} // namespace Filters

#endif // PREVIEW_ENGINE_H
