/*
 * data_cleaner.cpp  —  Universal Data Cleaner Implementation
 *
 * ROUTING TABLE:
 *   PHONE    → phone_cleaner (normalize to +91XXXXXXXXXX)
 *   EMAIL    → lowercase + trim
 *   CURRENCY → extract numeric value (strip ₹, commas)
 *   DATE     → normalize to DD-MM-YYYY
 *   TEXT     → text_cleaner (trim, collapse spaces)
 *   BLANK    → return ""
 *   Others   → text_cleaner as fallback
 */
#include "data_cleaner.h"
#include "phone_cleaner.h"
#include "text_cleaner.h"
#include "../detector/data_detector.h"
#include <cctype>
#include <algorithm>

#include "email_cleaner.h"
#include "date_cleaner.h"
#include "mojibake_cleaner.h"

namespace Filters {

std::string DataCleaner::clean(const std::string& value, DataType type) const {
    if (value.empty()) return "";

    // Heal encoding & mojibake before any specialist cleaning
    std::string val = MojibakeCleaner::getInstance().clean(value);
    if (val.empty()) return "";

    switch (type) {
        case DataType::PHONE: {
            std::string res = PhoneCleaner::normalize(val);
            return res.empty() ? TextCleaner::clean(val) : res;
        }

        case DataType::EMAIL: {
            std::string res = EmailCleaner::clean(val);
            return res.empty() ? TextCleaner::clean(val) : res;
        }

        case DataType::DATE: {
            std::string res = DateCleaner::getInstance().clean(val, DateOutputFormat::ISO_YYYY_MM_DD);
            return res.empty() ? TextCleaner::clean(val) : res;
        }

        case DataType::CURRENCY:
        case DataType::NUMBER: {
            std::string res = ExtremeCleaningEngine::cleanNumericString(val, true);
            return res.empty() ? TextCleaner::clean(val) : res;
        }

        case DataType::BOOLEAN: {
            std::string s = TextCleaner::trim(val);
            std::transform(s.begin(), s.end(), s.begin(),
                           [](unsigned char c){ return std::toupper(c); });
            if (s == "TRUE" || s == "YES" || s == "1" || s == "Y" || s == "T" ||
                s == "PASS" || s == "ENABLED" || s == "ON" || s == "CHECKED") return "TRUE";
            if (s == "FALSE" || s == "NO" || s == "0" || s == "N" || s == "F" ||
                s == "FAIL" || s == "DISABLED" || s == "OFF" || s == "UNCHECKED") return "FALSE";
            return TextCleaner::clean(val);
        }

        case DataType::BLANK:
        case DataType::TEXT:
        default:
            return TextCleaner::clean(val); // NEVER erase non-empty cells
    }
}


std::string DataCleaner::autoClean(const std::string& value) const {
    if (value.empty()) return "";
    DataType type = DataDetector::getInstance().detect(value);
    return clean(value, type);
}

} // namespace Filters
