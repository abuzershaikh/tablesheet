/*
 * aggregation_engine.h — Dynamic Aggregations (SUM, AVG, COUNT, MIN, MAX)
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#pragma once
#include "pivot_cache_engine.h"
#include <string>
#include <vector>

namespace Filters {

enum class AggregationType {
    SUM,
    AVG,
    COUNT,
    MIN,
    MAX
};

class AggregationEngine {
public:
    static double compute(const PivotCacheEngine& cache, 
                           const std::vector<int>& rowIndices, 
                           int valColIndex, 
                           AggregationType type);

    static AggregationType parseType(const std::string& str);
    static std::string typeToString(AggregationType type);
};

} // namespace Filters
