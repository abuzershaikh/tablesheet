#pragma once
#include <string>
#include <vector>
#include <map>

namespace Filters {

struct ColumnProfile {
    std::string columnLetter;
    int minLength;              // Shortest value
    int maxLength;              // Longest value
    float avgLength;            // Average length
    float entropy;              // Shannon entropy (0.0-1.0)
    std::string detectedPattern;// "ABC###" or "INV-####-###" or ""
    std::vector<std::string> invalidByPattern; // Values that don't match pattern
    std::string mostFrequent;   // Most common value
    int mostFrequentCount;
    std::string leastFrequent;  // Least common non-unique value
    std::vector<std::string> outliers; // Values far from pattern
};

class ColumnProfiler {
public:
    static ColumnProfiler& getInstance() {
        static ColumnProfiler inst;
        return inst;
    }
    ColumnProfile profile(const std::vector<std::string>& values,
                          const std::string& columnLetter) const;
private:
    ColumnProfiler() = default;
    static float computeEntropy(const std::vector<std::string>& values);
    static std::string learnPattern(const std::vector<std::string>& values);
    static std::vector<std::string> findPatternInvalid(
        const std::vector<std::string>& values, const std::string& pattern);
};

} // namespace Filters
