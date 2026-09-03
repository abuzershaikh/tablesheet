/*
 * mojibake_cleaner.cpp  —  Enterprise Mojibake & Encoding Corruption Auto-Healer Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "mojibake_cleaner.h"
#include <algorithm>

namespace Filters {

MojibakeCleaner::MojibakeCleaner() {
    initRules();
}

void MojibakeCleaner::initRules() {
    // 1. Currency Symbols (Corrupted multi-byte sequences)
    _replacementRules.push_back({"Â₹", "₹"});
    _replacementRules.push_back({"â‚¹", "₹"});
    _replacementRules.push_back({"â‚¬", "€"});
    _replacementRules.push_back({"Â€", "€"});
    _replacementRules.push_back({"Â£", "£"});
    _replacementRules.push_back({"Â¥", "¥"});
    _replacementRules.push_back({"Â$", "$"});

    // 2. Punctuation, Quotes & Dashes
    _replacementRules.push_back({"â€™", "'"});
    _replacementRules.push_back({"â€˜", "'"});
    _replacementRules.push_back({"â€œ", "\""});
    _replacementRules.push_back({"â€\x9d", "\""});
    _replacementRules.push_back({"â€ž", "\""});
    _replacementRules.push_back({"â€“", "–"}); // En-dash
    _replacementRules.push_back({"â€”", "—"}); // Em-dash
    _replacementRules.push_back({"â€¦", "..."}); // Ellipsis
    _replacementRules.push_back({"â€¢", "•"}); // Bullet
    _replacementRules.push_back({"â„¢", "™"}); // Trademark

    // 3. Common Symbols
    _replacementRules.push_back({"Â°", "°"}); // Degree
    _replacementRules.push_back({"Â©", "©"}); // Copyright
    _replacementRules.push_back({"Â®", "®"}); // Registered
    _replacementRules.push_back({"Â±", "±"}); // Plus-minus
    _replacementRules.push_back({"Âµ", "µ"}); // Micro
    _replacementRules.push_back({"Â¼", "¼"}); // One-quarter
    _replacementRules.push_back({"Â½", "½"}); // One-half
    _replacementRules.push_back({"Â¾", "¾"}); // Three-quarters
    _replacementRules.push_back({"Â§", "§"}); // Section sign
    _replacementRules.push_back({"Â¶", "¶"}); // Pilcrow / Paragraph

    // 4. Accented Lowercase Letters (Windows-1252 / ISO-8859-1 double-encoding)
    _replacementRules.push_back({"Ã©", "é"});
    _replacementRules.push_back({"Ã¨", "è"});
    _replacementRules.push_back({"Ãª", "ê"});
    _replacementRules.push_back({"Ã«", "ë"});
    _replacementRules.push_back({"Ã ", "à"});
    _replacementRules.push_back({"Ã¡", "á"});
    _replacementRules.push_back({"Ã¢", "â"});
    _replacementRules.push_back({"Ã£", "ã"});
    _replacementRules.push_back({"Ã¤", "ä"});
    _replacementRules.push_back({"Ã¥", "å"});
    _replacementRules.push_back({"Ã¦", "æ"});
    _replacementRules.push_back({"Ã§", "ç"});
    _replacementRules.push_back({"Ã¬", "ì"});
    _replacementRules.push_back({"Ã­", "í"});
    _replacementRules.push_back({"Ã®", "î"});
    _replacementRules.push_back({"Ã¯", "ï"});
    _replacementRules.push_back({"Ã±", "ñ"});
    _replacementRules.push_back({"Ã²", "ò"});
    _replacementRules.push_back({"Ã³", "ó"});
    _replacementRules.push_back({"Ã´", "ô"});
    _replacementRules.push_back({"Ãµ", "õ"});
    _replacementRules.push_back({"Ã¶", "ö"});
    _replacementRules.push_back({"Ã¸", "ø"});
    _replacementRules.push_back({"Ã¹", "ù"});
    _replacementRules.push_back({"Ãº", "ú"});
    _replacementRules.push_back({"Ã»", "û"});
    _replacementRules.push_back({"Ã¼", "ü"});
    _replacementRules.push_back({"Ã½", "ý"});
    _replacementRules.push_back({"Ã¿", "ÿ"});
    _replacementRules.push_back({"ÃŸ", "ß"});

    // 5. Accented Uppercase Letters
    _replacementRules.push_back({"Ã‰", "É"});
    _replacementRules.push_back({"Ãˆ", "È"});
    _replacementRules.push_back({"ÃŠ", "Ê"});
    _replacementRules.push_back({"Ã‹", "Ë"});
    _replacementRules.push_back({"Ã€", "À"});
    _replacementRules.push_back({"Ã\x81", "Á"});
    _replacementRules.push_back({"Ã‚", "Â"});
    _replacementRules.push_back({"Ãƒ", "Ã"});
    _replacementRules.push_back({"Ã„", "Ä"});
    _replacementRules.push_back({"Ã…", "Å"});
    _replacementRules.push_back({"Ã‡", "Ç"});
    _replacementRules.push_back({"ÃŒ", "Ì"});
    _replacementRules.push_back({"Ã\x8D", "Í"});
    _replacementRules.push_back({"ÃŽ", "Î"});
    _replacementRules.push_back({"Ã\x8F", "Ï"});
    _replacementRules.push_back({"Ã‘", "Ñ"});
    _replacementRules.push_back({"Ã’", "Ò"});
    _replacementRules.push_back({"Ã“", "Ó"});
    _replacementRules.push_back({"Ã”", "Ô"});
    _replacementRules.push_back({"Ã•", "Õ"});
    _replacementRules.push_back({"Ã–", "Ö"});
    _replacementRules.push_back({"Ã˜", "Ø"});
    _replacementRules.push_back({"Ã™", "Ù"});
    _replacementRules.push_back({"Ãš", "Ú"});
    _replacementRules.push_back({"Ã›", "Û"});
    _replacementRules.push_back({"Ãœ", "Ü"});
}

std::string MojibakeCleaner::applyReplacements(const std::string& text) const {
    std::string result = text;
    for (const auto& pair : _replacementRules) {
        const std::string& bad = pair.first;
        const std::string& good = pair.second;
        size_t pos = 0;
        while ((pos = result.find(bad, pos)) != std::string::npos) {
            result.replace(pos, bad.length(), good);
            pos += good.length();
        }
    }
    return result;
}

std::string MojibakeCleaner::stripInvisibleChars(const std::string& input) const {
    if (input.empty()) return input;

    std::string result;
    result.reserve(input.size());

    for (size_t i = 0; i < input.size(); ) {
        unsigned char c = static_cast<unsigned char>(input[i]);

        // Non-breaking space (0xC2 0xA0) → regular space ' '
        if (c == 0xC2 && i + 1 < input.size() && static_cast<unsigned char>(input[i + 1]) == 0xA0) {
            result += ' ';
            i += 2;
            continue;
        }

        // UTF-8 BOM (0xEF 0xBB 0xBF)
        if (c == 0xEF && i + 2 < input.size() &&
            static_cast<unsigned char>(input[i + 1]) == 0xBB &&
            static_cast<unsigned char>(input[i + 2]) == 0xBF) {
            i += 3;
            continue;
        }

        // Zero-width space (0xE2 0x80 0x8B)
        if (c == 0xE2 && i + 2 < input.size() &&
            static_cast<unsigned char>(input[i + 1]) == 0x80 &&
            static_cast<unsigned char>(input[i + 2]) == 0x8B) {
            i += 3;
            continue;
        }

        // Zero-width non-joiner (0xE2 0x80 0x8C) / joiner (0xE2 0x80 0x8D)
        if (c == 0xE2 && i + 2 < input.size() &&
            static_cast<unsigned char>(input[i + 1]) == 0x80 &&
            (static_cast<unsigned char>(input[i + 2]) == 0x8C || static_cast<unsigned char>(input[i + 2]) == 0x8D)) {
            i += 3;
            continue;
        }

        // Left-to-Right Mark / Right-to-Left Mark (0xE2 0x80 0x8E / 0x8F)
        if (c == 0xE2 && i + 2 < input.size() &&
            static_cast<unsigned char>(input[i + 1]) == 0x80 &&
            (static_cast<unsigned char>(input[i + 2]) == 0x8E || static_cast<unsigned char>(input[i + 2]) == 0x8F)) {
            i += 3;
            continue;
        }

        result += input[i];
        i++;
    }

    return result;
}

std::string MojibakeCleaner::clean(const std::string& input) const {
    if (input.empty()) return input;

    // Step 1: Strip zero-width & invisible junk
    std::string intermediate = stripInvisibleChars(input);

    // Step 2: Multi-pass mojibake healing (handles double and triple encodings)
    std::string healed = applyReplacements(intermediate);
    if (healed != intermediate) {
        // Second pass in case of cascaded corruptions
        healed = applyReplacements(healed);
    }

    return healed;
}

bool MojibakeCleaner::hasMojibake(const std::string& input) const {
    if (input.empty()) return false;
    for (const auto& pair : _replacementRules) {
        if (input.find(pair.first) != std::string::npos) return true;
    }
    return false;
}

} // namespace Filters
