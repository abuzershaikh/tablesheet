#ifndef NUMBER_FILTER_H
#define NUMBER_FILTER_H

#include "filter_rule.h"

namespace Filters {

enum class NumberOperator {
    EQUALS,
    NOT_EQUALS,
    GREATER_THAN,
    LESS_THAN,
    GREATER_EQUALS,
    LESS_EQUALS,
    BETWEEN,
    IS_EVEN,
    IS_ODD
};

class NumberFilter : public FilterRule {
public:
    NumberFilter(NumberOperator op, double val1, double val2 = 0.0);

    bool evaluate(const FilterContext& ctx) const override;

private:
    NumberOperator op;
    double val1;
    double val2;
};

} // namespace Filters

#endif // NUMBER_FILTER_H
