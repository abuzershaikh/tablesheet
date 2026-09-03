/*
 * phone_plugin.cpp  —  Advanced Phone Number Detection Logic
 *
 * FOLDER CONTEXT:
 *   Header:    data_engine/detector/plugins/phone_plugin.h
 *   Interface: data_engine/detector/data_detector.h
 *   Cleaner:   data_engine/cleaning/phone_cleaner.cpp
 *
 * DETECTION RULES:
 *   - Strips allowed non-digit chars: spaces, +, -, (, )
 *   - Any remaining non-digit char → NOT a phone → 0.0
 *   - 10 digits starting with 6-9 → Indian mobile   → 0.97
 *   - 11 digits starting with 0   → Indian 0-prefix  → 0.95
 *   - 12 digits starting with 91  → Indian +91 form  → 0.95
 *   - Total digits 7–15, ≤1 plus  → International    → 0.85
 *   - Otherwise → 0.0
 */
#include "phone_plugin.h"
#include <cctype>
#include <string>

namespace Filters {

float PhonePlugin::detect(const std::string& val) const {
    if (val.empty() || val.size() > 20) return 0.0f;

    std::string digits;
    int plusCount = 0;

    for (char c : val) {
        if (std::isdigit(c)) {
            digits += c;
        } else if (c == '+') {
            plusCount++;
        } else if (c == ' ' || c == '-' || c == '(' || c == ')') {
            // allowed separators — skip
        } else {
            return 0.0f; // non-phone character found
        }
    }

    if (plusCount > 1) return 0.0f;
    int len = (int)digits.size();

    // Indian mobile: 10 digits, starts with 6,7,8,9
    if (len == 10 && plusCount == 0) {
        char first = digits[0];
        if (first >= '6' && first <= '9') return 0.97f;
    }

    // Indian 0-prefix: 011XXXXXXXX or 09XXXXXXXXX
    if (len == 11 && digits[0] == '0') return 0.95f;

    // Indian +91 prefix: 9112345678XX
    if (len == 12 && digits.substr(0, 2) == "91") return 0.95f;

    // International: digits 7-15, at most 1 plus
    if (len >= 7 && len <= 15) return 0.85f;

    return 0.0f;
}

} // namespace Filters
