#include "pipeline_registry.h"

namespace DataPipeline {

void PipelineRegistry::registerStep(const std::string& typeName, std::function<std::shared_ptr<IPipelineStep>()> factory) {
    std::lock_guard<std::mutex> lock(registryMutex);
    factories[typeName] = factory;
}

std::shared_ptr<IPipelineStep> PipelineRegistry::createStep(const std::string& typeName) const {
    std::lock_guard<std::mutex> lock(registryMutex);
    auto it = factories.find(typeName);
    if (it != factories.end()) {
        return it->second();
    }
    return nullptr;
}

} // namespace DataPipeline
