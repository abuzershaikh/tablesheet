#ifndef PIPELINE_VALIDATOR_H
#define PIPELINE_VALIDATOR_H

#include "../pipeline/pipeline_step.h"
#include <string>

namespace DataPipeline {

class PipelineValidator {
public:
    static PipelineResult validate(const std::string& pipelineJson);
};

} // namespace DataPipeline

#endif // PIPELINE_VALIDATOR_H
