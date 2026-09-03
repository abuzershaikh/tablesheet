/*
 * extreme_cleaning_engine.cpp — Extreme Kaggle & Data Science Master Cleaning Engine Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "extreme_cleaning_engine.h"
#include "email_cleaner.h"
#include "text_cleaner.h"
#include <regex>
#include <algorithm>
#include <sstream>
#include <cmath>
#include <cctype>

namespace Filters {

ExtractedEntity ExtremeCleaningEngine::extractMixedCellData(const std::string& rawText) {
    ExtractedEntity entity;
    entity.rawData = rawText;
    entity.isValid = false;

    if (rawText.empty()) return entity;

    // 1. Extract Email Regex
    std::regex emailRegex(R"([\w.\u00C0-\u024F\u0600-\u06FF-]+@[\w.-]+\.[a-zA-Z]{2,})");
    std::smatch emailMatch;
    if (std::regex_search(rawText, emailMatch, emailRegex)) {
        entity.cleanEmail = emailMatch.str();
    }

    // 2. Extract Phone Regex (+91 / +CC or 10-digit)
    std::regex phoneRegex(R"((\+\d{1,3}[\s-]?)?\(?\d{3,5}\)?[\s-]?\d{3,4}[\s-]?\d{3,4})");
    std::smatch phoneMatch;
    if (std::regex_search(rawText, phoneMatch, phoneRegex)) {
        entity.cleanPhone = phoneMatch.str();
    }

    // 3. Extract Name from Email if explicit name missing
    if (!entity.cleanEmail.empty()) {
        entity.cleanName = deriveNameFromEmail(entity.cleanEmail);
    } else {
        entity.cleanName = sanitizeUnicodeText(rawText);
    }

    entity.isValid = !entity.cleanEmail.empty() || !entity.cleanPhone.empty() || !entity.cleanName.empty();
    return entity;
}

std::string ExtremeCleaningEngine::sanitizeUnicodeText(const std::string& input) {
    if (input.empty()) return "";
    
    std::string result;
    result.reserve(input.size());

    // Preserve alphanumeric, spaces, hyphens, and multi-byte UTF-8 letters (Arabic, Cyrillic, Latin-Ext)
    for (size_t i = 0; i < input.size(); ++i) {
        unsigned char uc = static_cast<unsigned char>(input[i]);
        if (uc >= 128) {
            // Keep multi-byte UTF-8 character intact
            result += input[i];
        } else if (std::isalnum(uc) || std::isspace(uc) || uc == '-' || uc == '.') {
            result += input[i];
        }
    }

    // Trim extra spaces
    std::string trimmed = TextCleaner::trim(result);
    return TextCleaner::titleCase(trimmed);
}

std::string ExtremeCleaningEngine::deriveNameFromEmail(const std::string& email) {
    if (email.empty() || email.find('@') == std::string::npos) return "";

    std::string localPart = email.substr(0, email.find('@'));
    std::string clean;
    for (char c : localPart) {
        if (std::isalpha(static_cast<unsigned char>(c))) clean += c;
        else if (c == '.' || c == '_' || c == '-') clean += ' ';
    }

    std::string trimmed = TextCleaner::trim(clean);
    return TextCleaner::titleCase(trimmed);
}

std::string ExtremeCleaningEngine::detectIndustryCategory(const std::string& text) {
    std::string lower = text;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

    if (lower.find("kg") != std::string::npos || lower.find("ml") != std::string::npos || lower.find("ltr") != std::string::npos) {
        return "Units & Measurement";
    }
    if (lower.find("apple") != std::string::npos || lower.find("samsung") != std::string::npos || lower.find("realme") != std::string::npos || lower.find("vivo") != std::string::npos) {
        return "Tech & Electronics";
    }
    if (lower.find("apple") != std::string::npos || lower.find("banana") != std::string::npos || lower.find("potato") != std::string::npos || lower.find("onion") != std::string::npos) {
        return "Produce & Groceries";
    }
    if (lower.find("lathe") != std::string::npos || lower.find("cnc") != std::string::npos || lower.find("motor") != std::string::npos || lower.find("pump") != std::string::npos) {
        return "Machinery & Hardware";
    }
    return "General Data";
}

static std::string toLowerAscii(const std::string& str) {
    std::string s = str;
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return std::tolower(c); });
    return s;
}

std::string ExtremeCleaningEngine::cleanNumericString(const std::string& rawInput, bool preserveDecimal) {
    if (rawInput.empty()) return "";

    std::string s = rawInput;
    // Trim
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(0, 1);
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    if (s.empty()) return "";

    // 1. Check sign
    bool isNegative = false;
    if (s.front() == '(' && s.back() == ')') {
        isNegative = true;
        s = s.substr(1, s.length() - 2);
    } else if (s.front() == '-') {
        isNegative = true;
        s = s.substr(1);
    } else if (s.back() == '-') {
        isNegative = true;
        s.pop_back();
    }

    std::string lower = toLowerAscii(s);
    if (lower.find(" dr") != std::string::npos || lower.find("debit") != std::string::npos) {
        isNegative = true;
    }

    // 2. Check suffix multipliers
    double multiplier = 1.0;
    if (lower.size() >= 2 && lower.back() == 'k' && (std::isdigit(static_cast<unsigned char>(lower[lower.size() - 2])) || lower[lower.size() - 2] == '.' || lower[lower.size() - 2] == ',')) {
        multiplier = 1000.0;
        s.pop_back();
    } else if (lower.size() >= 2 && lower.back() == 'm' && (std::isdigit(static_cast<unsigned char>(lower[lower.size() - 2])) || lower[lower.size() - 2] == '.' || lower[lower.size() - 2] == ',')) {
        multiplier = 1000000.0;
        s.pop_back();
    } else if (lower.size() >= 2 && lower.back() == 'b' && (std::isdigit(static_cast<unsigned char>(lower[lower.size() - 2])) || lower[lower.size() - 2] == '.' || lower[lower.size() - 2] == ',')) {
        multiplier = 1000000000.0;
        s.pop_back();
    } else if (lower.find("lakh") != std::string::npos || lower.find("lac") != std::string::npos) {
        multiplier = 100000.0;
    } else if (lower.find("crore") != std::string::npos || lower.find("cr") != std::string::npos) {
        multiplier = 10000000.0;
    }

    // Strip trailing Indian '/-' notation
    while (s.size() >= 2 && s.substr(s.size() - 2) == "/-") {
        s = s.substr(0, s.size() - 2);
    }

    // 3. Strip currency words and symbols
    std::string filtered;
    filtered.reserve(s.size());

    for (size_t i = 0; i < s.size(); ) {
        unsigned char c = static_cast<unsigned char>(s[i]);

        // UTF-8 ₹ (E2 82 B9)
        if (c == 0xE2 && i + 2 < s.size() &&
            static_cast<unsigned char>(s[i + 1]) == 0x82 &&
            static_cast<unsigned char>(s[i + 2]) == 0xB9) {
            i += 3; continue;
        }
        // UTF-8 € (E2 82 AC)
        if (c == 0xE2 && i + 2 < s.size() &&
            static_cast<unsigned char>(s[i + 1]) == 0x82 &&
            static_cast<unsigned char>(s[i + 2]) == 0xAC) {
            i += 3; continue;
        }

        // ASCII / Latin currency symbols
        if (c == '$' || c == 0xA3 /*£*/ || c == 0xA2 /*¢*/ || c == 0xA5 /*¥*/ || c == 0xC2) {
            i++; continue;
        }

        if (std::isdigit(c) || c == '.' || c == ',') {
            filtered += s[i];
        }
        i++;
    }

    if (filtered.empty()) return "";

    // 4. Decimal vs Thousand separator detection (EU vs US)
    size_t lastDot = filtered.rfind('.');
    size_t lastComma = filtered.rfind(',');

    std::string standardized;

    if (lastDot != std::string::npos && lastComma != std::string::npos) {
        if (lastComma > lastDot) {
            // EU format: 1.234,56 -> remove dots, replace comma with dot
            for (char c : filtered) {
                if (c == '.') continue;
                if (c == ',') standardized += '.';
                else standardized += c;
            }
        } else {
            // US format: 1,234.56 -> remove commas, keep dot
            for (char c : filtered) {
                if (c == ',') continue;
                else standardized += c;
            }
        }
    } else if (lastComma != std::string::npos) {
        // Only comma present
        // Check if comma looks like a decimal separator (1 or 2 digits after last comma)
        size_t digitsAfter = filtered.length() - 1 - lastComma;
        size_t commaCount = std::count(filtered.begin(), filtered.end(), ',');

        if (commaCount == 1 && (digitsAfter == 1 || digitsAfter == 2)) {
            // Decimal comma: 1234,50 -> 1234.50
            for (char c : filtered) {
                if (c == ',') standardized += '.';
                else standardized += c;
            }
        } else {
            // Thousand separator: 1,250 or 1,234,567 -> strip commas
            for (char c : filtered) {
                if (c != ',') standardized += c;
            }
        }
    } else if (lastDot != std::string::npos) {
        size_t dotCount = std::count(filtered.begin(), filtered.end(), '.');
        if (dotCount > 1) {
            // Multiple dots (EU thousands): 1.234.567 -> strip dots
            for (char c : filtered) {
                if (c != '.') standardized += c;
            }
        } else {
            standardized = filtered;
        }
    } else {
        standardized = filtered;
    }

    if (standardized.empty()) return "";

    // Parse double to apply multiplier
    double val = 0.0;
    try {
        val = std::stod(standardized);
    } catch (...) {
        return "";
    }

    val *= multiplier;
    if (isNegative) val = -std::abs(val);

    char buf[64];
    if (preserveDecimal && (val != std::floor(val) || multiplier != 1.0)) {
        snprintf(buf, sizeof(buf), "%.6g", val);
    } else {
        snprintf(buf, sizeof(buf), "%.0f", val);
    }

    return std::string(buf);
}

