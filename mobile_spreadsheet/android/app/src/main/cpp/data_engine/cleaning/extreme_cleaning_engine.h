/*
 * extreme_cleaning_engine.h — Extreme Kaggle & Data Science Master Cleaning Engine
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 * Integrates 30 Extreme Data Cleaning Tricks & Intelligence Plugins
 */
#pragma once
#include <string>
#include <vector>
#include <map>
#include <memory>

namespace Filters {

struct ExtractedEntity {
    std::string cleanName;
    std::string cleanEmail;
    std::string cleanPhone;
    std::string rawData;
    bool isValid;
};

class ExtremeCleaningEngine {
public:
    // Trick #1: Extract Concatenated Text-Email-Phone from dirty multi-field text
    static ExtractedEntity extractMixedCellData(const std::string& rawText);

    // Trick #2 & #3: Clean Unicode Text (preserves Arabic, Devanagari, Latin-Ext)
    static std::string sanitizeUnicodeText(const std::string& input);

    // Trick #4: Extract & Title Case Name from Email Username
    static std::string deriveNameFromEmail(const std::string& email);

    // Trick #6: Categorize Text against Multi-Industry Dictionaries
    static std::string detectIndustryCategory(const std::string& text);

    // Trick #9: Clean Currency & Multi-Symbol Numeric Strings (Locale-aware & Suffix-aware)
    static double parseCurrencyValue(const std::string& rawCurrency);
    static std::string cleanNumericString(const std::string& rawInput, bool preserveDecimal = true);

    // Trick #10: Normalize Indian (+91) & Global E.164 Phone Numbers
    static std::string formatPhoneNumber(const std::string& rawPhone);

    // Trick #11: IQR Outlier Capping
    static void capOutliersIQR(std::vector<double>& values, double multiplier = 1.5);

    // Trick #16: Multi-Format Date Standardizer to YYYY-MM-DD
    static std::string standardizeDate(const std::string& rawDate);
};

} // namespace Filters
