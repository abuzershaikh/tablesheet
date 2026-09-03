/*
 * phonetic_matcher.cpp  —  Enterprise Phonetic Sound Matching Engine Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cluster/
 */
#include "phonetic_matcher.h"
#include "levenshtein.h"
#include <cctype>
#include <algorithm>
#include <vector>

namespace Filters {

std::string PhoneticMatcher::cleanAlphaOnly(const std::string& s) {
    std::string res;
    for (char c : s) {
        if (std::isalpha(static_cast<unsigned char>(c))) {
            res += static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
        }
    }
    return res;
}

char PhoneticMatcher::getSoundexDigit(char c) {
    switch (c) {
        case 'B': case 'F': case 'P': case 'V':
            return '1';
        case 'C': case 'G': case 'J': case 'K': case 'Q': case 'S': case 'X': case 'Z':
            return '2';
        case 'D': case 'T':
            return '3';
        case 'L':
            return '4';
        case 'M': case 'N':
            return '5';
        case 'R':
            return '6';
        default:
            return '0'; // A, E, I, O, U, H, W, Y
    }
}

std::string PhoneticMatcher::soundex(const std::string& input) const {
    std::string s = cleanAlphaOnly(input);
    if (s.empty()) return "0000";

    std::string code;
    code += s[0]; // First letter preserved

    char lastDigit = getSoundexDigit(s[0]);

    for (size_t i = 1; i < s.size() && code.size() < 4; i++) {
        char d = getSoundexDigit(s[i]);
        if (d != '0' && d != lastDigit) {
            code += d;
            lastDigit = d;
        } else if (d == '0') {
            lastDigit = '0';
        }
    }

    while (code.size() < 4) {
        code += '0';
    }

    return code;
}

std::string PhoneticMatcher::metaphone(const std::string& input) const {
    std::string s = cleanAlphaOnly(input);
    if (s.empty()) return "";

    // Metaphone transform logic
    std::string meta = "";
    size_t len = s.length();

    // Drop silent initial letters (KN, GN, PN, AE, WR)
    size_t start = 0;
    if (len >= 2) {
        std::string p2 = s.substr(0, 2);
        if (p2 == "KN" || p2 == "GN" || p2 == "PN" || p2 == "AE" || p2 == "WR") {
            start = 1;
        }
    }

    // Initial 'X' -> 'S'
    if (start < len && s[start] == 'X') {
        meta += 'S';
        start++;
    }
    // Initial 'WH' -> 'W'
    else if (start + 1 < len && s[start] == 'W' && s[start + 1] == 'H') {
        meta += 'W';
        start += 2;
    }

    for (size_t i = start; i < len; i++) {
        char c = s[i];
        char next = (i + 1 < len) ? s[i + 1] : '\0';
        char prev = (i > 0) ? s[i - 1] : '\0';

        // Skip consecutive duplicate letters (except 'C')
        if (c == prev && c != 'C') continue;

        // Vowels are only kept at the beginning of the word
        if (c == 'A' || c == 'E' || c == 'I' || c == 'O' || c == 'U') {
            if (i == 0) meta += c;
            continue;
        }

        switch (c) {
            case 'B':
                // 'MB' at end of word -> 'B' is silent (e.g. thumb)
                if (i == len - 1 && prev == 'M') break;
                meta += 'B';
                break;

            case 'C':
                if (next == 'H') { meta += 'X'; i++; } // CH -> X
                else if (next == 'I' || next == 'E' || next == 'Y') { meta += 'S'; } // Soft C -> S
                else { meta += 'K'; } // Hard C -> K
                break;

            case 'D':
                if (next == 'G' && (i + 2 < len) && (s[i + 2] == 'E' || s[i + 2] == 'I' || s[i + 2] == 'Y')) {
                    meta += 'J'; i += 2; // DGE -> J
                } else {
                    meta += 'T';
                }
                break;

            case 'G':
                if (next == 'H' && i + 1 == len) break; // Silent GH at end
                if (next == 'N' && i + 1 == len - 1) break; // Silent GN at end
                if (next == 'I' || next == 'E' || next == 'Y') { meta += 'J'; } // Soft G -> J
                else { meta += 'K'; } // Hard G -> K
                break;

            case 'H':
                // H after vowel or before non-vowel is silent
                if (prev == 'A' || prev == 'E' || prev == 'I' || prev == 'O' || prev == 'U') {
                    if (next == 'A' || next == 'E' || next == 'I' || next == 'O' || next == 'U') {
                        meta += 'H';
                    }
                } else if (i == 0) {
                    meta += 'H';
                }
                break;

            case 'K':
                if (prev != 'C') meta += 'K';
                break;

            case 'P':
                if (next == 'H') { meta += 'F'; i++; } // PH -> F
                else { meta += 'P'; }
                break;

            case 'Q':
                meta += 'K';
                break;

            case 'S':
                if (next == 'H') { meta += 'X'; i++; } // SH -> X
                else if (next == 'I' && (i + 2 < len) && (s[i + 2] == 'O' || s[i + 2] == 'A')) {
                    meta += 'X'; i += 2; // SIO / SIA -> X
                } else {
                    meta += 'S';
                }
                break;

            case 'T':
                if (next == 'H') { meta += '0'; i++; } // TH -> 0
                else if (next == 'I' && (i + 2 < len) && (s[i + 2] == 'O' || s[i + 2] == 'A')) {
                    meta += 'X'; i += 2; // TIO / TIA -> X
                } else {
                    meta += 'T';
                }
                break;

            case 'V':
                meta += 'F';
                break;

            case 'W':
            case 'Y':
                if (next == 'A' || next == 'E' || next == 'I' || next == 'O' || next == 'U') {
                    meta += c;
                }
                break;

            case 'Z':
                meta += 'S';
                break;

            default:
                meta += c;
                break;
        }
    }

    return meta;
}

bool PhoneticMatcher::isPhoneticMatch(const std::string& a, const std::string& b) const {
    if (a.empty() || b.empty()) return false;
    if (a == b) return true;

    // Check Metaphone match
    std::string metaA = metaphone(a);
    std::string metaB = metaphone(b);
    if (!metaA.empty() && metaA == metaB) return true;

    // Check Soundex match
    std::string soundA = soundex(a);
    std::string soundB = soundex(b);
    if (!soundA.empty() && soundA != "0000" && soundA == soundB) return true;

    return false;
}

float PhoneticMatcher::hybridSimilarity(const std::string& a, const std::string& b) const {
    if (a == b) return 1.0f;
    if (a.empty() || b.empty()) return 0.0f;

    float levSim = levenshteinSimilarity(a, b);
    bool phonMatch = isPhoneticMatch(a, b);

    if (phonMatch) {
        // Boost similarity if pronunciation is identical
        return std::max(levSim, 0.90f);
    }

    return levSim;
}

} // namespace Filters
