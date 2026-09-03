/*
 * gst_validator.cpp  —  GST Number Structural Validator (Phase 2)
 *
 * FORMAT: 15 characters
 *   [0-1]  = State code 01–37
 *   [2-11] = PAN number (AAAAA9999A format)
 *   [12]   = Entity number (1–9 or A–Z)
 *   [13]   = Always 'Z'
 *   [14]   = Checksum character
 *
 * NOTE: We do structural validation. Full checksum requires GSTIN API.
 *
 * RELATED:
 *   data_engine/detector/plugins/id_plugin.h   (detection — returns UUID/GST type)
 *   data_engine/cleaning/data_cleaner.h        (uppercase normalization for GST)
 */
#include "gst_validator.h"
#include <cctype>

namespace Filters {

ValidationResult GstValidator::validate(const std::string& value) const {
    // Normalize: uppercase, remove spaces/dashes
    std::string v;
    for (char c : value) {
        if (!std::isspace((unsigned char)c) && c != '-') {
            v += std::toupper((unsigned char)c);
        }
    }

    if (v.size() != 15) {
        return {false,
                "GST must be 15 characters (got " + std::to_string(v.size()) + ")",
                "Format: 2-digit state + 10-char PAN + entity + Z + check",
                0.95f};
    }

    // State code 01–37
    bool isDigit0 = std::isdigit((unsigned char)v[0]);
    bool isDigit1 = std::isdigit((unsigned char)v[1]);
    if (!isDigit0 || !isDigit1) {
        return {false, "First 2 chars must be numeric state code",
                "Example: 27 for Maharashtra", 0.97f};
    }
    int stateCode = (v[0] - '0') * 10 + (v[1] - '0');
    if (stateCode < 1 || stateCode > 37) {
        return {false,
                "Invalid state code '" + v.substr(0, 2) + "' (must be 01–37)",
                "Check first 2 digits (state code)",
                0.97f};
    }

    // PAN portion: positions 2–11 → AAAAA9999A
    std::string pan = v.substr(2, 10);
    for (int i = 0; i < 5; i++) {
        if (!std::isalpha((unsigned char)pan[i])) {
            return {false, "PAN chars 1–5 must be letters (got '" +
                    std::string(1, pan[i]) + "' at position " + std::to_string(i+3) + ")",
                    "Correct PAN portion (positions 3–7)", 0.96f};
        }
    }
    for (int i = 5; i < 9; i++) {
        if (!std::isdigit((unsigned char)pan[i])) {
            return {false, "PAN chars 6–9 must be digits",
                    "Check PAN portion (positions 8–11)", 0.96f};
        }
    }
    if (!std::isalpha((unsigned char)pan[9])) {
        return {false, "PAN 10th char must be a letter",
                "Check position 12", 0.96f};
    }

    // Entity number (position 12) — alphanumeric
    if (!std::isalnum((unsigned char)v[12])) {
        return {false,
                "Entity number '" + std::string(1, v[12]) + "' is invalid (must be alphanumeric)",
                "Position 13 must be a digit or letter", 0.94f};
    }

    // Position 13 must be 'Z'
    if (v[13] != 'Z') {
        return {false,
                "Position 14 must be 'Z' (got '" + std::string(1, v[13]) + "')",
                "GST format requires 'Z' at position 14", 0.97f};
    }

    return {true, "Valid GST format (structural validation passed)", "", 0.9f};
}

} // namespace Filters
