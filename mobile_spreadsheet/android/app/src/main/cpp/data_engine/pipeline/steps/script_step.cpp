#include "script_step.h"
#include "../../../js_engine.h"

namespace DataPipeline {

void ScriptStep::configure(const nlohmann::json& config) {
    if (config.contains("code")) {
        code = config["code"].get<std::string>();
    } else if (config.contains("script")) {
        code = config["script"].get<std::string>();
    } else {
        code = "";
    }
}

PipelineResult ScriptStep::execute(PipelineContext& ctx) {
    if (code.empty()) {
        return {ExecutionStatus::SUCCESS, 0, "No script code provided", -1};
    }
    
    std::string res = JsEngine::getInstance().evalScript(code);
    return {ExecutionStatus::SUCCESS, 0, "Script executed successfully: " + res, -1};
}

} // namespace DataPipeline
