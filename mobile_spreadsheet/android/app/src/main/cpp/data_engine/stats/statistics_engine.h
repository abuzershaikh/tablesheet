#ifndef STATISTICS_ENGINE_H
#define STATISTICS_ENGINE_H

#include "../pipeline/pipeline_step.h"
#include <string>
#include <unordered_map>
#include <vector>

namespace Filters {

struct ColumnStats {
    long long count = 0;
    long long blank = 0;
    long long duplicates = 0;
    long long unique = 0;
    
    // Numeric stats
    double min = 0.0;
    double max = 0.0;
    double sum = 0.0;
    
    // Internal trackers
    std::unordered_map<std::string, long long> frequencyMap;
    bool isFirstNumeric = true;
    
    std::string toJson() const;
};

class StatisticsEngine {
public:
    static StatisticsEngine& getInstance() {
        static StatisticsEngine instance;
        return instance;
    }
    
    // Update stats with a new chunk of data
    void processChunk(int column, DataPipeline::PipelineContext& ctx);
    
    ColumnStats getStats(int column) const;
    
    void reset(int column);

private:
    StatisticsEngine() = default;
    
    std::unordered_map<int, ColumnStats> statsCache;
};

} // namespace Filters

#endif // STATISTICS_ENGINE_H
