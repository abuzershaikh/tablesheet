/*
 * email_cleaner.h — Enterprise-Grade Layered Email Cleaner & Normalizer (Phase 3)
 *
 * FOLDER CONTEXT:
 *   Lives in:     data_engine/cleaning/
 *   Used by:      data_engine/cleaning/data_cleaner.cpp
 *                 data_engine/validator/email_validator.cpp
 *                 data_engine/detector/plugins/email_plugin.cpp
 *                 ffi_bridge.cpp → native_autoCleanValue / native_analyzeEmail
 *
 * LAYERS:
 *   1. Garbage Extraction & Whitespace Cleaner (strips <>, !, leading/trailing punctuation)
 *   2. Syntax Parser & RFC Basic Check (local-part, domain, TLD rules)
 *   3. Provider Detector (Gmail, Yahoo, Microsoft, Apple, Disposable, Corporate)
 *   4. Provider-Specific Rules & Duplicate Normalizer (Gmail dot removal, + alias strip)
 */
#pragma once
#include <string>
#include <vector>

namespace Filters {

struct EmailMetadata {
    std::string originalEmail;
    std::string rawCleanedEmail;  ///< Clean email for sending (preserves alias/dots)
    std::string normalizedEmail;  ///< Canonical email for DB deduplication
    std::string localPart;
    std::string domain;
    std::string tld;
    std::string provider;         ///< "Gmail", "Yahoo", "Microsoft", "Apple", "Disposable", "Corporate/Other"
    
    bool isValid = false;
    bool hasPlusAlias = false;
    bool hasDots = false;
    bool isDisposable = false;
    
    int confidenceScore = 0;      ///< 0 to 100
    std::string validationMessage;
};

class EmailCleaner {
public:
    /**
     * Deeply analyzes raw input string, extracts email from garbage/punctuation,
     * applies provider-specific normalization (Gmail dot/plus rules), and returns EmailMetadata.
     */
    static EmailMetadata analyzeAndNormalize(const std::string& rawInput);

    /**
     * Returns rawCleanedEmail (usable for sending email, trimmed, lowercase, stripped garbage).
     */
    static std::string clean(const std::string& rawInput);

    /**
     * Returns normalizedEmail (usable for database unique constraint / duplicate detection).
     * Normalizes googlemail.com→gmail.com, strips Gmail dots, strips +aliases.
     */
    static std::string normalize(const std::string& rawInput);
};

} // namespace Filters
