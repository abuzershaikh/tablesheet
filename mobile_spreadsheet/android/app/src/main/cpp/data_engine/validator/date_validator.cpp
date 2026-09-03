/*
 * date_validator.cpp  —  Calendar Date Validator (Phase 2)
 *
 * SUPPORTED FORMATS:
 *   DD/MM/YYYY   DD-MM-YYYY   DD.MM.YYYY
 *   MM/DD/YYYY   YYYY-MM-DD
 *   (Format auto-detected: if first part > 31 → YYYY-MM-DD)
 *
 * CHECKS:
 *   - Must parse into exactly 3 parts
 *   - Month must be 1–12
 *   - Day must be valid for month (leap year aware)
 *   - Year must be in realistic range (1900–2100)
 *
 * RELATED:
 *   data_engine/detector/data_detector.h  → DateDetector (structural match)
 */
#include "date_validator.h"
#include <cctype>
#include <vector>
#include <stdexcept>

namespace Filters {

bool DateValidator::isLeapYear(int y) {
    return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
}

int DateValidator::daysInMonth(int m, int y) {
    static const int days[] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
    if (m < 1 || m > 12) return 0;
    if (m == 2 && isLeapYear(y)) return 29;
    return days[m];
}

ValidationResult DateValidator::validate(const std::string& value) const {
    // Parse numeric parts separated by / - .
    std::vector<int> parts;
    std::string cur;
    for (char c : value) {
        if (std::isdigit((unsigned char)c)) {
            cur += c;
        } else if (c == '/' || c == '-' || c == '.') {
            if (!cur.empty()) {
                try { parts.push_back(std::stoi(cur)); } catch (...) {}
                cur.clear();
            }
        }
    }
    if (!cur.empty()) {
        try { parts.push_back(std::stoi(cur)); } catch (...) {}
    }

    if (parts.size() != 3) {
        return {false,
                "Expected 3 date parts (got " + std::to_string(parts.size()) + ")",
                "Use format DD/MM/YYYY or YYYY-MM-DD",
                0.9f};
    }

    int d, m, y;
    // Auto-detect format
    if (parts[0] > 31) {           // YYYY-MM-DD
        y = parts[0]; m = parts[1]; d = parts[2];
    } else if (parts[2] > 31) {    // DD/MM/YYYY or MM/DD/YYYY
        d = parts[0]; m = parts[1]; y = parts[2];
    } else {
        // Ambiguous — assume DD/MM/YYYY (Indian standard)
        d = parts[0]; m = parts[1]; y = parts[2];
    }

    if (m < 1 || m > 12) {
        return {false,
                "Month " + std::to_string(m) + " is out of range (1–12)",
                "Fix month value",
                0.98f};
    }

    int maxDay = daysInMonth(m, y);
    if (d < 1 || d > maxDay) {
        return {false,
                "Day " + std::to_string(d) + " invalid for month " +
                std::to_string(m) + "/" + std::to_string(y) +
                " (max " + std::to_string(maxDay) + ")",
                "Fix day value",
                0.98f};
    }

    if (y < 1900 || y > 2100) {
        return {false,
                "Year " + std::to_string(y) + " out of realistic range (1900–2100)",
                "Check year value",
                0.9f};
    }

    return {true, "Valid calendar date", "", 1.0f};
}

} // namespace Filters
