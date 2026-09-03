#pragma once
#include "validator_base.h"
namespace Filters {
/// GST Number structural validator
/// Format: 2-digit state + 10-char PAN + entity + Z + checksum = 15 chars total
class GstValidator : public IValidator {
public:
    std::string getName() const override { return "GstValidator"; }
    ValidationResult validate(const std::string& value) const override;
};
} // namespace Filters
