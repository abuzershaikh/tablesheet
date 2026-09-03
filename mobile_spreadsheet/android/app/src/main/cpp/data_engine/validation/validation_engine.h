#ifndef VALIDATION_ENGINE_H
#define VALIDATION_ENGINE_H

#include "../pipeline/pipeline_step.h"
#include "../cache/column_metadata.h"
#include <string>
#include <vector>

namespace Filters {

enum class ValidationStatus {
    VALID,
    INVALID,
    WARNING
};

struct ValidationResult {
    ValidationStatus status = ValidationStatus::VALID;
    std::string message;
    std::string autoFixValue;
    bool hasAutoFix = false;
};

class IValidationRule {
public:
    virtual ~IValidationRule() = default;
    
    // Returns the validation result for a given cell value
    virtual ValidationResult validate(const std::string& val, DataType expectedType) const = 0;
};

class ValidationEngine {
public:
    static ValidationEngine& getInstance() {
        static ValidationEngine instance;
        return instance;
    }
    
    // Validate an entire chunk and apply auto-fixes if requested
    void validateChunk(int column, DataType expectedType, bool applyAutoFix, DataPipeline::PipelineContext& ctx);

    void addRule(std::shared_ptr<IValidationRule> rule);

private:
    ValidationEngine() = default;
    
    std::vector<std::shared_ptr<IValidationRule>> rules;
};

} // namespace Filters

#endif // VALIDATION_ENGINE_H
