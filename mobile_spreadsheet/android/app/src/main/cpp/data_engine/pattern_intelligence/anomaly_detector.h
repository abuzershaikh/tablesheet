#pragma once
#include <string>
#include <vector>

namespace PatternIntelligence {
    struct Anomaly {
        std::string cellRef;
        std::string value;
        std::string reason;
    };

    class AnomalyDetector {
    public:
        // Detects length anomalies and mixed data types (e.g. text in numeric column)
        static std::vector<Anomaly> detectAnomalies(const std::vector<std::string>& values, const std::vector<std::string>& cellRefs);
    };
}
