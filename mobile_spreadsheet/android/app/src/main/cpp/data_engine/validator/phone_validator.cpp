/*
 * phone_validator.cpp  —  Indian Phone Number Validator (Phase 2)
 *
 * RULES:
 *   1. Extract digits only (strip +91, 0, spaces, dashes)
 *   2. Must be exactly 10 digits after prefix removal
 *   3. First digit must be 6, 7, 8, or 9
 *   4. Cannot be all-same digits (9999999999)
 *   5. Cannot be all zeros
 *
 * DETECT vs VALIDATE:
 *   PhonePlugin.detect() → returns PHONE type (structural match)
 *   PhoneValidator.validate() → confirms it's a REAL number (semantic check)
 *
 * RELATED:
 *   data_engine/detector/plugins/phone_plugin.h  (detection)
 *   data_engine/cleaning/phone_cleaner.h         (normalization)
 */
#include "phone_validator.h"
#include <cctype>

namespace Filters {

ValidationResult PhoneValidator::validate(const std::string& value) const {
    // 1. Extract digits
    std::string digits;
    for (char c : value) {
        if (std::isdigit((unsigned char)c)) digits += c;
    }

    // 2. Strip country codes
    if (digits.size() == 12 && digits.substr(0, 2) == "91") {
        digits = digits.substr(2);
    } else if (digits.size() == 11 && digits[0] == '0') {
        digits = digits.substr(1);
    }

    // 3. Length check
    if (digits.size() != 10) {
        return {false,
                "Invalid length: " + std::to_string(digits.size()) + " digits (expected 10)",
                "Provide 10-digit number starting with 6, 7, 8, or 9",
                0.95f};
    }

    // 4. First digit check (Indian mobile starts with 6–9)
    char first = digits[0];
    if (first < '6' || first > '9') {
        return {false,
                "First digit '" + std::string(1, first) + "' is invalid (must be 6, 7, 8, or 9)",
                "Indian mobile numbers always start with 6, 7, 8, or 9",
                0.98f};
    }

    // 5. All-same digits check (1111111111, 9999999999 etc.)
    bool allSame = true;
    for (char c : digits) {
        if (c != digits[0]) { allSame = false; break; }
    }
    if (allSame) {
        return {false,
                "All repeating digits (" + digits + ") — clearly not a real number",
                "Enter a genuine 10-digit mobile number",
                0.99f};
    }

    // 6. All zeros
    if (digits == "0000000000") {
        return {false, "All zeros — not a valid number", "Enter real phone number", 0.99f};
    }

    return {true, "Valid Indian mobile number", "", 1.0f};
}

} // namespace Filters
