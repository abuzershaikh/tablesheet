#include "relational_pattern.h"
#include "../cleaning/date_cleaner.h"
#include <algorithm>

namespace PatternIntelligence {
    std::vector<RelationalAnomaly> RelationalPattern::checkTemporalLogic(
        const std::vector<std::string>& primaryDates, const std::vector<std::string>& primaryRefs,
        const std::vector<std::string>& secondaryDates, const std::vector<std::string>& secondaryRefs) {
        
        std::vector<RelationalAnomaly> anomalies;
        size_t limit = std::min(primaryDates.size(), secondaryDates.size());
        Filters::DateCleaner& dateCleaner = Filters::DateCleaner::getInstance();

        for (size_t i = 0; i < limit; ++i) {
            if (!primaryDates[i].empty() && !secondaryDates[i].empty()) {
                Filters::ParsedDate p1 = dateCleaner.parse(primaryDates[i]);
                Filters::ParsedDate p2 = dateCleaner.parse(secondaryDates[i]);

                if (p1.isValid && p2.isValid) {
                    // Compare chronological days
                    long dayCount1 = (long)p1.year * 372 + p1.month * 31 + p1.day;
                    long dayCount2 = (long)p2.year * 372 + p2.month * 31 + p2.day;

                    if (dayCount2 < dayCount1) {
                        RelationalAnomaly anomaly;
                        anomaly.primaryCellRef = (i < primaryRefs.size()) ? primaryRefs[i] : "";
                        anomaly.secondaryCellRef = (i < secondaryRefs.size()) ? secondaryRefs[i] : "";
                        anomaly.primaryValue = primaryDates[i];
                        anomaly.secondaryValue = secondaryDates[i];
                        anomaly.description = "Secondary date (" + secondaryDates[i] + ") is earlier than primary date (" + primaryDates[i] + ") — Chronological Time-Travel Anomaly.";
                        anomalies.push_back(anomaly);
                    }
                }
            }
        }
        return anomalies;
    }
}
