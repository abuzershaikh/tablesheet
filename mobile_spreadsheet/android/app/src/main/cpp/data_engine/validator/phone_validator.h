#pragma once
#include "validator_base.h"
namespace Filters {
/// Validates Indian mobile phone numbers
/// 9999999999 → detected PHONE but INVALID (all repeating)
/// 7012345678 → VALID (starts with 7, non-repeating)
class PhoneValidator : public IValidator {
public:
    std::string getName() const override { return "PhoneValidator"; }
    ValidationResult validate(const std::string& value) const override;
};
} // namespace Filters
