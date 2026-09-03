#ifndef PIPELINE_REGISTRY_H
#define PIPELINE_REGISTRY_H

#include "pipeline_step.h"
#include <string>
#include <unordered_map>
#include <memory>
#include <functional>
#include <mutex>

namespace DataPipeline {

class PipelineRegistry {
public:
    static PipelineRegistry& getInstance() {
        static PipelineRegistry instance;
        return instance;
    }

    void registerStep(const std::string& typeName, std::function<std::shared_ptr<IPipelineStep>()> factory);
    
    std::shared_ptr<IPipelineStep> createStep(const std::string& typeName) const;

private:
    PipelineRegistry() = default;
    
    std::unordered_map<std::string, std::function<std::shared_ptr<IPipelineStep>()>> factories;
    mutable std::mutex registryMutex;
};

} // namespace DataPipeline

#endif // PIPELINE_REGISTRY_H
