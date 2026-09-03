#include "text_filter.h"
#include <algorithm>
#include <cctype>

namespace Filters {

TextFilter::TextFilter(TextOperator op, const std::string& value)
    : op(op), value(toLower(value)) {}

std::string TextFilter::toLower(const std::string& str) const {
    std::string result = str;
    std::transform(result.begin(), result.end(), result.begin(),
                   [](unsigned char c){ return std::tolower(c); });
    return result;
}

bool TextFilter::evaluate(const FilterContext& ctx) const {
    std::string cellVal = toLower(ctx.cellValue);
    
    switch (op) {
        case TextOperator::EQUALS:
            return cellVal == value;
        case TextOperator::NOT_EQUALS:
            return cellVal != value;
        case TextOperator::CONTAINS:
            return cellVal.find(value) != std::string::npos;
        case TextOperator::NOT_CONTAINS:
            return cellVal.find(value) == std::string::npos;
        case TextOperator::STARTS_WITH:
            return cellVal.rfind(value, 0) == 0;
        case TextOperator::ENDS_WITH:
            if (value.length() > cellVal.length()) return false;
            return std::equal(value.rbegin(), value.rend(), cellVal.rbegin());
        default:
            return true;
    }
}

} // namespace Filters
