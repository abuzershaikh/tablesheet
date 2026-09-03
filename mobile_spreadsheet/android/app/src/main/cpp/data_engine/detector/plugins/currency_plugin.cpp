/*
 * currency_plugin.cpp  —  Currency Detection Logic
 *
 * DETECTION RULES:
 *   1. Strip leading/trailing whitespace
 *   2. Check for currency symbols: ₹ $ € £ ¥ ¢
 *   3. Strip symbol, commas, spaces
 *   4. Remaining must be a valid decimal number
 *   5. Comma-separated number without symbol → 0.75 confidence
 */
#include "currency_plugin.h"
#include <cctype>
#include <stdexcept>

#include "../cleaning/extreme_cleaning_engine.h"
#include <algorithm>

namespace Filters {

float CurrencyPlugin::detect(const std::string& val) const {
    if (val.empty()) return 0.0f;

    std::string s = val;
    // Trim leading/trailing whitespace
    while (!s.empty() && std::isspace((unsigned char)s.front())) s.erase(s.begin());
    while (!s.empty() && std::isspace((unsigned char)s.back())) s.pop_back();
    if (s.empty()) return 0.0f;

    bool hasCurrencySymbol = false;
    std::string lower = s;
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c){ return std::tolower(c); });

    // Check for UTF-8 ₹ (E2 82 B9) or € (E2 82 AC)
    if (s.size() >= 3 && (unsigned char)s[0] == 0xE2) {
        if ((unsigned char)s[1] == 0x82 && ((unsigned char)s[2] == 0xB9 || (unsigned char)s[2] == 0xAC)) {
            hasCurrencySymbol = true;
        }
    } else if (!s.empty() && (s[0] == '$' || s[0] == '\xA3' /*£*/ || s[0] == '\xA2' /*¢*/ || s[0] == '\xA5' /*¥*/)) {
        hasCurrencySymbol = true;
    } else if (s.size() >= 2 && (unsigned char)s[0] == 0xC2) {
        hasCurrencySymbol = true;
    }

    // Text codes (Rs., INR, USD, EUR, GBP, AED, CAD, AUD)
    if (!hasCurrencySymbol) {
        if (lower.rfind("rs.", 0) == 0 || lower.rfind("rs ", 0) == 0 || lower.rfind("inr", 0) == 0 ||
            lower.rfind("usd", 0) == 0 || lower.rfind("eur", 0) == 0 || lower.rfind("gbp", 0) == 0 ||
            lower.rfind("aed", 0) == 0 || lower.rfind("cad", 0) == 0 || lower.rfind("aud", 0) == 0) {
            hasCurrencySymbol = true;
        } else if (lower.size() >= 2 && lower.substr(lower.size() - 2) == "/-") {
            hasCurrencySymbol = true;
        } else if (s.front() == '(' && s.back() == ')') {
            // Accounting negative e.g. (1,200.00)
            hasCurrencySymbol = true;
        }
    }

    std::string clean = ExtremeCleaningEngine::cleanNumericString(s, true);
    if (clean.empty()) return 0.0f;

    if (hasCurrencySymbol) return 0.98f;
    if (s.find(',') != std::string::npos && (s.find('.') != std::string::npos || std::count(s.begin(), s.end(), ',') > 0)) {
        return 0.75f; // comma-formatted number like 1,250 or 1.234,56
    }

    return 0.0f; // plain number — let NumberDetector handle it
}

} // namespace Filters
