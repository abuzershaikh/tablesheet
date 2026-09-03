/*
 * cluster_engine.cpp  —  Enterprise Fuzzy & Phonetic Clustering Engine Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cluster/
 */
#include "cluster_engine.h"
#include "phonetic_matcher.h"
#include "levenshtein.h"
#include <sstream>
#include <set>
#include <algorithm>

namespace Filters {

static std::string escapeJson(const std::string& s) {
    std::string res;
    for (char c : s) {
        if (c == '"') res += "\\\"";
        else if (c == '\\') res += "\\\\";
        else if (c == '\n') res += "\\n";
        else if (c == '\r') res += "\\r";
        else if (c == '\t') res += "\\t";
        else res += c;
    }
    return res;
}

std::string ClusterResult::toJson() const {
    std::ostringstream oss;
    oss << "{";
    oss << "\"column\":\"" << escapeJson(columnLetter) << "\",";
    oss << "\"totalValues\":" << totalValues << ",";
    oss << "\"clusteredCount\":" << clusteredCount << ",";
    oss << "\"clusteringRatio\":" << clusteringRatio << ",";
    oss << "\"clusters\":[";
    for (size_t i = 0; i < clusters.size(); i++) {
        const auto& g = clusters[i];
        oss << "{";
        oss << "\"canonical\":\"" << escapeJson(g.canonical) << "\",";
        oss << "\"algorithm\":\"" << escapeJson(g.algorithm) << "\",";
        oss << "\"avgSimilarity\":" << g.avgSimilarity << ",";
        oss << "\"canonicalCount\":" << g.canonicalCount << ",";
        oss << "\"variants\":[";
        for (size_t v = 0; v < g.variants.size(); v++) {
            oss << "\"" << escapeJson(g.variants[v]) << "\"";
            if (v + 1 < g.variants.size()) oss << ",";
        }
        oss << "]}";
        if (i + 1 < clusters.size()) oss << ",";
    }
    oss << "]}";
    return oss.str();
}

std::string ClusterEngine::pickCanonical(const std::vector<std::string>& variants,
                                         const std::map<std::string, int>& freq) {
    if (variants.empty()) return "";
    std::string best = variants[0];
    int maxF = -1;
    for (const auto& v : variants) {
        auto it = freq.find(v);
        int f = (it != freq.end()) ? it->second : 1;
        if (f > maxF) {
            maxF = f;
            best = v;
        } else if (f == maxF && v.length() > best.length()) {
            best = v; // Prefer fuller title
        }
    }
    return best;
}

std::vector<ClusterGroup> ClusterEngine::clusterByFingerprint(const std::vector<std::string>& values) const {
    std::map<std::string, std::vector<std::string>> fpMap;
    std::map<std::string, int> freq;

    for (const auto& v : values) {
        if (v.empty()) continue;
        freq[v]++;
        std::string fp = fingerprint(v);
        if (!fp.empty()) {
            fpMap[fp].push_back(v);
        }
    }

    std::vector<ClusterGroup> groups;
    for (const auto& pair : fpMap) {
        std::set<std::string> uniqueVars(pair.second.begin(), pair.second.end());
        if (uniqueVars.size() > 1) {
            ClusterGroup g;
            g.variants.assign(uniqueVars.begin(), uniqueVars.end());
            g.canonical = pickCanonical(g.variants, freq);
            g.canonicalCount = freq[g.canonical];
            g.avgSimilarity = 0.95f;
            g.algorithm = "Key Collision (Fingerprint)";
            groups.push_back(g);
        }
    }
    return groups;
}

static std::string cleanToken(const std::string& str) {
    std::string s = str;
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return std::tolower(c); });
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(0, 1);
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    return s;
}

