#include "repair_suggester.h"
#include <unordered_map>
#include <sstream>
#include <algorithm>
#include <cctype>

namespace PatternIntelligence {

static int parseNumberWord(const std::string& input) {
    static const std::unordered_map<std::string, int> units = {
        {"zero", 0}, {"one", 1}, {"two", 2}, {"three", 3}, {"four", 4},
        {"five", 5}, {"six", 6}, {"seven", 7}, {"eight", 8}, {"nine", 9},
        {"ten", 10}, {"eleven", 11}, {"twelve", 12}, {"thirteen", 13},
        {"fourteen", 14}, {"fifteen", 15}, {"sixteen", 16}, {"seventeen", 17},
        {"eighteen", 18}, {"nineteen", 19}
    };

    static const std::unordered_map<std::string, int> tens = {
        {"twenty", 20}, {"thirty", 30}, {"forty", 40}, {"fifty", 50},
        {"sixty", 60}, {"seventy", 70}, {"eighty", 80}, {"ninety", 90}
    };

    std::string s = input;
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
        return (c == '-') ? ' ' : std::tolower(c);
    });

    std::istringstream iss(s);
    std::string word;
    int total = 0;
    int current = 0;
    bool matchedAny = false;

    while (iss >> word) {
        auto itU = units.find(word);
        if (itU != units.end()) {
            current += itU->second;
            matchedAny = true;
            continue;
        }
        auto itT = tens.find(word);
        if (itT != tens.end()) {
            current += itT->second;
            matchedAny = true;
            continue;
        }
        if (word == "hundred") {
            current = (current == 0 ? 1 : current) * 100;
            matchedAny = true;
            continue;
        }
        if (word == "thousand") {
            total += (current == 0 ? 1 : current) * 1000;
            current = 0;
            matchedAny = true;
            continue;
        }
        if (word == "million") {
            total += (current == 0 ? 1 : current) * 1000000;
            current = 0;
            matchedAny = true;
            continue;
        }
        if (word == "and") continue;

        return -1; // Unrecognized word
    }

    return matchedAny ? (total + current) : -1;
}

std::vector<RepairSuggestion> RepairSuggester::suggestRepairs(
    const std::vector<std::string>& values,
    const std::vector<std::string>& cellRefs) {

    std::vector<RepairSuggestion> suggestions;
    size_t count = std::min(values.size(), cellRefs.size());

    // Check if column is predominantly numeric
    int numCount = 0;
    int filledCount = 0;
    for (const auto& v : values) {
        if (!v.empty()) {
            filledCount++;
            bool isNum = true;
            for (char c : v) {
                if (!std::isdigit(static_cast<unsigned char>(c)) && c != '.' && c != '-') {
                    isNum = false; break;
                }
            }
            if (isNum) numCount++;
        }
    }
    bool isNumericColumn = (filledCount > 0 && (float)numCount / filledCount >= 0.5f);

    for (size_t i = 0; i < count; ++i) {
        std::string val = values[i];
        if (val.empty()) continue;

        // 1. Convert written number words to digits if in a numeric column or exact word match
        int parsedNum = parseNumberWord(val);
        if (parsedNum >= 0 && (isNumericColumn || val.find(' ') == std::string::npos)) {
            RepairSuggestion r;
            r.cellRef = cellRefs[i];
            r.originalValue = val;
            r.suggestedValue = std::to_string(parsedNum);
            r.confidenceScore = 0.95;
            suggestions.push_back(r);
            continue;
        }

        // 2. Boolean normalization (y/n/t/f)
        std::string lower = val;
        std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c){ return std::tolower(c); });
        if (lower == "y" || lower == "t" || lower == "yes") {
            RepairSuggestion r;
            r.cellRef = cellRefs[i];
            r.originalValue = val;
            r.suggestedValue = "TRUE";
            r.confidenceScore = 0.90;
            suggestions.push_back(r);
            continue;
        } else if (lower == "n" || lower == "f" || lower == "no") {
            RepairSuggestion r;
            r.cellRef = cellRefs[i];
            r.originalValue = val;
            r.suggestedValue = "FALSE";
            r.confidenceScore = 0.90;
            suggestions.push_back(r);
            continue;
        }

        // 3. ALL CAPS to Title Case for text with multiple letters
        bool isAllUpper = true;
        int alphaCount = 0;
        for (char c : val) {
            if (std::isalpha(static_cast<unsigned char>(c))) {
                alphaCount++;
                if (!std::isupper(static_cast<unsigned char>(c))) {
                    isAllUpper = false;
                    break;
                }
            }
        }

        if (isAllUpper && alphaCount > 2 && val.length() > 2) {
            std::string repaired = val;
            bool capNext = true;
            for (size_t k = 0; k < repaired.size(); ++k) {
                if (std::isspace(static_cast<unsigned char>(repaired[k]))) {
                    capNext = true;
                } else if (capNext) {
                    repaired[k] = static_cast<char>(std::toupper(static_cast<unsigned char>(repaired[k])));
                    capNext = false;
                } else {
                    repaired[k] = static_cast<char>(std::tolower(static_cast<unsigned char>(repaired[k])));
                }
            }
            RepairSuggestion r;
            r.cellRef = cellRefs[i];
            r.originalValue = val;
            r.suggestedValue = repaired;
            r.confidenceScore = 0.85;
            suggestions.push_back(r);
        }
    }
    return suggestions;
}
} // namespace PatternIntelligence
