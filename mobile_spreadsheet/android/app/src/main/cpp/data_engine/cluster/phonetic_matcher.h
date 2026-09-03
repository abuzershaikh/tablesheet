/*
 * phonetic_matcher.h  —  Enterprise Phonetic Sound Matching Engine (Soundex & Metaphone)
 *
 * Folder: android/app/src/main/cpp/data_engine/cluster/
 *
 * PURPOSE:
 *   Matches names & words that sound the same but have completely different spelling.
 *
 * EXAMPLES:
 *   - Pooja vs Puja          → Phonetic Match (Code: PJ)
 *   - Gautam vs Gotam        → Phonetic Match (Code: KTM)
 *   - Smith vs Smyth         → Phonetic Match (Soundex: S530)
 *   - Choudhary vs Chowdhury → Phonetic Match (Code: XTR)
 */
#pragma once
#include <string>

namespace Filters {

class PhoneticMatcher {
public:
    static PhoneticMatcher& getInstance() {
        static PhoneticMatcher instance;
        return instance;
    }

    /// Computes standard 4-character American Soundex code (e.g. S530)
    std::string soundex(const std::string& input) const;

    /// Computes Metaphone phonetic pronunciation code
    std::string metaphone(const std::string& input) const;

    /// Checks if two strings are phonetically identical (Soundex OR Metaphone match)
    bool isPhoneticMatch(const std::string& a, const std::string& b) const;

    /// Returns hybrid similarity (0.0 to 1.0) combining Levenshtein and Phonetic matching
    float hybridSimilarity(const std::string& a, const std::string& b) const;

private:
    PhoneticMatcher() = default;
    static char getSoundexDigit(char c);
    static std::string cleanAlphaOnly(const std::string& s);
};

} // namespace Filters
