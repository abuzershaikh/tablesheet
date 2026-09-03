#pragma once
#include <string>
#include <vector>

namespace PatternIntelligence {
    struct SequenceAnomaly {
        int index;
        std::string expectedValue;
        std::string foundValue;
        std::string cellRef;
    };

    class SequencePattern {
    public:
        // Returns a list of anomalies if the sequence is broken (e.g., 1, 2, 4 -> 3 is missing)
        static std::vector<SequenceAnomaly> checkNumericSequence(const std::vector<std::string>& values, const std::vector<std::string>& cellRefs);
    };
}
