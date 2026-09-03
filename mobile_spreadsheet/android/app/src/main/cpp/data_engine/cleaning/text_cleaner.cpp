/*
 * text_cleaner.cpp  —  Text Normalization Logic
 */
#include "text_cleaner.h"
#include <cctype>
#include <algorithm>
#include <sstream>

namespace Filters {

std::string TextCleaner::trim(const std::string& s) {
    if (s.empty()) return s;
    size_t start = 0;
    while (start < s.size() && std::isspace((unsigned char)s[start])) start++;
    if (start == s.size()) return "";
    size_t end = s.size() - 1;
    while (end > start && std::isspace((unsigned char)s[end])) end--;
    return s.substr(start, end - start + 1);
}

std::string TextCleaner::clean(const std::string& s) {
    if (s.empty()) return s;
    std::string result;
    bool lastWasSpace = false;
    for (char c : s) {
        // Remove control characters (ASCII 0-31 except \t treated as space)
        if ((unsigned char)c < 0x20 && c != '\t') continue;
        if (c == '\t') c = ' ';
        if (c == ' ') {
            if (!lastWasSpace && !result.empty()) {
                result += ' ';
                lastWasSpace = true;
            }
        } else {
            result += c;
            lastWasSpace = false;
        }
    }
    // Final trim
    while (!result.empty() && result.back() == ' ') result.pop_back();
    return result;
}

std::string TextCleaner::titleCase(const std::string& s) {
    std::string result = clean(s);
    bool capitalizeNext = true;
    for (size_t i = 0; i < result.size(); i++) {
        unsigned char uc = (unsigned char)result[i];
        if (std::isspace(uc)) {
            capitalizeNext = true;
        } else if (uc < 128) {
            if (capitalizeNext) {
                result[i] = (char)std::toupper(uc);
                capitalizeNext = false;
            } else {
                result[i] = (char)std::tolower(uc);
            }
        } else {
            // UTF-8 multi-byte character (like Arabic 'محمد' or Latin 'Zoë' / 'Müller')
            // Preserve multi-byte bytes intact without corruption
            capitalizeNext = false;
        }
    }
    return result;
}

std::string TextCleaner::lower(const std::string& s) {
    std::string r = s;
    for (size_t i = 0; i < r.size(); i++) {
        unsigned char uc = (unsigned char)r[i];
        if (uc < 128) r[i] = (char)std::tolower(uc);
    }
    return r;
}

std::string TextCleaner::upper(const std::string& s) {
    std::string r = s;
    for (size_t i = 0; i < r.size(); i++) {
        unsigned char uc = (unsigned char)r[i];
        if (uc < 128) r[i] = (char)std::toupper(uc);
    }
    return r;
}


} // namespace Filters