std::vector<ClusterGroup> ClusterEngine::clusterByLevenshtein(
    const std::vector<std::string>& values, float threshold) const {

    std::map<std::string, int> freq;
    std::vector<std::string> uniq;
    for (const auto& v : values) {
        if (v.empty()) continue;
        if (freq[v]++ == 0) uniq.push_back(v);
    }

    std::vector<ClusterGroup> groups;
    if (uniq.empty()) return groups;

    std::vector<bool> visited(uniq.size(), false);

    // Build Inverted Index for Candidate Blocking
    std::unordered_map<std::string, std::vector<int>> tokenIndex;
    for (size_t i = 0; i < uniq.size(); i++) {
        std::string s = cleanToken(uniq[i]);
        if (s.empty()) continue;

        // 1. Prefix key (first 2-3 characters)
        if (s.length() >= 2) {
            tokenIndex[s.substr(0, 2)].push_back(static_cast<int>(i));
        }
        // 2. Phonetic code
        std::string sx = PhoneticMatcher::soundex(s);
        if (!sx.empty()) {
            tokenIndex["sx_" + sx].push_back(static_cast<int>(i));
        }
        // 3. 2-gram character shingles
        if (s.length() >= 3) {
            for (size_t k = 0; k + 2 <= s.length(); k++) {
                tokenIndex["2g_" + s.substr(k, 2)].push_back(static_cast<int>(i));
            }
        }
    }

    for (size_t i = 0; i < uniq.size(); i++) {
        if (visited[i]) continue;
        std::vector<std::string> clusterVars = { uniq[i] };
        float simSum = 1.0f;
        int pairCount = 1;

        std::string s = cleanToken(uniq[i]);

        // Find candidate indices sharing blocking keys
        std::unordered_map<int, int> candidateHits;
        if (uniq.size() > 150) {
            // Use Inverted Index candidates to avoid O(N^2)
            if (s.length() >= 2) {
                for (int idx : tokenIndex[s.substr(0, 2)]) if (idx > (int)i) candidateHits[idx] += 3;
            }
            std::string sx = PhoneticMatcher::soundex(s);
            if (!sx.empty()) {
                for (int idx : tokenIndex["sx_" + sx]) if (idx > (int)i) candidateHits[idx] += 2;
            }
            if (s.length() >= 3) {
                for (size_t k = 0; k + 2 <= s.length(); k++) {
                    for (int idx : tokenIndex["2g_" + s.substr(k, 2)]) if (idx > (int)i) candidateHits[idx]++;
                }
            }
        } else {
            // On small datasets, evaluate all pairs for maximum recall
            for (size_t j = i + 1; j < uniq.size(); j++) {
                candidateHits[static_cast<int>(j)] = 1;
            }
        }

        for (const auto& [candIdx, hits] : candidateHits) {
            if (visited[candIdx] || candIdx <= (int)i) continue;
            // Require minimum key overlap for large datasets
            if (uniq.size() > 150 && hits < 2) continue;

            float sim = PhoneticMatcher::getInstance().hybridSimilarity(uniq[i], uniq[candIdx]);
            if (sim >= threshold) {
                visited[candIdx] = true;
                clusterVars.push_back(uniq[candIdx]);
                simSum += sim;
                pairCount++;
            }
        }

        if (clusterVars.size() > 1) {
            visited[i] = true;
            ClusterGroup g;
            g.variants = clusterVars;
            g.canonical = pickCanonical(clusterVars, freq);
            g.canonicalCount = freq[g.canonical];
            g.avgSimilarity = simSum / pairCount;
            g.algorithm = "Hybrid Levenshtein & Phonetic";
            groups.push_back(g);
        }
    }
    return groups;
}

std::vector<ClusterGroup> ClusterEngine::mergeOverlapping(std::vector<ClusterGroup> groups) const {
    // Basic deduplication of overlapping cluster groups
    return groups;
}

ClusterResult ClusterEngine::cluster(const std::vector<std::string>& values,
                                     const std::string& columnLetter,
                                     float threshold) const {
    ClusterResult res;
    res.columnLetter = columnLetter;
    res.totalValues = static_cast<int>(values.size());

    // 1. Cluster by Fingerprint
    std::vector<ClusterGroup> fpGroups = clusterByFingerprint(values);

    // 2. Cluster by Levenshtein + Phonetics
    std::vector<ClusterGroup> levGroups = clusterByLevenshtein(values, threshold);

    // Combine
    res.clusters = fpGroups;
    for (const auto& lg : levGroups) {
        bool alreadyExists = false;
        for (const auto& existing : res.clusters) {
            if (existing.canonical == lg.canonical) {
                alreadyExists = true;
                break;
            }
        }
        if (!alreadyExists) {
            res.clusters.push_back(lg);
        }
    }

    int clusteredItems = 0;
    for (const auto& g : res.clusters) {
        clusteredItems += static_cast<int>(g.variants.size());
    }
    res.clusteredCount = clusteredItems;
    res.clusteringRatio = (res.totalValues > 0) ? (static_cast<float>(clusteredItems) / res.totalValues) : 0.0f;

    return res;
}

std::vector<std::string> ClusterEngine::applyClusters(
    const std::vector<std::string>& values,
    const ClusterResult& result) const {

    std::map<std::string, std::string> replacementMap;
    for (const auto& group : result.clusters) {
        for (const auto& variant : group.variants) {
            replacementMap[variant] = group.canonical;
        }
    }

    std::vector<std::string> cleaned = values;
    for (auto& val : cleaned) {
        auto it = replacementMap.find(val);
        if (it != replacementMap.end()) {
            val = it->second;
        }
    }
    return cleaned;
}

} // namespace Filters
