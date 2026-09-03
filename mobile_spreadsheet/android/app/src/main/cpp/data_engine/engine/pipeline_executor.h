#ifndef PIPELINE_EXECUTOR_H
#define PIPELINE_EXECUTOR_H

#include <string>
#include <vector>
#include <memory>
#include "../pipeline/pipeline_step.h"

namespace DataPipeline {

class PipelineExecutor {
public:
    static PipelineExecutor& getInstance() {
        static PipelineExecutor instance;
        return instance;
    }

    // Execute a series of operations from a JSON pipeline definition
    PipelineResult executePipeline(PipelineContext& ctx, const std::string& pipelineJson);

private:
    PipelineExecutor() = default;
};

} // namespace DataPipeline

#endif // PIPELINE_EXECUTOR_H
