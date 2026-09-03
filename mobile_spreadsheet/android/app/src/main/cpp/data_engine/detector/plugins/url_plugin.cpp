/*
 * url_plugin.cpp — URL Detection Logic
 */
#include "url_plugin.h"
#include <algorithm>

namespace Filters {

float UrlPlugin::detect(const std::string& val) const {
    if (val.size() < 7) return 0.0f;
    std::string lower = val;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
    if (lower.substr(0, 8) == "https://") return 1.0f;
    if (lower.substr(0, 7) == "http://")  return 1.0f;
    if (lower.substr(0, 4) == "www.")      return 0.85f;
    return 0.0f;
}

} // namespace Filters
