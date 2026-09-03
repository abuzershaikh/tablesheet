#ifndef TEXT_FILTER_H
#define TEXT_FILTER_H

#include "filter_rule.h"
#include <string>

namespace Filters {

enum class TextOperator {
    EQUALS,
    CONTAINS,
    STARTS_WITH,
    ENDS_WITH,
    NOT_EQUALS,
    NOT_CONTAINS
};

class TextFilter : public FilterRule {
public:
    TextFilter(TextOperator op, const std::string& value);

    bool evaluate(const FilterContext& ctx) const override;

private:
    TextOperator op;
    std::string value;
    
    // helper to convert to lower case for case-insensitive matching if needed
    std::string toLower(const std::string& str) const;
};

} // namespace Filters

#endif // TEXT_FILTER_H
