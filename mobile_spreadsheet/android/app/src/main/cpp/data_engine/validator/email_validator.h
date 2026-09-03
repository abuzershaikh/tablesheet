#pragma once
#include "validator_base.h"
namespace Filters {
class EmailValidator : public IValidator {
public:
    std::string getName() const override { return "EmailValidator"; }
    ValidationResult validate(const std::string& value) const override;
};
} // namespace Filters
