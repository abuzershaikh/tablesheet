/*
 * date_cleaner.h  —  Enterprise-Grade Multi-Format Date Parser & Cleaner
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 *
 * FEATURES:
 *   1. 30+ Date Formats:
 *      - ISO 8601:        2024-05-12, 2024/05/12, 2024.05.12, 2024-05-12T14:30:00Z
 *      - DD/MM/YYYY:      12/05/2024, 12-05-2024, 12.05.2024
 *      - MM/DD/YYYY:      05/12/2024, 05-12-2024
 *      - Text Month:      15 Jan 2024, 15th January 2024, Jan 15, 2024, 15-Aug-2024
 *      - Short Year:      12/05/24, 24-05-12, 15-Jan-24
 *      - Compact:         20240512, 12052024
 *      - Excel Serial:    45424 (Excel serial date number)
 *      - Timestamps:      2024-05-12 14:30:00, 12/05/2024 10:15 AM
 *   2. Smart Heuristics:
 *      - Ordinal suffix stripper (1st, 2nd, 3rd, 4th, 15th, 22nd)
 *      - 2-digit year expansion (< 50 -> 20XX, >= 50 -> 19XX)
 *      - Leap year & days-in-month validation
 *      - Auto-resolves ambiguous D/M vs M/D using column context or global default
 *   3. Standardized Output Formats:
 *      - ISO_YYYY_MM_DD (2024-05-12)
 *      - DD_MM_YYYY     (12-05-2024)
 *      - MM_DD_YYYY     (05/12/2024)
 *      - DD_MMM_YYYY    (12 May 2024)
 */
#pragma once
#include <string>
#include <vector>

namespace Filters {

enum class DateOutputFormat {
    ISO_YYYY_MM_DD,     // 2024-05-12
    DD_MM_YYYY,         // 12-05-2024
    MM_DD_YYYY,         // 05/12/2024
    DD_MMM_YYYY,        // 12 May 2024
    YYYY_MM_DD_SLASH    // 2024/05/12
};

enum class DateFormatPreference {
    AUTO_DETECT, // Use column vote or local default
    PREFER_DMY,  // DD/MM/YYYY (Indian/European standard)
    PREFER_MDY,  // MM/DD/YYYY (US standard)
    PREFER_YMD   // YYYY/MM/DD (ISO standard)
};

struct ParsedDate {
    int day = 0;
    int month = 0;
    int year = 0;
    int hour = 0;
    int minute = 0;
    int second = 0;
    bool hasTime = false;
    bool isValid = false;
    std::string original = "";
    std::string formatDetected = "";
    std::string errorMessage = "";

    std::string format(DateOutputFormat outFmt = DateOutputFormat::ISO_YYYY_MM_DD) const;
};

class DateCleaner {
public:
    static DateCleaner& getInstance() {
        static DateCleaner instance;
        return instance;
    }

    /// Learn the prevailing date format (DD/MM vs MM/DD) across an entire column
    DateFormatPreference learnColumnDateFormat(const std::vector<std::string>& columnValues) const;

    /// Parse any messy date string into structured ParsedDate with optional preference
    ParsedDate parse(const std::string& rawDate, DateFormatPreference pref = DateFormatPreference::AUTO_DETECT) const;

    /// Clean and normalize any date string to standard format
    std::string clean(const std::string& rawDate,
                      DateOutputFormat targetFormat = DateOutputFormat::ISO_YYYY_MM_DD,
                      DateFormatPreference pref = DateFormatPreference::AUTO_DETECT) const;

    /// Clean entire column using collective column-level format consensus
    std::vector<std::string> cleanColumn(const std::vector<std::string>& columnValues,
                                         DateOutputFormat targetFormat = DateOutputFormat::ISO_YYYY_MM_DD) const;

    /// Alias for cleanColumn
    std::vector<std::string> cleanColumnConsensus(const std::vector<std::string>& columnValues,
                                                  DateOutputFormat targetFormat = DateOutputFormat::ISO_YYYY_MM_DD) const {
        return cleanColumn(columnValues, targetFormat);
    }

    /// Normalize with default DD-MM-YYYY (India / International standard)
    std::string normalizeToDDMMYYYY(const std::string& rawDate) const;

    /// Check if string is a valid parseable date
    bool isValidDate(const std::string& rawDate) const;

    /// Is leap year check
    static bool isLeapYear(int year);

    /// Days in given month for given year
    static int daysInMonth(int month, int year);

private:
    DateCleaner() = default;

    // Helper parsers
    static int monthNameToNumber(const std::string& monthName);
    static std::string stripOrdinalSuffix(const std::string& str);
    static ParsedDate parseNumericDelimited(const std::vector<std::string>& tokens,
                                           const std::string& rawDate,
                                           DateFormatPreference pref = DateFormatPreference::AUTO_DETECT);
    static ParsedDate parseWithTextMonth(const std::vector<std::string>& tokens,
                                        const std::string& rawDate);
    static ParsedDate parseCompact(const std::string& digitsOnly,
                                  const std::string& rawDate,
                                  DateFormatPreference pref = DateFormatPreference::AUTO_DETECT);
    static ParsedDate parseExcelSerial(double serial,
                                      const std::string& rawDate);
    static int expandTwoDigitYear(int yy);
};

} // namespace Filters
