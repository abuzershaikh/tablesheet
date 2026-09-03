#pragma once
#include "levenshtein.h"
#include <string>
#include <vector>
#include <map>

namespace Filters {

struct ClusterGroup {
    std::string canonical;       // Most frequent or alphabetically first
    std::vector<std::string> variants; // All similar values
    float avgSimilarity;         // Average similarity score
    std::string algorithm;       // Algorithm that found this cluster
    int canonicalCount;          // How many times canonical appears
};

struct ClusterResult {
    std::string columnLetter;
    std::vector<ClusterGroup> clusters; // Found clusters
    int totalValues;             // Total unique values analyzed
    int clusteredCount;          // Values that ended up in a cluster
    float clusteringRatio;       // clusteredCount / totalValues
    std::string toJson() const;
};

class ClusterEngine {
public:
    static ClusterEngine& getInstance() {
        static ClusterEngine inst;
        return inst;
    }

    /**
     * Find fuzzy clusters in a column's values.
     * @param values      All unique values in the column
     * @param columnLetter e.g. "A"
     * @param threshold   Minimum similarity to cluster (default 0.85)
     */
    ClusterResult cluster(const std::vector<std::string>& values,
                          const std::string& columnLetter,
                          float threshold = 0.85f) const;

    /// Apply clusters: replace variants with canonical in a value list
    std::vector<std::string> applyClusters(const std::vector<std::string>& values,
                                            const ClusterResult& result) const;

private:
    ClusterEngine() = default;
    std::vector<ClusterGroup> clusterByFingerprint(const std::vector<std::string>& values) const;
    std::vector<ClusterGroup> clusterByLevenshtein(const std::vector<std::string>& values,
                                                    float threshold) const;
    std::vector<ClusterGroup> mergeOverlapping(std::vector<ClusterGroup> groups) const;
    static std::string pickCanonical(const std::vector<std::string>& variants,
                                      const std::map<std::string,int>& freq);
};

} // namespace Filters
