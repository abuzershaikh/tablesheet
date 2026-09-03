#include "name_from_email_cleaner.h"
#include <algorithm>
#include <cctype>
#include <unordered_set>
#include <vector>

namespace Filters {

static const std::unordered_set<std::string> BOT_PREFIXES = {
    "info", "information", "support", "admin", "administrator", "contact", "contactus",
    "sales", "billing", "help", "helpdesk", "office", "hr", "marketing", "team",
    "no-reply", "noreply", "test", "testing", "service", "services", "account", "accounts",
    "inquiry", "inquiries", "feedback", "mail", "query", "general", "careers", "jobs",
    "press", "media", "security", "privacy", "legal", "compliance", "ops", "operations",
    "dev", "developer", "developers", "postmaster", "hostmaster", "webmaster", "customer",
    "customerservice", "client", "clients", "order", "orders", "invoice", "invoices",
    "donotreply", "system", "auto", "notification", "notifications", "alerts", "alert"
};

std::string NameFromEmailCleaner::toTitleCase(const std::string& s) {
    if (s.empty()) return "";
    std::string res = s;
    for (size_t i = 0; i < res.length(); i++) {
        if (i == 0 || !std::isalpha(static_cast<unsigned char>(res[i - 1]))) {
            res[i] = std::toupper(static_cast<unsigned char>(res[i]));
        } else {
            res[i] = std::tolower(static_cast<unsigned char>(res[i]));
        }
    }
    return res;
}

bool NameFromEmailCleaner::isGenericBotOrDepartment(const std::string& localPart) {
    std::string lower = localPart;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

    // Exact match
    if (BOT_PREFIXES.find(lower) != BOT_PREFIXES.end()) return true;

    // Check with prefixes/suffixes stripped of trailing numbers
    std::string alphaOnly;
    for (char c : lower) {
        if (std::isalpha(static_cast<unsigned char>(c))) alphaOnly += c;
    }
    if (BOT_PREFIXES.find(alphaOnly) != BOT_PREFIXES.end()) return true;

    // Check delimited sub-tokens (e.g. "support.india" or "hr_team")
    std::string cur;
    for (char c : lower) {
        if (c == '.' || c == '_' || c == '-' || c == '+') {
            if (!cur.empty() && BOT_PREFIXES.find(cur) != BOT_PREFIXES.end()) return true;
            cur.clear();
        } else {
            cur += c;
        }
    }
    if (!cur.empty() && BOT_PREFIXES.find(cur) != BOT_PREFIXES.end()) return true;

    return false;
}

bool NameFromEmailCleaner::isFuzzyOrRandomHash(const std::string& localPart) {
    if (localPart.length() < 3) return true;

    int digitCount = 0;
    int alphaCount = 0;
    int vowelCount = 0;

    for (char c : localPart) {
        unsigned char uc = static_cast<unsigned char>(c);
        if (std::isdigit(uc)) {
            digitCount++;
        } else if (std::isalpha(uc)) {
            alphaCount++;
            char l = std::tolower(uc);
            if (l == 'a' || l == 'e' || l == 'i' || l == 'o' || l == 'u' || l == 'y') {
                vowelCount++;
            }
        }
    }

    // Dismiss if no alphabetic characters
    if (alphaCount == 0) return true;

    // Dismiss if excessive digits (> 35% of string is numbers)
    float digitRatio = static_cast<float>(digitCount) / static_cast<float>(localPart.length());
    if (digitRatio > 0.35f && digitCount >= 4) return true;

    // Dismiss if no vowels exist in alphabetic characters (e.g. "xkjdfhg" or "bczx")
    if (vowelCount == 0 && alphaCount >= 3) return true;

    return false;
}

ExtractedNameResult NameFromEmailCleaner::extractName(const std::string& rawEmail) {
    ExtractedNameResult res;
    res.originalEmail = rawEmail;
    res.isValidHumanName = false;
    res.confidence = 0.0f;

    if (rawEmail.empty()) {
        res.dismissReason = "Empty email";
        return res;
    }

    // Extract local-part before '@'
    size_t atPos = rawEmail.find('@');
    if (atPos == std::string::npos || atPos == 0) {
        res.dismissReason = "No '@' symbol found or empty local-part";
        return res;
    }

    std::string local = rawEmail.substr(0, atPos);
    
    // Strip trailing plus alias (e.g. "karan.gupta+newsletter" -> "karan.gupta")
    size_t plusPos = local.find('+');
    if (plusPos != std::string::npos) {
        local = local.substr(0, plusPos);
    }

    res.localPart = local;

    // 1. Check if it's a generic bot or department mailbox
    if (isGenericBotOrDepartment(local)) {
        res.dismissReason = "Generic bot or department mailbox";
        return res;
    }

    // 2. Check if it's random hash or fuzzy garbage
    if (isFuzzyOrRandomHash(local)) {
        res.dismissReason = "Fuzzy, random alphanumeric hash or excessive numbers";
        return res;
    }

    // 3. Tokenize by delimiters: '.', '_', '-', and space
    std::vector<std::string> rawTokens;
    std::string cur;
    for (char c : local) {
        if (c == '.' || c == '_' || c == '-' || std::isspace(static_cast<unsigned char>(c))) {
            if (!cur.empty()) {
                rawTokens.push_back(cur);
                cur.clear();
            }
        } else {
            cur += c;
        }
    }
    if (!cur.empty()) rawTokens.push_back(cur);

    // 4. Clean tokens: strip digits from each token (e.g. "gupta55" -> "gupta")
    std::vector<std::string> cleanTokens;
    for (const auto& tok : rawTokens) {
        std::string alphaPart;
        for (char c : tok) {
            if (std::isalpha(static_cast<unsigned char>(c))) {
                alphaPart += c;
            }
        }
        // Keep token if length >= 2 or if it's a single initial with another token
        if (alphaPart.length() >= 2) {
            cleanTokens.push_back(toTitleCase(alphaPart));
        } else if (alphaPart.length() == 1 && rawTokens.size() >= 2) {
            cleanTokens.push_back(toTitleCase(alphaPart));
        }
    }

    // If no valid tokens extracted
    if (cleanTokens.empty()) {
        res.dismissReason = "No alphabetic name tokens extracted";
        return res;
    }

    // Dismiss if all tokens are single characters (e.g. "a.b")
    bool allSingle = true;
    for (const auto& t : cleanTokens) {
        if (t.length() > 1) { allSingle = false; break; }
    }
    if (allSingle) {
        res.dismissReason = "Only single-character initials, unable to form full name";
        return res;
    }

    // 5. Assemble First Name, Last Name, and Full Name
    if (cleanTokens.size() == 1) {
        res.firstName = cleanTokens[0];
        res.lastName = "";
        res.fullName = cleanTokens[0];
        res.confidence = 0.80f; // Single name has moderate confidence
    } else if (cleanTokens.size() == 2) {
        res.firstName = cleanTokens[0];
        res.lastName = cleanTokens[1];
        res.fullName = cleanTokens[0] + " " + cleanTokens[1];
        res.confidence = 0.95f; // First + Last has high confidence
    } else {
        // 3 or more tokens (e.g. "Mohd Ali Khan")
        res.firstName = cleanTokens[0];
        std::string remaining;
        for (size_t i = 1; i < cleanTokens.size(); i++) {
            if (i > 1) remaining += " ";
            remaining += cleanTokens[i];
        }
        res.lastName = remaining;
        res.fullName = cleanTokens[0] + " " + remaining;
        res.confidence = 0.92f;
    }

    res.isValidHumanName = true;
    return res;
}

} // namespace Filters
