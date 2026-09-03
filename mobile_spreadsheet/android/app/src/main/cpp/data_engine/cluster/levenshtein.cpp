#include "levenshtein.h"
#include <cctype>
#include <set>
#include <cmath>

namespace Filters {

int levenshteinDistance(const std::string& a, const std::string& b) {
    size_t m = a.length(), n = b.length();
    std::vector<std::vector<int>> dp(m + 1, std::vector<int>(n + 1));
    for (size_t i = 0; i <= m; ++i) dp[i][0] = i;
    for (size_t j = 0; j <= n; ++j) dp[0][j] = j;

    for (size_t i = 1; i <= m; ++i) {
        for (size_t j = 1; j <= n; ++j) {
            int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
            dp[i][j] = std::min({ dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost });
        }
    }
    return dp[m][n];
}

float levenshteinSimilarity(const std::string& a, const std::string& b) {
    if (a.empty() && b.empty()) return 1.0f;
    int dist = levenshteinDistance(a, b);
    int maxLen = std::max(a.length(), b.length());
    return 1.0f - ((float)dist / maxLen);
}

float jaroWinkler(const std::string& a, const std::string& b) {
    if (a == b) return 1.0f;
    // Basic implementation placeholder for Jaro-Winkler
    return levenshteinSimilarity(a, b); 
}

float ngramSimilarity(const std::string& a, const std::string& b, int n) {
    if (a.length() < n || b.length() < n) return 0.0f;
    std::set<std::string> setA, setB;
    for (size_t i = 0; i <= a.length() - n; ++i) setA.insert(a.substr(i, n));
    for (size_t i = 0; i <= b.length() - n; ++i) setB.insert(b.substr(i, n));
    
    int intersection = 0;
    for (const auto& ng : setA) {
        if (setB.count(ng)) intersection++;
    }
    int unionSize = setA.size() + setB.size() - intersection;
    return unionSize == 0 ? 0.0f : (float)intersection / unionSize;
}

std::string fingerprint(const std::string& s) {
    std::string res;
    for (char c : s) {
        if (!std::isspace(c)) res += std::tolower(c);
    }
    std::sort(res.begin(), res.end());
    auto it = std::unique(res.begin(), res.end());
    res.erase(it, res.end());
    return res;
}

} // namespace Filters
