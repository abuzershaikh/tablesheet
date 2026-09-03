#ifndef FILTER_RULE_H
#define FILTER_RULE_H

#include <string>
#include <vector>
#include <memory>

#include "../cache/column_metadata.h"

namespace Filters {

struct FilterContext {
    int row;
    int col;
    std::string cellValue;
    double numericValue; // NaN if not numeric
};

class FilterRule {
public:
    virtual ~FilterRule() = default;
    
    // Returns true if the cell value MATCHES the rule (should be kept visible)
    virtual bool evaluate(const FilterContext& ctx) const = 0;
};

} // namespace Filters

#endif // FILTER_RULE_H
