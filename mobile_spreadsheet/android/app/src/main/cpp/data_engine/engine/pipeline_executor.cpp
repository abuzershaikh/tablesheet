#include "pipeline_executor.h"
#include "../pipeline/pipeline_registry.h"
#include "pipeline_validator.h"
#include "transaction_engine.h"
#include "../api/error_codes.h"
#include "../../json.hpp"
#include <iostream>

using json = nlohmann::json;

namespace DataPipeline {

PipelineResult PipelineExecutor::executePipeline(PipelineContext& ctx, const std::string& pipelineJson) {
    // 1. Validation
    PipelineResult valResult = PipelineValidator::validate(pipelineJson);
    if (!valResult.isSuccess()) {
        return valResult;
    }

    // 2. Transaction Start
    auto& txEngine = TransactionEngine::getInstance();
    txEngine.beginTransaction(ctx);

    try {
        auto j = json::parse(pipelineJson);
        
        // 3. Execution
        for (const auto& stepConfig : j["steps"]) {
            std::string type = stepConfig.value("type", "");
            if (type.empty()) {
                if (stepConfig.contains("action") && stepConfig["action"].is_string()) {
                    type = stepConfig["action"].get<std::string>();
                } else if (stepConfig.contains("script") || stepConfig.contains("code")) {
                    type = "script";
                }
            }
            
            auto step = PipelineRegistry::getInstance().createStep(type);
            
            if (step) {
                step->configure(stepConfig);
                PipelineResult stepResult = step->execute(ctx);
                
                if (!stepResult.isSuccess()) {
                    std::cerr << "Pipeline step failed: " << type << " - " << stepResult.message << std::endl;
                    txEngine.rollback(ctx);
                    return stepResult;
                }
            } else {
                std::cerr << "Pipeline WARNING: Unknown step type '" << type << "' — skipping (not registered in PipelineRegistry)" << std::endl;
            }
        }
        
        // 4. Commit on Success
        txEngine.commit();
        return {ExecutionStatus::SUCCESS, ErrorCodes::SUCCESS, "Pipeline executed successfully", -1};
        
    } catch (const std::exception& e) {
        txEngine.rollback(ctx);
        std::cerr << "Pipeline execution exception: " << e.what() << std::endl;
        return {ExecutionStatus::FATAL_ERROR, ErrorCodes::ERR_EXECUTION_EXCEPTION, std::string("Execution Exception: ") + e.what(), -1};
    }
}

} // namespace DataPipeline
