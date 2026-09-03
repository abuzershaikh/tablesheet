/*
 * validator_base.h  —  Validator Plugin Interface (Phase 2)
 *
 * FOLDER CONTEXT:
 *   Lives in:   data_engine/validator/
 *   Validators: phone_validator, email_validator, gst_validator,
 *               aadhaar_validator, date_validator
 *
 * DETECT vs VALIDATE:
 *   Detector  = WHAT type is this value? (phone, email, etc.)
 *   Validator = Is this value VALID for its type?
 *   Example:  9999999999 → detected as PHONE but INVALID (all repeating digits)
 *             ABCDE1234Z → detected as PAN but check digit may be wrong
 *
 * USAGE in AI Agent:
 *   After analyze_column detects type → run validator on dirty values
 *   Returns ValidationResult with reason + suggestedFix for user feedback
 */
#pragma once
#include <string>

namespace Filters {

struct ValidationResult {
    bool isValid;
    std::string reason;        ///< "All repeating digits — not a real number"
    std::string suggestedFix;  ///< "Enter a real 10-digit mobile starting with 6-9"
    float confidence;          ///< 0.0–1.0 how certain we are of the invalidity
};

class IValidator {
public:
    virtual ~IValidator() = default;
    virtual std::string getName() const = 0;
    virtual ValidationResult validate(const std::string& value) const = 0;
};

} // namespace Filters
