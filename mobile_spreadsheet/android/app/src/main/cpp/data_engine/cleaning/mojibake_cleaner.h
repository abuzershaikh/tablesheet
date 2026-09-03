/*
 * mojibake_cleaner.h  —  Enterprise Mojibake & Encoding Corruption Auto-Healer (ftfy-style)
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 *
 * PURPOSE:
 *   Repairs corrupted character encodings caused by Windows-1252, ISO-8859-1,
 *   double-encoded UTF-8, stripped BOMs, and mixed byte sequences.
 *
 * EXAMPLES:
 *   "Â₹ 1,500"   → "₹ 1,500"
 *   "CafÃ©"      → "Café"
 *   "Itâ€™s"     → "It's"
 *   "NaÃ¯ve"     → "Naïve"
 *   "10Â°C"      → "10°C"
 *   "UberÂ®"     → "Uber®"
 */
#pragma once
#include <string>
#include <vector>
#include <utility>

namespace Filters {

class MojibakeCleaner {
public:
    static MojibakeCleaner& getInstance() {
        static MojibakeCleaner instance;
        return instance;
    }

    /// Auto-heals mojibake and encoding glitches from input text
    std::string clean(const std::string& input) const;

    /// Checks if a string contains known mojibake patterns
    bool hasMojibake(const std::string& input) const;

    /// Strips invisible unicode control characters (BOM, zero-width space, etc.)
    std::string stripInvisibleChars(const std::string& input) const;

private:
    MojibakeCleaner();
    std::vector<std::pair<std::string, std::string>> _replacementRules;

    void initRules();
    std::string applyReplacements(const std::string& text) const;
};

} // namespace Filters
