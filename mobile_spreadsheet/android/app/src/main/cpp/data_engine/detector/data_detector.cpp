#include "data_detector.h"
// Advanced detector plugins (see: data_engine/detector/plugins/)
#include "plugins/phone_plugin.h"
#include "plugins/currency_plugin.h"
#include "plugins/name_plugin.h"
#include "plugins/id_plugin.h"
#include "plugins/url_plugin.h"
#include "plugins/category_plugin.h"
#include "../cleaning/email_cleaner.h"
#include "../cleaning/date_cleaner.h"
#include <cctype>
#include <algorithm>

namespace Filters {

// --- Basic Plugin Implementations ---


class BooleanDetector : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override {
        std::string lower = val;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
        if (lower == "true" || lower == "false") return 1.0f;
        return 0.0f;
    }
    DataType getDataType() const override { return DataType::BOOLEAN; }
    std::string getName() const override { return "Boolean"; }
};

class PhoneDetector : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override {
        int digits = 0;
        int plus = 0;
        for (char c : val) {
            if (std::isdigit(c)) digits++;
            else if (c == '+') plus++;
            else if (!std::isspace(c) && c != '-' && c != '(' && c != ')') return 0.0f;
        }
        if (digits >= 7 && digits <= 15 && plus <= 1) return 0.9f;
        return 0.0f;
    }
    DataType getDataType() const override { return DataType::PHONE; }
    std::string getName() const override { return "Phone"; }
};

class EmailDetector : public IDataDetectorPlugin {

public:
    float detect(const std::string& val) const override {
        if (val.empty()) return 0.0f;
        EmailMetadata meta = EmailCleaner::analyzeAndNormalize(val);
        if (!meta.isValid) return 0.0f;
        return (float)meta.confidenceScore / 100.0f;
    }
    DataType getDataType() const override { return DataType::EMAIL; }
    std::string getName() const override { return "Email"; }
};


class NumberDetector : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override {
        try {
            std::size_t pos;
            std::stod(val, &pos);
            if (pos == val.length()) return 0.8f; 
        } catch (...) {}
        return 0.0f;
    }
    DataType getDataType() const override { return DataType::NUMBER; }
    std::string getName() const override { return "Number"; }
};

class DateDetector : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override {
        if (val.empty()) return 0.0f;
        ParsedDate parsed = DateCleaner::getInstance().parse(val);
        if (parsed.isValid) {
            // High confidence for well-formed dates
            return 0.95f;
        }
        return 0.0f;
    }
    DataType getDataType() const override { return DataType::DATE; }
    std::string getName() const override { return "Date"; }
};


// --- DataDetector Implementation ---

DataDetector::DataDetector() {
    // Priority order matters: higher-confidence plugins registered first.
    // Registration order:
    //   1. BooleanDetector  (exact match, confidence 1.0)
    //   2. IdPlugin         (PAN/GST/Aadhaar/IFSC exact match, confidence 1.0)
    //   3. EmailDetector    (@ + dot check, confidence 1.0)
    //   4. UrlPlugin        (http/www prefix, confidence 1.0)
    //   5. PhonePlugin      (digit count + format, confidence 0.97)
    //   6. CurrencyPlugin   (currency symbol + valid number, confidence 0.98)
    //   7. DateDetector     (slash/dash count heuristic, confidence 0.7)
    //   8. NumberDetector   (stod() parse, confidence 0.8)
    //   9. NamePlugin       (alpha word heuristic, confidence 0.80)
    //  10. CategoryPlugin   (short alpha label, confidence 0.45  — lowest priority)
    registerPlugin(std::make_shared<BooleanDetector>());
    registerPlugin(std::make_shared<IdPlugin>());
    registerPlugin(std::make_shared<EmailDetector>());
    registerPlugin(std::make_shared<UrlPlugin>());
    registerPlugin(std::make_shared<PhonePlugin>());
    registerPlugin(std::make_shared<CurrencyPlugin>());
    registerPlugin(std::make_shared<DateDetector>());
    registerPlugin(std::make_shared<NumberDetector>());
    registerPlugin(std::make_shared<NamePlugin>());
    registerPlugin(std::make_shared<CategoryPlugin>());
}

void DataDetector::registerPlugin(std::shared_ptr<IDataDetectorPlugin> plugin) {
    if (plugin) {
        plugins.push_back(plugin);
    }
}

DataType DataDetector::detect(const std::string& val) {
    if (val.empty()) return DataType::BLANK;
    if (val[0] == '=') return DataType::FORMULA;
    
    DataType bestType = DataType::TEXT;
    float maxConfidence = 0.0f;
    
    for (const auto& plugin : plugins) {
        float confidence = plugin->detect(val);
        if (confidence > maxConfidence) {
            maxConfidence = confidence;
            bestType = plugin->getDataType();
            if (confidence >= 1.0f) break; // Perfect match
        }
    }

    return bestType;
}

} // namespace Filters
