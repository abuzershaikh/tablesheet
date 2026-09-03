/*
 * email_cleaner.cpp  —  Enterprise-Grade Layered Email Cleaner & Normalizer (Phase 3)
 *
 * PIPELINE STAGES:
 *   Layer 1: Whitespace Cleaner & Garbage Stripper (extracts email from surrounding text/punctuation)
 *   Layer 2: Syntax Parser & Character Rules (local-part, domain, TLD)
 *   Layer 3: Provider Classification (Gmail, Yahoo, Microsoft, Apple, Disposable, Corporate)
 *   Layer 4: Provider-Specific Rules & Normalization (Gmail dot removal, + alias stripping)
 */
#include "email_cleaner.h"
#include <cctype>
#include <algorithm>
#include <unordered_set>

namespace Filters {

// Helper: check if character is valid in email local-part (standard unquoted)
static bool isValidLocalChar(char c) {
    unsigned char uc = (unsigned char)c;
    return std::isalnum(uc) || uc >= 128 || c == '.' || c == '_' || c == '%' || c == '+' || c == '-';
}


// Helper: check if character is valid in email domain
static bool isValidDomainChar(char c) {
    return std::isalnum((unsigned char)c) || c == '.' || c == '-';
}

// Helper: convert string to lowercase
static std::string toLowerStr(const std::string& s) {
    std::string res = s;
    std::transform(res.begin(), res.end(), res.begin(),
                   [](unsigned char c) { return std::tolower(c); });
    return res;
}

EmailMetadata EmailCleaner::analyzeAndNormalize(const std::string& rawInput) {
    EmailMetadata meta;
    meta.originalEmail = rawInput;
    meta.isValid = false;
    meta.confidenceScore = 0;

    if (rawInput.empty()) {
        meta.validationMessage = "Input is empty";
        return meta;
    }

    // ── LAYER 1: Whitespace & Garbage Extraction ─────────────────────────────
    // Find '@' in rawInput
    size_t atPos = rawInput.find('@');
    if (atPos == std::string::npos || atPos == 0 || atPos == rawInput.length() - 1) {
        meta.validationMessage = "Missing or misplaced '@' symbol";
        return meta;
    }

    // Ensure only one '@' is present
    if (rawInput.find('@', atPos + 1) != std::string::npos) {
        meta.validationMessage = "Multiple '@' symbols found";
        return meta;
    }

    // Scan backwards from '@' to find start of local-part (skip leading garbage like '<', '!', ':', ' ')
    size_t localStart = atPos;
    while (localStart > 0) {
        char prev = rawInput[localStart - 1];
        if (!isValidLocalChar(prev)) break;
        localStart--;
    }

    // Scan forwards from '@' to find end of domain (skip trailing garbage like '>', ')', ',', ';', ' ')
    size_t domainEnd = atPos + 1;
    while (domainEnd < rawInput.length()) {
        char next = rawInput[domainEnd];
        if (!isValidDomainChar(next)) break;
        domainEnd++;
    }

    std::string localPart = rawInput.substr(localStart, atPos - localStart);
    std::string domainPart = rawInput.substr(atPos + 1, domainEnd - (atPos + 1));

    // Strip leading prefix garbage & delimiters from local-part (e.g. "Sa..sara", "^^iY6Evve noah")
    size_t spacePos = localPart.find_last_of(" \t\n\r:;,<>()[]{}=*^!?#");
    if (spacePos != std::string::npos && spacePos < localPart.size() - 1) {
        localPart = localPart.substr(spacePos + 1);
    }
    while (!localPart.empty() && (localPart.front() == '.' || localPart.front() == '-' || localPart.front() == '_' || localPart.front() == '+' || localPart.front() == '=' || localPart.front() == ':')) {
        localPart.erase(0, 1);
    }

    localPart  = toLowerStr(localPart);
    domainPart = toLowerStr(domainPart);


    // ── LAYER 2: Syntax Parser & Basic Validation ─────────────────────────────
    if (localPart.empty()) {
        meta.validationMessage = "Empty username before '@'";
        return meta;
    }
    if (domainPart.empty()) {
        meta.validationMessage = "Empty domain after '@'";
        return meta;
    }

    // Local-part checks
    if (localPart.front() == '.' || localPart.back() == '.') {
        meta.validationMessage = "Local-part cannot start or end with a dot";
        return meta;
    }
    if (localPart.find("..") != std::string::npos) {
        meta.validationMessage = "Local-part cannot contain consecutive dots";
        return meta;
    }

    // Domain checks
    if (domainPart.front() == '.' || domainPart.back() == '.') {
        meta.validationMessage = "Domain cannot start or end with a dot";
        return meta;
    }
    if (domainPart.find("..") != std::string::npos) {
        meta.validationMessage = "Domain cannot contain consecutive dots";
        return meta;
    }
    size_t lastDot = domainPart.rfind('.');
    if (lastDot == std::string::npos) {
        meta.validationMessage = "Domain must contain a top-level domain (e.g. .com)";
        return meta;
    }

    std::string tld = domainPart.substr(lastDot + 1);
    if (tld.size() < 2) {
        meta.validationMessage = "TLD '" + tld + "' is too short (min 2 characters)";
        return meta;
    }
    for (char c : tld) {
        if (!std::isalpha((unsigned char)c)) {
            meta.validationMessage = "TLD must contain only alphabetic characters";
            return meta;
        }
    }

    meta.localPart = localPart;
    meta.domain    = domainPart;
    meta.tld       = tld;
    meta.hasDots      = (localPart.find('.') != std::string::npos);
    meta.hasPlusAlias = (localPart.find('+') != std::string::npos);

    // ── LAYER 3: Provider Classification ─────────────────────────────────────
    static const std::unordered_set<std::string> disposableDomains = {
        "mailinator.com", "tempmail.com", "10minutemail.com", "trashmail.com",
        "guerrillamail.com", "yopmail.com", "dispostable.com", "sharklasers.com",
        "getnada.com", "temp-mail.org", "throwawaymail.com", "maildrop.cc"
    };

    if (disposableDomains.count(domainPart)) {
        meta.provider = "Disposable";
        meta.isDisposable = true;
    } else if (domainPart == "gmail.com" || domainPart == "googlemail.com") {
        meta.provider = "Gmail";
    } else if (domainPart == "yahoo.com" || domainPart == "ymail.com" ||
               domainPart == "rocketmail.com" || domainPart.rfind("yahoo.", 0) == 0) {
        meta.provider = "Yahoo";
    } else if (domainPart == "outlook.com" || domainPart == "hotmail.com" ||
               domainPart == "live.com" || domainPart == "msn.com") {
        meta.provider = "Microsoft";
    } else if (domainPart == "icloud.com" || domainPart == "me.com" || domainPart == "mac.com") {
        meta.provider = "Apple";
    } else {
        meta.provider = "Corporate/Other";
    }

    // ── LAYER 4: Provider Rules & Duplicate Normalization ────────────────────
    std::string normLocal  = localPart;
    std::string normDomain = domainPart;

    if (meta.provider == "Gmail") {
        // Rule 1: Normalise googlemail.com to gmail.com
        normDomain = "gmail.com";

        // Rule 2: Remove +alias
        size_t plusPos = normLocal.find('+');
        if (plusPos != std::string::npos) {
            normLocal = normLocal.substr(0, plusPos);
        }

        // Rule 3: Remove dots (Google ignores dots in username)
        normLocal.erase(std::remove(normLocal.begin(), normLocal.end(), '.'), normLocal.end());

        meta.confidenceScore = 95;
    } else if (meta.provider == "Microsoft" || meta.provider == "Yahoo" || meta.provider == "Apple") {
        // Remove +alias
        size_t plusPos = normLocal.find('+');
        if (plusPos != std::string::npos) {
            normLocal = normLocal.substr(0, plusPos);
        }
        meta.confidenceScore = 90;
    } else if (meta.isDisposable) {
        meta.confidenceScore = 50;
    } else {
        meta.confidenceScore = 85;
    }

    if (normLocal.empty()) {
        meta.validationMessage = "Local-part is empty after stripping alias/formatting";
        return meta;
    }

    meta.isValid = true;
    meta.rawCleanedEmail = localPart + "@" + domainPart;
    meta.normalizedEmail = normLocal + "@" + normDomain;
    meta.validationMessage = "Valid " + meta.provider + " email address";

    return meta;
}

std::string EmailCleaner::clean(const std::string& rawInput) {
    EmailMetadata meta = analyzeAndNormalize(rawInput);
    if (!meta.isValid) return rawInput; // return original if invalid
    return meta.rawCleanedEmail;
}

std::string EmailCleaner::normalize(const std::string& rawInput) {
    EmailMetadata meta = analyzeAndNormalize(rawInput);
    if (!meta.isValid) return rawInput;
    return meta.normalizedEmail;
}

} // namespace Filters
