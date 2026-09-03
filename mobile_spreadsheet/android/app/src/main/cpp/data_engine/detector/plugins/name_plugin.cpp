/*
 * name_plugin.cpp  —  Human Name Detection Logic
 *
 * HEURISTICS:
 *   - Only letters, spaces, dots, apostrophes (for O'Brien etc.)
 *   - 1–4 words
 *   - Each word starts with uppercase or is all-uppercase
 *   - Length 3–60 characters
 *   - No digits
 */
#include "name_plugin.h"
#include <cctype>
#include <sstream>
#include <vector>

namespace Filters {

float NamePlugin::detect(const std::string& val) const {
    if (val.size() < 3 || val.size() > 60) return 0.0f;

    // Only allow letters (including UTF-8 accented), spaces, dots, apostrophes, hyphens
    for (char c : val) {
        unsigned char uc = (unsigned char)c;
        if (!std::isalpha(uc) && uc < 128 &&
            c != ' ' && c != '.' && c != '\'' && c != '-') {
            return 0.0f;
        }
    }

    // Split into words
    std::istringstream iss(val);
    std::string word;
    std::vector<std::string> words;
    while (iss >> word) words.push_back(word);

    if (words.empty() || words.size() > 5) return 0.0f;

    // Each word: must start with uppercase letter OR be all uppercase OR be UTF-8
    int nameWords = 0;
    for (const auto& w : words) {
        if (w.empty()) continue;
        unsigned char u0 = (unsigned char)w[0];
        if (std::isupper(u0) || u0 >= 128) nameWords++;
    }


    if (nameWords == (int)words.size() && words.size() >= 2) return 0.80f;
    if (nameWords >= 1 && words.size() >= 2) return 0.65f;
    if (words.size() == 1 && words[0].size() >= 3 && std::isupper((unsigned char)words[0][0])) return 0.40f;

    return 0.0f;
}

} // namespace Filters
