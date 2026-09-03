#pragma once
#include "validator_base.h"
namespace Filters {
/// Aadhaar Number Validator with Verhoeff checksum algorithm
/// 12 digits, cannot start with 0/1, must pass Verhoeff check
class AadhaarValidator : public IValidator {
public:
    std::string getName() const override { return "AadhaarValidator"; }
    ValidationResult validate(const std::string& value) const override;
private:
    static const int d[10][10];   ///< Verhoeff multiplication table
    static const int p[8][10];    ///< Verhoeff permutation table
    static const int inv[10];     ///< Verhoeff inverse table
    static bool verhoeff(const std::string& digits);
};
} // namespace Filters