double ExtremeCleaningEngine::parseCurrencyValue(const std::string& rawCurrency) {
    if (rawCurrency.empty()) return 0.0;
    std::string clean = cleanNumericString(rawCurrency, true);
    if (clean.empty()) return 0.0;
    try {
        return std::stod(clean);
    } catch (...) {
        return 0.0;
    }
}

std::string ExtremeCleaningEngine::formatPhoneNumber(const std::string& rawPhone) {
    std::string digits;
    for (char c : rawPhone) {
        if (std::isdigit(static_cast<unsigned char>(c))) digits += c;
    }

    if (digits.length() == 10) {
        return "+91" + digits;
    } else if (digits.length() == 11 && digits[0] == '0') {
        return "+91" + digits.substr(1);
    } else if (digits.length() == 12 && digits.rfind("91", 0) == 0) {
        return "+" + digits;
    }
    return rawPhone;
}

void ExtremeCleaningEngine::capOutliersIQR(std::vector<double>& values, double multiplier) {
    if (values.size() < 4) return;

    std::vector<double> sorted = values;
    std::sort(sorted.begin(), sorted.end());

    size_t n = sorted.size();
    double q1 = sorted[n / 4];
    double q3 = sorted[(3 * n) / 4];
    double iqr = q3 - q1;

    double lowerBound = q1 - (multiplier * iqr);
    double upperBound = q3 + (multiplier * iqr);

    for (double& val : values) {
        if (val < lowerBound) val = lowerBound;
        else if (val > upperBound) val = upperBound;
    }
}

#include "date_cleaner.h"

namespace Filters {

std::string ExtremeCleaningEngine::standardizeDate(const std::string& rawDate) {
    if (rawDate.empty()) return "";
    return DateCleaner::getInstance().clean(rawDate, DateOutputFormat::ISO_YYYY_MM_DD);
}

} // namespace Filters
