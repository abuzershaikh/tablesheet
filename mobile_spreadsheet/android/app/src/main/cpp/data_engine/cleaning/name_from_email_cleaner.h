#pragma once
#include <string>
#include <vector>

namespace Filters {

struct ExtractedNameResult {
    std::string originalEmail;
    std::string localPart;
    std::string firstName;
    std::string lastName;
    std::string fullName;
    bool isValidHumanName = false;
    float confidence = 0.0f;
    std::string dismissReason;
};

class NameFromEmailCleaner {
public:
    static NameFromEmailCleaner& getInstance() {
        static NameFromEmailCleaner instance;
        return instance;
    }

    /**
     * Extracts a human first and last name from an email address.
     * Rejects generic bot, department, or high-entropy/random hash emails.
     */
    static ExtractedNameResult extractName(const std::string& rawEmail);

    /**
     * Checks if the local-part is a generic bot, department, or service mailbox.
     */
    static bool isGenericBotOrDepartment(const std::string& localPart);

    /**
     * Checks if the local-part is random alphanumeric hash, high entropy, or lacking vowels.
     */
    static bool isFuzzyOrRandomHash(const std::string& localPart);

    /**
     * Capitalizes each word into Title Case (e.g. "karan" -> "Karan").
     */
    static std::string toTitleCase(const std::string& s);

private:
    NameFromEmailCleaner() = default;
};

} // namespace Filters
