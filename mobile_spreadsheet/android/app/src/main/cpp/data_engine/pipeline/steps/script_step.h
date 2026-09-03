#pragma once
#include "../pipeline_registry.h"
#include <string>

namespace DataPipeline {

class ScriptStep : public IPipelineStep {
public:
    std::string getName() const override { return "Script"; }
    void configure(const nlohmann::json& config) override;
    PipelineResult execute(PipelineContext& ctx) override;
private:
    std::string code;
};

} // namespace DataPipeline
