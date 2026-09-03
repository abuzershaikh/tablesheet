#pragma once
#include "../pipeline_registry.h"
#include <string>
#include <vector>

namespace DataPipeline {

class FillDataStep : public IPipelineStep {
public:
    std::string getName() const override { return "FillData"; }
    void configure(const nlohmann::json& config) override;
    PipelineResult execute(PipelineContext& ctx) override;
private:
    int startRow = 0;
    int startColumn = 0;
    std::vector<std::vector<std::string>> values;
};

} // namespace DataPipeline
