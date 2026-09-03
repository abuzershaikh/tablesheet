#pragma once
#include <string>
#include <vector>
#include <map>
#include <set>

namespace Filters {

enum class SemanticCategory {
    UNKNOWN,
    PAYMENT_STATUS,    // Paid, Pending, Cancelled, Refunded
    ORDER_STATUS,      // Placed, Shipped, Delivered, Returned
    GENDER,            // Male, Female, Other
    YES_NO,            // Yes, No, NA
    MONTH_NAME,        // Jan, Feb, March...
    DAY_NAME,          // Mon, Tue, Wednesday...
    BANK_NAME,         // SBI, HDFC, ICICI...
    PAYMENT_MODE,      // Cash, UPI, Card, NEFT
    FRUIT_CATEGORY,    // Apple, Banana, Mango
    BLOOD_GROUP,       // A+, B-, O+, AB+
    DEPARTMENT,        // HR, Finance, IT, Marketing
    PRIORITY,          // High, Medium, Low
    RATING,            // Excellent, Good, Average, Poor
    COUNTRY_NAME,      // India, USA, UAE
    STATE_NAME,        // Maharashtra, Delhi...
    CUSTOM             // Learned from column header
};

struct SemanticResult {
    SemanticCategory category;
    std::string categoryName;   // "Payment Status"
    float confidence;           // 0.0-1.0
    std::string reason;         // "4/5 values match payment status vocabulary"
    std::vector<std::string> matchedValues;  // which values matched
    std::vector<std::string> unmatchedValues; // which didn't match
};

class SemanticDetector {
public:
    static SemanticDetector& getInstance() {
        static SemanticDetector inst;
        return inst;
    }

    /// Detect semantic category of a column's unique values
    SemanticResult detect(const std::vector<std::string>& uniqueValues,
                          const std::string& headerHint = "") const;

    /// Convert category enum to human-readable name
    static std::string categoryToName(SemanticCategory cat);
    static std::string categoryToTag(SemanticCategory cat); // for knowledge_tags

private:
    SemanticDetector();
    std::map<SemanticCategory, std::set<std::string>> _vocabulary; // category → known values
    void initVocabulary();
    float computeOverlap(const std::vector<std::string>& values,
                         const std::set<std::string>& vocab,
                         std::vector<std::string>& matched,
                         std::vector<std::string>& unmatched) const;
};

} // namespace Filters
