/*
 * email_validator.cpp  —  Email Address Validator (Phase 2)
 *
 * RULES (RFC 5321 basic compliance):
 *   - No spaces
 *   - Exactly one '@'
 *   - Non-empty local part (before @)
 *   - Domain must have at least one '.'
 *   - Domain must not start/end with '.'
 *   - TLD must be at least 2 chars
 *
 * RELATED:
 *   data_engine/detector/data_detector.h  → EmailDetector (structural match)
 *   data_engine/cleaning/text_cleaner.h   → trim + lowercase
 */
#include "email_validator.h"
#include "../cleaning/email_cleaner.h"

namespace Filters {

ValidationResult EmailValidator::validate(const std::string& value) const {
    EmailMetadata meta = EmailCleaner::analyzeAndNormalize(value);
    if (!meta.isValid) {
        return {false, meta.validationMessage,
                "Format should be user@domain.com", 0.95f};
    }
    return {true, meta.validationMessage, "", (float)meta.confidenceScore / 100.0f};
}

} // namespace Filters

