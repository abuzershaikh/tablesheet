/*
 * text_cleaner.h  —  General Text Normalizer
 *
 * FOLDER CONTEXT:
 *   Lives in:   data_engine/cleaning/
 *   Called by:  data_engine/cleaning/data_cleaner.cpp  (fallback for TEXT type)
 *   Also used:  data_engine/analyzer/column_analyzer.cpp
 *
 * OPERATIONS:
 *   trim()       - Remove leading/trailing whitespace
 *   clean()      - Trim + collapse multiple spaces + remove control chars
 *   titleCase()  - "john doe" → "John Doe"
 *   lower()      - "HELLO" → "hello"
 *   upper()      - "hello" → "HELLO"
 */
#pragma once
#include <string>

namespace Filters {

class TextCleaner {
public:
    static std::string trim(const std::string& s);
    static std::string clean(const std::string& s);      // trim + collapse spaces + strip ctrl chars
    static std::string titleCase(const std::string& s);  // Title Case Each Word
    static std::string lower(const std::string& s);
    static std::string upper(const std::string& s);
};

} // namespace Filters
