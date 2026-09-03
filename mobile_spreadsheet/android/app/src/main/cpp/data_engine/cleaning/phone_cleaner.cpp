/*
 * phone_cleaner.cpp  —  Phone Number Normalization Logic
 */
#include "phone_cleaner.h"
#include <cctype>

namespace Filters {

std::string PhoneCleaner::normalize(const std::string& rawPhone) {
    if (rawPhone.empty()) return rawPhone;

    // Step 1: Extract only digits and leading +
    bool hasPlus = false;
    std::string digits;
    for (size_t i = 0; i < rawPhone.size(); i++) {
        char c = rawPhone[i];
        if (c == '+' && digits.empty() && !hasPlus) { hasPlus = true; }
        else if (std::isdigit((unsigned char)c)) { digits += c; }
        // skip spaces, dashes, parens
    }

    if (digits.empty()) return rawPhone; // can't normalize

    // Step 2: Identify and normalize
    // Pattern: 10 digits starting with 6-9 → Indian mobile
    if (digits.size() == 10) {
        char f = digits[0];
        if (f >= '6' && f <= '9') {
            return "+91" + digits;
        }
    }

    // Pattern: 11 digits starting with 0 → strip 0, add +91
    if (digits.size() == 11 && digits[0] == '0') {
        std::string mobile = digits.substr(1);
        char f = mobile[0];
        if (f >= '6' && f <= '9') {
            return "+91" + mobile;
        }
    }

    // Pattern: 12 digits starting with 91 → add +
    if (digits.size() == 12 && digits.substr(0, 2) == "91") {
        return "+" + digits;
    }

    // International: already has plus → return +digits
    if (hasPlus && digits.size() >= 7) {
        return "+" + digits;
    }

    // Fallback: return as-is (don't mangle unknown formats)
    return rawPhone;
}

} // namespace Filters
