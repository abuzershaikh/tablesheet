/*
 * date_cleaner.cpp  —  Enterprise-Grade Multi-Format Date Parser & Cleaner Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "date_cleaner.h"
#include <cctype>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <cmath>

namespace Filters {

// Month short names for formatted output
static const char* const MONTH_NAMES_SHORT[] = {
    "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};

bool DateCleaner::isLeapYear(int y) {
    return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
}

int DateCleaner::daysInMonth(int m, int y) {
    static const int days[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    if (m < 1 || m > 12) return 0;
    if (m == 2 && isLeapYear(y)) return 29;
    return days[m];
}

int DateCleaner::expandTwoDigitYear(int yy) {
    if (yy >= 0 && yy <= 49) return 2000 + yy;
    if (yy >= 50 && yy <= 99) return 1900 + yy;
    return yy;
}

std::string DateCleaner::stripOrdinalSuffix(const std::string& str) {
    if (str.length() < 3) return str;
    std::string s = str;
    // Check for st, nd, rd, th at end of digits (e.g., 1st, 2nd, 3rd, 15th, 22nd)
    size_t len = s.length();
    std::string tail = s.substr(len - 2);
    std::transform(tail.begin(), tail.end(), tail.begin(), ::tolower);
    if (tail == "st" || tail == "nd" || tail == "rd" || tail == "th") {
        bool allDigitsBefore = true;
        for (size_t i = 0; i < len - 2; i++) {
            if (!std::isdigit(static_cast<unsigned char>(s[i]))) {
                allDigitsBefore = false;
                break;
            }
        }
        if (allDigitsBefore) {
            return s.substr(0, len - 2);
        }
    }
    return str;
}

int DateCleaner::monthNameToNumber(const std::string& monthName) {
    std::string m = monthName;
    std::transform(m.begin(), m.end(), m.begin(), ::tolower);

    // Strip punctuation
    while (!m.empty() && !std::isalpha(static_cast<unsigned char>(m.back()))) m.pop_back();

    if (m == "jan" || m == "january" || m == "jan." || m == "janu") return 1;
    if (m == "feb" || m == "february" || m == "feb." || m == "febr") return 2;
    if (m == "mar" || m == "march" || m == "mar.") return 3;
    if (m == "apr" || m == "april" || m == "apr.") return 4;
    if (m == "may") return 5;
    if (m == "jun" || m == "june" || m == "jun.") return 6;
    if (m == "jul" || m == "july" || m == "jul.") return 7;
    if (m == "aug" || m == "august" || m == "aug.") return 8;
    if (m == "sep" || m == "sept" || m == "september" || m == "sep.") return 9;
    if (m == "oct" || m == "october" || m == "oct.") return 10;
    if (m == "nov" || m == "november" || m == "nov.") return 11;
    if (m == "dec" || m == "december" || m == "dec.") return 12;
    return 0;
}

std::string ParsedDate::format(DateOutputFormat outFmt) const {
    if (!isValid) return original;

    char buf[64];
    switch (outFmt) {
        case DateOutputFormat::ISO_YYYY_MM_DD:
            snprintf(buf, sizeof(buf), "%04d-%02d-%02d", year, month, day);
            return buf;

        case DateOutputFormat::DD_MM_YYYY:
            snprintf(buf, sizeof(buf), "%02d-%02d-%04d", day, month, year);
            return buf;

        case DateOutputFormat::MM_DD_YYYY:
            snprintf(buf, sizeof(buf), "%02d/%02d/%04d", month, day, year);
            return buf;

        case DateOutputFormat::DD_MMM_YYYY: {
            const char* mName = (month >= 1 && month <= 12) ? MONTH_NAMES_SHORT[month] : "???";
            snprintf(buf, sizeof(buf), "%02d %s %04d", day, mName, year);
            return buf;
        }

        case DateOutputFormat::YYYY_MM_DD_SLASH:
            snprintf(buf, sizeof(buf), "%04d/%02d/%02d", year, month, day);
            return buf;
    }
    return original;
}

ParsedDate DateCleaner::parseExcelSerial(double serial, const std::string& rawDate) {
    ParsedDate res;
    res.original = rawDate;

    // Excel bug: 1900 is treated as leap year (day 60 = Feb 29, 1900)
    int nSerialDate = static_cast<int>(serial);
    if (nSerialDate < 1 || nSerialDate > 2958465) { // 01/01/1900 to 31/12/9999
        res.isValid = false;
        res.errorMessage = "Serial date out of supported range (1..2958465)";
        return res;
    }

    if (nSerialDate == 60) {
        res.day = 29; res.month = 2; res.year = 1900;
        res.isValid = true;
        res.formatDetected = "ExcelSerial";
        return res;
    } else if (nSerialDate < 60) {
        // Before false leap day
        nSerialDate++;
    }

    // Gregorian conversion
    int l = nSerialDate + 68569 + 2415019;
    int n = int((4 * l) / 146097);
    l = l - int((146097 * n + 3) / 4);
    int i = int((4000 * (l + 1)) / 1461001);
    l = l - int((1461 * i) / 4) + 31;
    int j = int((80 * l) / 2447);
    int d = l - int((2447 * j) / 80);
    l = int(j / 11);
    int m = j + 2 - (12 * l);
    int y = 100 * (n - 49) + i + l;

    res.day = d;
    res.month = m;
    res.year = y;
    res.isValid = (y >= 1900 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth(m, y));
    res.formatDetected = "ExcelSerial";
    return res;
}

DateFormatPreference DateCleaner::learnColumnDateFormat(const std::vector<std::string>& columnValues) const {
    int dmyVotes = 0;
    int mdyVotes = 0;
    int ymdVotes = 0;

    for (const auto& raw : columnValues) {
        if (raw.empty()) continue;
        std::string s = raw;
        while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(0, 1);
        while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();

        std::vector<std::string> tokens;
        std::string cur;
        for (char c : s) {
            if (c == '/' || c == '-' || c == '.' || c == ',' || std::isspace(static_cast<unsigned char>(c))) {
                if (!cur.empty()) { tokens.push_back(cur); cur.clear(); }
            } else {
                cur += c;
            }
        }
        if (!cur.empty()) tokens.push_back(cur);

        if (tokens.size() >= 3) {
            try {
                int p0 = std::stoi(stripOrdinalSuffix(tokens[0]));
                int p1 = std::stoi(stripOrdinalSuffix(tokens[1]));
                int p2 = std::stoi(stripOrdinalSuffix(tokens[2]));

                if (p0 > 31 || tokens[0].length() == 4) {
                    ymdVotes++;
                } else if (p2 > 31 || tokens[2].length() == 4 || tokens[2].length() == 2) {
                    if (p0 > 12 && p1 <= 12) {
                        dmyVotes += 2; // Strong unambiguous proof
                    } else if (p1 > 12 && p0 <= 12) {
                        mdyVotes += 2; // Strong unambiguous proof
                    }
                }
            } catch (...) {}
        }
    }

    if (mdyVotes > dmyVotes && mdyVotes > ymdVotes) return DateFormatPreference::PREFER_MDY;
    if (ymdVotes > dmyVotes && ymdVotes > mdyVotes) return DateFormatPreference::PREFER_YMD;
    if (dmyVotes > 0) return DateFormatPreference::PREFER_DMY;
    return DateFormatPreference::AUTO_DETECT;
}

ParsedDate DateCleaner::parseNumericDelimited(const std::vector<std::string>& tokens,
                                             const std::string& rawDate,
                                             DateFormatPreference pref) {
    ParsedDate res;
    res.original = rawDate;

    if (tokens.size() < 3) {
        res.isValid = false;
        res.errorMessage = "Fewer than 3 date tokens";
        return res;
    }

    std::vector<int> nums;
    for (size_t k = 0; k < 3; k++) {
        try {
            std::string s = stripOrdinalSuffix(tokens[k]);
            nums.push_back(std::stoi(s));
        } catch (...) {
            res.isValid = false;
            res.errorMessage = "Non-numeric token in date: " + tokens[k];
            return res;
        }
    }

    int p0 = nums[0], p1 = nums[1], p2 = nums[2];
    int y = 0, m = 0, d = 0;

    // Pattern 1: YYYY-MM-DD or YYYY/MM/DD
    if (p0 > 31 || tokens[0].length() == 4) {
        y = (p0 < 100) ? expandTwoDigitYear(p0) : p0;
        m = p1;
        d = p2;
        res.formatDetected = "YYYY-MM-DD";
    }
    // Pattern 2: DD-MM-YYYY or MM-DD-YYYY (where p2 is 4-digit or 2-digit year)
    else if (p2 > 31 || tokens[2].length() == 4 || (p2 >= 0 && tokens[2].length() == 2 && p0 <= 31 && p1 <= 12)) {
        y = (p2 < 100) ? expandTwoDigitYear(p2) : p2;

        if (p0 > 12 && p1 <= 12) {
            // Definitely DD-MM-YYYY (e.g. 25/05/2024)
            d = p0; m = p1;
            res.formatDetected = "DD-MM-YYYY";
        } else if (p1 > 12 && p0 <= 12) {
            // Definitely MM-DD-YYYY (e.g. 05/25/2024)
            m = p0; d = p1;
            res.formatDetected = "MM-DD-YYYY";
        } else {
            // Ambiguous (e.g. 05/06/2024) -> respect column consensus
            if (pref == DateFormatPreference::PREFER_MDY) {
                m = p0; d = p1;
                res.formatDetected = "MM-DD-YYYY (Resolved via Column Vote)";
            } else {
                d = p0; m = p1;
                res.formatDetected = "DD-MM-YYYY (Resolved via Column Vote/Default)";
            }
        }
    }
    // Pattern 3: YY-MM-DD (Short ISO)
    else if (p0 > 12 && p1 <= 12 && p2 <= 31) {
        y = expandTwoDigitYear(p0);
        m = p1;
        d = p2;
        res.formatDetected = "YY-MM-DD";
    } else {
        // Fallback default
        if (pref == DateFormatPreference::PREFER_MDY) {
            m = p0; d = p1; y = expandTwoDigitYear(p2);
            res.formatDetected = "MM-DD-YYYY";
        } else {
            d = p0; m = p1; y = expandTwoDigitYear(p2);
            res.formatDetected = "DD-MM-YYYY";
        }
    }

    if (m < 1 || m > 12) {
        res.isValid = false;
        res.errorMessage = "Month " + std::to_string(m) + " is invalid";
        return res;
    }

    int maxD = daysInMonth(m, y);
    if (d < 1 || d > maxD) {
        res.isValid = false;
        res.errorMessage = "Day " + std::to_string(d) + " is invalid for month " + std::to_string(m);
        return res;
    }

    if (y < 1900 || y > 2100) {
        res.isValid = false;
        res.errorMessage = "Year " + std::to_string(y) + " out of realistic range";
        return res;
    }

    res.day = d;
    res.month = m;
    res.year = y;
    res.isValid = true;
    return res;
}

ParsedDate DateCleaner::parseWithTextMonth(const std::vector<std::string>& tokens,
                                          const std::string& rawDate) {
    ParsedDate res;
    res.original = rawDate;

    int monthIdx = -1;
    int m = 0;

    for (size_t i = 0; i < tokens.size(); i++) {
        int monthNum = monthNameToNumber(tokens[i]);
        if (monthNum > 0) {
            monthIdx = static_cast<int>(i);
            m = monthNum;
            break;
        }
    }

    if (monthIdx == -1 || tokens.size() < 3) {
        res.isValid = false;
        res.errorMessage = "Text month not found or insufficient tokens";
        return res;
    }

    int d = 0, y = 0;

    if (monthIdx == 0) {
        // Format: Jan 15, 2024 or January 15 2024
        try {
            d = std::stoi(stripOrdinalSuffix(tokens[1]));
            y = std::stoi(tokens[2]);
            if (y < 100) y = expandTwoDigitYear(y);
            res.formatDetected = "MMM DD, YYYY";
        } catch (...) {
            res.isValid = false;
            return res;
        }
    } else if (monthIdx == 1) {
        // Format: 15 Jan 2024 or 15th January 2024 or 15-Jan-24
        try {
            d = std::stoi(stripOrdinalSuffix(tokens[0]));
            y = std::stoi(tokens[2]);
            if (y < 100) y = expandTwoDigitYear(y);
            res.formatDetected = "DD MMM YYYY";
        } catch (...) {
            res.isValid = false;
            return res;
        }
    } else if (monthIdx == 2 && tokens.size() >= 3) {
        // Format: 2024 Jan 15
        try {
            y = std::stoi(tokens[0]);
            if (y < 100) y = expandTwoDigitYear(y);
            d = std::stoi(stripOrdinalSuffix(tokens[1]));
            res.formatDetected = "YYYY MMM DD";
        } catch (...) {
            res.isValid = false;
            return res;
        }
    }

    if (d >= 1 && d <= daysInMonth(m, y) && y >= 1900 && y <= 2100) {
        res.day = d;
        res.month = m;
        res.year = y;
        res.isValid = true;
    } else {
        res.isValid = false;
        res.errorMessage = "Day or year validation failed";
    }

    return res;
}

ParsedDate DateCleaner::parseCompact(const std::string& digitsOnly,
                                    const std::string& rawDate,
                                    DateFormatPreference pref) {
    ParsedDate res;
    res.original = rawDate;

    if (digitsOnly.length() == 8) {
        // Could be YYYYMMDD (e.g. 20240512) or DDMMYYYY (e.g. 12052024) or MMDDYYYY (e.g. 05122024)
        int first4 = std::stoi(digitsOnly.substr(0, 4));
        int last4 = std::stoi(digitsOnly.substr(4, 4));

        if (first4 >= 1900 && first4 <= 2100) {
            // YYYYMMDD
            int y = first4;
            int m = std::stoi(digitsOnly.substr(4, 2));
            int d = std::stoi(digitsOnly.substr(6, 2));
            if (m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth(m, y)) {
                res.day = d; res.month = m; res.year = y;
                res.isValid = true;
                res.formatDetected = "YYYYMMDD";
                return res;
            }
        }
        if (last4 >= 1900 && last4 <= 2100) {
            int y = last4;
            int p0 = std::stoi(digitsOnly.substr(0, 2));
            int p1 = std::stoi(digitsOnly.substr(2, 2));

            if (p0 > 12 && p1 <= 12) {
                // DDMMYYYY
                int d = p0; int m = p1;
                if (d >= 1 && d <= daysInMonth(m, y)) {
                    res.day = d; res.month = m; res.year = y;
                    res.isValid = true;
                    res.formatDetected = "DDMMYYYY";
                    return res;
                }
            } else if (p1 > 12 && p0 <= 12) {
                // MMDDYYYY
                int m = p0; int d = p1;
                if (d >= 1 && d <= daysInMonth(m, y)) {
                    res.day = d; res.month = m; res.year = y;
                    res.isValid = true;
                    res.formatDetected = "MMDDYYYY";
                    return res;
                }
            } else {
                int d = (pref == DateFormatPreference::PREFER_MDY) ? p1 : p0;
                int m = (pref == DateFormatPreference::PREFER_MDY) ? p0 : p1;
                if (m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth(m, y)) {
                    res.day = d; res.month = m; res.year = y;
                    res.isValid = true;
                    res.formatDetected = (pref == DateFormatPreference::PREFER_MDY) ? "MMDDYYYY" : "DDMMYYYY";
                    return res;
                }
            }
        }
    } else if (digitsOnly.length() == 6) {
        // Could be YYMMDD or DDMMYY
        int p0 = std::stoi(digitsOnly.substr(0, 2));
        int p1 = std::stoi(digitsOnly.substr(2, 2));
        int p2 = std::stoi(digitsOnly.substr(4, 2));

        // Try DDMMYY or MMDDYY
        int y = expandTwoDigitYear(p2);
        int d = (pref == DateFormatPreference::PREFER_MDY) ? p1 : p0;
        int m = (pref == DateFormatPreference::PREFER_MDY) ? p0 : p1;
        if (m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth(m, y)) {
            res.day = d; res.month = m; res.year = y;
            res.isValid = true;
            res.formatDetected = "DDMMYY";
            return res;
        }
    }

    res.isValid = false;
    res.errorMessage = "Compact date parse failed";
    return res;
}

ParsedDate DateCleaner::parse(const std::string& rawDate, DateFormatPreference pref) const {
    ParsedDate res;
    res.original = rawDate;

    if (rawDate.empty()) {
        res.errorMessage = "Empty string";
        return res;
    }

    // Clean whitespace
    std::string s = rawDate;
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(0, 1);
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();

    if (s.empty()) return res;

    bool allNumeric = true;
    for (char c : s) {
        if (!std::isdigit(static_cast<unsigned char>(c))) {
            allNumeric = false;
            break;
        }
    }

    // Check for compact digits (e.g. 20240512 or 12052024)
    if (allNumeric && (s.length() == 8 || s.length() == 6)) {
        ParsedDate compactRes = parseCompact(s, rawDate, pref);
        if (compactRes.isValid) return compactRes;
    }

    // Strip ISO time part if present (e.g. "2024-05-12T14:30:00Z" or "2024-05-12 14:30:00")
    std::string datePartOnly = s;
    size_t tPos = s.find('T');
    if (tPos != std::string::npos && tPos >= 8) {
        datePartOnly = s.substr(0, tPos);
    } else {
        size_t spacePos = s.find(' ');
        if (spacePos != std::string::npos) {
            // Check if what follows is a time like "14:30" or "10:15:00"
            size_t colonPos = s.find(':', spacePos);
            if (colonPos != std::string::npos) {
                datePartOnly = s.substr(0, spacePos);
            }
        }
    }

    // Tokenize by delimiters: / - . , space
    std::vector<std::string> tokens;
    std::string cur;
    for (char c : datePartOnly) {
        if (c == '/' || c == '-' || c == '.' || c == ',' || std::isspace(static_cast<unsigned char>(c))) {
            if (!cur.empty()) {
                tokens.push_back(cur);
                cur.clear();
            }
        } else {
            cur += c;
        }
    }
    if (!cur.empty()) tokens.push_back(cur);

    if (tokens.empty()) {
        res.errorMessage = "No tokens extracted";
        return res;
    }

    // Check if any token is a text month
    bool hasTextMonth = false;
    for (const auto& tok : tokens) {
        if (monthNameToNumber(tok) > 0) {
            hasTextMonth = true;
            break;
        }
    }

    if (hasTextMonth) {
        return parseWithTextMonth(tokens, rawDate);
    }

    if (tokens.size() >= 3) {
        return parseNumericDelimited(tokens, rawDate, pref);
    }

    res.errorMessage = "Could not match known date format";
    return res;
}

std::string DateCleaner::clean(const std::string& rawDate, DateOutputFormat targetFormat, DateFormatPreference pref) const {
    ParsedDate parsed = parse(rawDate, pref);
    if (!parsed.isValid) return rawDate;
    return parsed.format(targetFormat);
}

std::vector<std::string> DateCleaner::cleanColumn(const std::vector<std::string>& columnValues,
                                                 DateOutputFormat targetFormat) const {
    DateFormatPreference learnedPref = learnColumnDateFormat(columnValues);
    std::vector<std::string> result;
    result.reserve(columnValues.size());
    for (const auto& val : columnValues) {
        result.push_back(clean(val, targetFormat, learnedPref));
    }
    return result;
}

std::string DateCleaner::normalizeToDDMMYYYY(const std::string& rawDate) const {
    return clean(rawDate, DateOutputFormat::DD_MM_YYYY);
}

bool DateCleaner::isValidDate(const std::string& rawDate) const {
    return parse(rawDate).isValid;
}

} // namespace Filters
