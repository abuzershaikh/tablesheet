#include "sequence_pattern.h"
#include <algorithm>
#include <map>
#include <iostream>

namespace PatternIntelligence {
    std::vector<SequenceAnomaly> SequencePattern::checkNumericSequence(const std::vector<std::string>& values, const std::vector<std::string>& cellRefs) {
        std::vector<SequenceAnomaly> anomalies;
        if (values.size() < 3) return anomalies;

        std::map<int, std::string> numMap;
        std::vector<int> numbers;

        for (size_t i = 0; i < values.size(); ++i) {
            try {
                int n = std::stoi(values[i]);
                numbers.push_back(n);
                numMap[n] = cellRefs[i];
            } catch (...) {
                // Not a number, skip for sequence check
            }
        }

        if (numbers.size() < 3) return anomalies;

        std::sort(numbers.begin(), numbers.end());

        // Simple gap detection (e.g., 1001, 1002, 1004 -> missing 1003)
        for (size_t i = 0; i < numbers.size() - 1; ++i) {
            if (numbers[i + 1] - numbers[i] > 1 && numbers[i + 1] - numbers[i] < 10) {
                // Sequence break found
                SequenceAnomaly anomaly;
                anomaly.index = i;
                anomaly.expectedValue = std::to_string(numbers[i] + 1);
                anomaly.foundValue = std::to_string(numbers[i + 1]);
                anomaly.cellRef = numMap[numbers[i + 1]];
                anomalies.push_back(anomaly);
            }
        }
        return anomalies;
    }
}
