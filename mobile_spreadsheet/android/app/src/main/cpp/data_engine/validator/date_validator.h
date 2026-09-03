#pragma once
#include "validator_base.h"
namespace Filters {
/// Calendar date validator — ensures dates are actually valid calendar dates
/// e.g. 30-02-2024 → INVALID (February has no 30th day)
class DateValidator : public IValidator {
public:
    std::string getName() const override { return "DateValidator"; }
    ValidationResult validate(const std::string& value) const override;
private:
    static bool isLeapYear(int y);
    static int daysInMonth(int m, int y);
};
} // namespace Filters
