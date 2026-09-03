/*
 * aggregation_engine.cpp — Dynamic Aggregations Implementation
 * Lives in: android/app/src/main/cpp/data_engine/pivot/
 */
#include "aggregation_engine.h"
#include <cstdlib>
#include <cmath>
#include <limits>
#include <algorithm>

namespace Filters {

AggregationType AggregationEngine::parseType(const std::string& str) {
    std::string s = str;
    for (auto& c : s) c = toupper(c);
    if (s == "AVG" || s == "AVERAGE") return AggregationType::AVG;
    if (s == "COUNT") return AggregationType::COUNT;
    if (s == "MIN") return AggregationType::MIN;
    if (s == "MAX") return AggregationType::MAX;
    return AggregationType::SUM;
}

std::string AggregationEngine::typeToString(AggregationType type) {
    switch (type) {
        case AggregationType::AVG: return "AVG";
        case AggregationType::COUNT: return "COUNT";
        case AggregationType::MIN: return "MIN";
        case AggregationType::MAX: return "MAX";
        default: return "SUM";
    }
}

double AggregationEngine::compute(const PivotCacheEngine& cache, 
                                   const std::vector<int>& rowIndices, 
                                   int valColIndex, 
                                   AggregationType type) {
    if (rowIndices.empty() || valColIndex < 0) return 0.0;

    if (type == AggregationType::COUNT) {
        double validCount = 0;
        for (int r : rowIndices) {
            const std::string& valStr = cache.getCellValue(r, valColIndex);
            if (!valStr.empty()) validCount++;
        }
        return validCount;
    }

    double sum = 0.0;
    double count = 0.0;
    double minVal = std::numeric_limits<double>::infinity();
    double maxVal = -std::numeric_limits<double>::infinity();

    for (int r : rowIndices) {
        const std::string& valStr = cache.getCellValue(r, valColIndex);
        if (valStr.empty()) continue;

        char* endPtr = nullptr;
        double v = std::strtod(valStr.c_str(), &endPtr);
        if (endPtr != valStr.c_str()) {
            sum += v;
            count += 1.0;
            if (v < minVal) minVal = v;
            if (v > maxVal) maxVal = v;
        }
    }

    if (count == 0.0) return 0.0;

    switch (type) {
        case AggregationType::SUM: return sum;
        case AggregationType::AVG: return sum / count;
        case AggregationType::MIN: return minVal;
        case AggregationType::MAX: return maxVal;
        default: return sum;
    }
}

} // namespace Filters
