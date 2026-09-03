#ifndef FILTER_STEP_H
#define FILTER_STEP_H

#include "../pipeline_step.h"
#include "../../rules/filter_rule.h"
#include <memory>

namespace DataPipeline {

class FilterStep : public IPipelineStep {
public:
    std::string getName() const override { return "Filter"; }
    
    PipelineResult execute(PipelineContext& ctx) override;
    
    void configure(const nlohmann::json& config) override;

private:
    std::shared_ptr<Filters::FilterRule> rule;
    int targetColumn = -1;
};

} // namespace DataPipeline

#endif // FILTER_STEP_H
