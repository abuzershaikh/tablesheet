#include "number_filter.h"
#include <string>
#include <cmath>
#include <iostream>

namespace Filters {

NumberFilter::NumberFilter(NumberOperator op, double val1, double val2)
    : op(op), val1(val1), val2(val2) {}

bool NumberFilter::evaluate(const FilterContext& ctx) const {
    double cellNum = 0.0;
    try {
        cellNum = std::stod(ctx.cellValue);
    } catch (...) {
        return false; // Not a valid number
    }

    switch (op) {
        case NumberOperator::EQUALS:
            return std::abs(cellNum - val1) < 1e-9;
        case NumberOperator::NOT_EQUALS:
            return std::abs(cellNum - val1) >= 1e-9;
        case NumberOperator::GREATER_THAN:
            return cellNum > val1;
        case NumberOperator::LESS_THAN:
            return cellNum < val1;
        case NumberOperator::GREATER_EQUALS:
            return cellNum >= val1;
        case NumberOperator::LESS_EQUALS:
            return cellNum <= val1;
        case NumberOperator::BETWEEN:
            return cellNum >= val1 && cellNum <= val2;
        case NumberOperator::IS_EVEN:
            return std::fmod(cellNum, 2.0) == 0;
        case NumberOperator::IS_ODD:
            return std::fmod(cellNum, 2.0) != 0;
        default:
            return true;
    }
}

} // namespace Filters
