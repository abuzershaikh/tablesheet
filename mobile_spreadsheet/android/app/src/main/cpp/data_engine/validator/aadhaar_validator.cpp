/*
 * aadhaar_validator.cpp  —  Aadhaar Number Validator with Verhoeff Checksum (Phase 2)
 *
 * ALGORITHM:
 *   Aadhaar uses the Verhoeff algorithm (dihedral group D5) for checksum.
 *   Steps: traverse digits right-to-left, apply permutation table p,
 *          then multiplication table d, check if result is 0.
 *
 * RULES:
 *   1. Must be exactly 12 digits
 *   2. First digit cannot be 0 or 1
 *   3. Must pass Verhoeff checksum
 *
 * RELATED:
 *   data_engine/detector/plugins/id_plugin.h  (Aadhaar pattern detection)
 *   data_engine/validator/phone_validator.h   (similar pattern)
 */
#include "aadhaar_validator.h"
#include <cctype>

namespace Filters {

// Verhoeff multiplication table (dihedral group D5)
const int AadhaarValidator::d[10][10] = {
    {0,1,2,3,4,5,6,7,8,9},
    {1,2,3,4,0,6,7,8,9,5},
    {2,3,4,0,1,7,8,9,5,6},
    {3,4,0,1,2,8,9,5,6,7},
    {4,0,1,2,3,9,5,6,7,8},
    {5,9,8,7,6,0,4,3,2,1},
    {6,5,9,8,7,1,0,4,3,2},
    {7,6,5,9,8,2,1,0,4,3},
    {8,7,6,5,9,3,2,1,0,4},
    {9,8,7,6,5,4,3,2,1,0}
};

// Verhoeff permutation table
const int AadhaarValidator::p[8][10] = {
    {0,1,2,3,4,5,6,7,8,9},
    {1,5,7,6,2,8,3,0,9,4},
    {5,8,0,3,7,9,6,1,4,2},
    {8,9,1,6,0,4,3,5,2,7},
    {9,4,5,3,1,2,6,8,7,0},
    {4,2,8,6,5,7,3,9,0,1},
    {2,7,9,3,8,0,6,4,1,5},
    {7,0,4,6,9,1,3,2,5,8}
};

// Verhoeff inverse table
const int AadhaarValidator::inv[10] = {0,4,3,2,1,5,6,7,8,9};

bool AadhaarValidator::verhoeff(const std::string& digits) {
    int c = 0;
    int n = (int)digits.size();
    for (int i = 0; i < n; i++) {
        int digit = digits[n - 1 - i] - '0';
        c = d[c][p[i % 8][digit]];
    }
    return c == 0;
}

ValidationResult AadhaarValidator::validate(const std::string& value) const {
    // Extract digits, reject non-digit non-separator chars
    std::string digits;
    for (char c : value) {
        if (std::isdigit((unsigned char)c)) {
            digits += c;
        } else if (!std::isspace((unsigned char)c) && c != '-') {
            return {false,
                    "Non-numeric character '" + std::string(1, c) + "' found",
                    "Aadhaar must contain only digits (spaces/hyphens allowed)",
                    0.99f};
        }
    }

    if (digits.size() != 12) {
        return {false,
                "Aadhaar must be 12 digits (got " + std::to_string(digits.size()) + ")",
                "Provide all 12 digits of the Aadhaar number",
                0.98f};
    }

    if (digits[0] == '0' || digits[0] == '1') {
        return {false,
                "Aadhaar cannot start with 0 or 1 (got '" + std::string(1, digits[0]) + "')",
                "Valid Aadhaar always starts with 2–9",
                0.99f};
    }

    if (!verhoeff(digits)) {
        return {false,
                "Failed Verhoeff checksum — likely fake, mistyped, or corrupted",
                "Verify the Aadhaar number digit by digit",
                0.95f};
    }

    return {true, "Valid Aadhaar number (Verhoeff checksum passed)", "", 1.0f};
}

} // namespace Filters
