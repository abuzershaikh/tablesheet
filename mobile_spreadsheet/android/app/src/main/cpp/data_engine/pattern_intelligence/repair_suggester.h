#pragma once
#include <string>
#include <vector>

namespace PatternIntelligence {
    struct RepairSuggestion {
        std::string cellRef;
        std::string originalValue;
        std::string suggestedValue;
        double confidenceScore; // 0.0 to 1.0
    };

    class RepairSuggester {
    public:
        // Generates auto-repair suggestions based on data profiling
        static std::vector<RepairSuggestion> suggestRepairs(const std::vector<std::string>& values, const std::vector<std::string>& cellRefs);
    };
}
