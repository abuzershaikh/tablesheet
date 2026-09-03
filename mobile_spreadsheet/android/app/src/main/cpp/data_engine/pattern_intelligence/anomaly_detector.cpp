#include "anomaly_detector.h"
#include <cctype>

namespace PatternIntelligence {
    std::vector<Anomaly> AnomalyDetector::detectAnomalies(const std::vector<std::string>& values, const std::vector<std::string>& cellRefs) {
        std::vector<Anomaly> anomalies;
        
        // Find majority type
        int numCount = 0;
        int textCount = 0;
        for (const auto& v : values) {
            if (v.empty()) continue;
            bool isNum = true;
            for (char c : v) { if (!std::isdigit(static_cast<unsigned char>(c)) && c != '.') { isNum = false; break; } }
            if (isNum) numCount++; else textCount++;
        }

        bool expectNum = (numCount > textCount * 2);

        for (size_t i = 0; i < values.size(); ++i) {
            if (values[i].empty()) continue;
            bool isNum = true;
            for (char c : values[i]) { if (!std::isdigit(static_cast<unsigned char>(c)) && c != '.') { isNum = false; break; } }

            if (expectNum && !isNum) {
                Anomaly a; a.cellRef = cellRefs[i]; a.value = values[i]; a.reason = "Text found in predominantly numeric column.";
                anomalies.push_back(a);
            }
        }
        return anomalies;
    }
}
