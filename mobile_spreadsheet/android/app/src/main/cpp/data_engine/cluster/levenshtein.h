#pragma once
#include <string>
#include <vector>
#include <algorithm>

namespace Filters {

/// Classic Levenshtein edit distance
int levenshteinDistance(const std::string& a, const std::string& b);

/// Normalized similarity: 1.0 = identical, 0.0 = completely different
float levenshteinSimilarity(const std::string& a, const std::string& b);

/// Jaro-Winkler similarity — better for short strings and names
float jaroWinkler(const std::string& a, const std::string& b);

/// N-gram similarity (bigram by default)
float ngramSimilarity(const std::string& a, const std::string& b, int n = 2);

/// Fingerprint: sort chars + dedupe ("Sams ung" → "agmnsu" → groups typos)
std::string fingerprint(const std::string& s);

} // namespace Filters
