#pragma once
#include <string>
#include <vector>

namespace PatternIntelligence {
    struct RelationalAnomaly {
        std::string primaryCellRef;
        std::string secondaryCellRef;
        std::string primaryValue;
        std::string secondaryValue;
        std::string description;
    };

    class RelationalPattern {
    public:
        // Compares two columns (e.g. Order Date vs Delivery Date) for temporal anomalies
        static std::vector<RelationalAnomaly> checkTemporalLogic(
            const std::vector<std::string>& primaryDates, const std::vector<std::string>& primaryRefs,
            const std::vector<std::string>& secondaryDates, const std::vector<std::string>& secondaryRefs);
    };
}
