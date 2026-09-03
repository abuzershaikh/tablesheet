#include "semantic_detector.h"
#include <algorithm>
#include <cctype>

namespace Filters {

SemanticDetector::SemanticDetector() {
    initVocabulary();
}

void SemanticDetector::initVocabulary() {
    _vocabulary[SemanticCategory::PAYMENT_STATUS] = {"paid","pending","cancelled","refunded","failed","processing","complete","completed","due","overdue"};
    _vocabulary[SemanticCategory::ORDER_STATUS] = {"placed","confirmed","packed","shipped","delivered","returned","rejected","cancelled"};
    _vocabulary[SemanticCategory::GENDER] = {"male","female","m","f","other","unknown"};
    _vocabulary[SemanticCategory::YES_NO] = {"yes","no","na","n/a","true","false","y","n"};
    _vocabulary[SemanticCategory::MONTH_NAME] = {"jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec","january","february","march","april","june","july","august","september","october","november","december"};
    _vocabulary[SemanticCategory::DAY_NAME] = {"mon","tue","wed","thu","fri","sat","sun","monday","tuesday","wednesday","thursday","friday","saturday","sunday"};
    _vocabulary[SemanticCategory::BANK_NAME] = {"sbi","hdfc","icici","axis","kotak","pnb","bob","canara","union","idbi","yes bank"};
    _vocabulary[SemanticCategory::PAYMENT_MODE] = {"cash","upi","card","neft","rtgs","imps","cheque","online","netbanking","cod","wallet","paytm","gpay","phonepe"};
    _vocabulary[SemanticCategory::BLOOD_GROUP] = {"a+","a-","b+","b-","o+","o-","ab+","ab-"};
    _vocabulary[SemanticCategory::DEPARTMENT] = {"hr","finance","it","sales","marketing","operations","legal","admin","accounts","engineering","logistics"};
    _vocabulary[SemanticCategory::PRIORITY] = {"high","medium","low","critical","urgent","normal"};
    _vocabulary[SemanticCategory::RATING] = {"excellent","good","average","poor","bad","outstanding","satisfactory"};
    _vocabulary[SemanticCategory::FRUIT_CATEGORY] = {"apple","banana","mango","orange","grape","papaya","guava","pineapple","watermelon","strawberry"};
}

std::string SemanticDetector::categoryToName(SemanticCategory cat) {
    switch(cat) {
        case SemanticCategory::PAYMENT_STATUS: return "Payment Status";
        case SemanticCategory::ORDER_STATUS: return "Order Status";
        case SemanticCategory::GENDER: return "Gender";
        case SemanticCategory::YES_NO: return "Yes/No";
        case SemanticCategory::MONTH_NAME: return "Month Name";
        case SemanticCategory::DAY_NAME: return "Day Name";
        case SemanticCategory::BANK_NAME: return "Bank Name";
        case SemanticCategory::PAYMENT_MODE: return "Payment Mode";
        case SemanticCategory::BLOOD_GROUP: return "Blood Group";
        case SemanticCategory::DEPARTMENT: return "Department";
        case SemanticCategory::PRIORITY: return "Priority";
        case SemanticCategory::RATING: return "Rating";
        case SemanticCategory::FRUIT_CATEGORY: return "Fruit";
        default: return "Unknown";
    }
}

std::string SemanticDetector::categoryToTag(SemanticCategory cat) {
    return categoryToName(cat);
}

static std::string toLower(const std::string& s) {
    std::string res = s;
    std::transform(res.begin(), res.end(), res.begin(), ::tolower);
    return res;
}

float SemanticDetector::computeOverlap(const std::vector<std::string>& values,
                                       const std::set<std::string>& vocab,
                                       std::vector<std::string>& matched,
                                       std::vector<std::string>& unmatched) const {
    if (values.empty()) return 0.0f;
    matched.clear();
    unmatched.clear();
    
    int matchCount = 0;
    for (const auto& v : values) {
        std::string lowerV = toLower(v);
        if (vocab.count(lowerV)) {
            matchCount++;
            matched.push_back(v);
        } else {
            unmatched.push_back(v);
        }
    }
    return (float)matchCount / values.size();
}

SemanticResult SemanticDetector::detect(const std::vector<std::string>& uniqueValues,
                                        const std::string& headerHint) const {
    SemanticResult bestResult;
    bestResult.category = SemanticCategory::UNKNOWN;
    bestResult.confidence = 0.0f;
    
    if (uniqueValues.empty()) return bestResult;

    for (const auto& kv : _vocabulary) {
        std::vector<std::string> matched, unmatched;
        float score = computeOverlap(uniqueValues, kv.second, matched, unmatched);
        if (score > bestResult.confidence) {
            bestResult.confidence = score;
            bestResult.category = kv.first;
            bestResult.matchedValues = matched;
            bestResult.unmatchedValues = unmatched;
        }
    }

    if (bestResult.confidence >= 0.5f) {
        bestResult.categoryName = categoryToName(bestResult.category);
        bestResult.reason = std::to_string(bestResult.matchedValues.size()) + "/" + std::to_string(uniqueValues.size()) + " values match";
    } else {
        bestResult.category = SemanticCategory::UNKNOWN;
        bestResult.confidence = 0.0f;
    }
    
    return bestResult;
}

} // namespace Filters
