#include "validation_engine.h"
#include <cctype>

namespace Filters {

// --- Basic Validation Rules ---

class NumberValidationRule : public IValidationRule {
public:
    ValidationResult validate(const std::string& val, DataType expectedType) const override {
        ValidationResult res;
        if (expectedType != DataType::NUMBER) return res;
        
        if (val.empty()) {
            res.status = ValidationStatus::WARNING;
            res.message = "Empty number";
            res.hasAutoFix = true;
            res.autoFixValue = "0";
            return res;
        }
        
        try {
            std::size_t pos;
            std::stod(val, &pos);
            if (pos != val.length()) {
                res.status = ValidationStatus::INVALID;
                res.message = "Contains non-numeric characters";
            }
        } catch (...) {
            res.status = ValidationStatus::INVALID;
            res.message = "Invalid number format";
        }
        return res;
    }
};

class PhoneValidationRule : public IValidationRule {
public:
    ValidationResult validate(const std::string& val, DataType expectedType) const override {
        ValidationResult res;
        if (expectedType != DataType::PHONE) return res;
        
        int digits = 0;
        for (char c : val) {
            if (std::isdigit(c)) digits++;
        }
        
        if (digits < 7) {
            res.status = ValidationStatus::INVALID;
            res.message = "Phone number too short";
        } else if (digits > 15) {
            res.status = ValidationStatus::INVALID;
            res.message = "Phone number too long";
        }
        
        // Auto fix example: remove spaces and dashes
        std::string cleaned;
        for (char c : val) {
            if (std::isdigit(c) || c == '+') {
                cleaned += c;
            }
        }
        if (cleaned != val && digits >= 7 && digits <= 15) {
            res.status = ValidationStatus::WARNING;
            res.message = "Contains formatting characters";
            res.hasAutoFix = true;
            res.autoFixValue = cleaned;
        }
        
        return res;
    }
};

// --- Engine Implementation ---

void ValidationEngine::addRule(std::shared_ptr<IValidationRule> rule) {
    if (rule) {
        rules.push_back(rule);
    }
}

void ValidationEngine::validateChunk(int column, DataType expectedType, bool applyAutoFix, DataPipeline::PipelineContext& ctx) {
    // Add default rules if empty
    if (rules.empty()) {
        addRule(std::make_shared<NumberValidationRule>());
        addRule(std::make_shared<PhoneValidationRule>());
    }

    int endRow = ctx.chunkStartIndex + ctx.chunkRowCount;
    if (endRow > ctx.totalRows) endRow = ctx.totalRows;
    
    for (int r = ctx.chunkStartIndex; r < endRow; ++r) {
        if (r < ctx.rowVisibility.size() && ctx.rowVisibility[r] == 0) continue;
        
        std::string val = ctx.getCellVal(r, column);
        
        for (const auto& rule : rules) {
            ValidationResult res = rule->validate(val, expectedType);
            
            if (res.status == ValidationStatus::INVALID) {
                // E.g., highlight the cell in red
                // Here we might append to a validation report in ctx.metadata
            } else if (res.status == ValidationStatus::WARNING && res.hasAutoFix && applyAutoFix) {
                // Apply the fix
                ctx.setCellVal(r, column, res.autoFixValue);
            }
        }
    }
}

} // namespace Filters
