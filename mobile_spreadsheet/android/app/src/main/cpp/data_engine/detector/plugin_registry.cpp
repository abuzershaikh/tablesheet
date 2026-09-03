/*
 * plugin_registry.cpp  —  Registry-Based Detector Plugin System (Phase 2)
 *
 * FOLDER CONTEXT:
 *   Lives in:  data_engine/detector/
 *   Header:    data_engine/detector/plugin_registry.h
 *   Used by:   data_engine/analyzer/column_analyzer.cpp (future integration)
 *   Used by:   data_engine/detector/data_detector.cpp (can delegate)
 *
 * HOW IT WORKS:
 *   Plugins register via registerPlugin() or REGISTER_PLUGIN macro.
 *   detectWithAll() runs every enabled plugin, collects all confidence scores,
 *   sorts by confidence, and returns winner + all candidates.
 *   Thread-safe via std::mutex.
 */
#include "plugin_registry.h"
#include <algorithm>
#include <sstream>

namespace Filters {

void DetectorRegistry::registerPlugin(std::shared_ptr<IDataDetectorPlugin> plugin,
                                       int priority) {
    std::lock_guard<std::mutex> lock(_mutex);
    // Insert in sorted position (highest priority first)
    PluginEntry entry{plugin, priority, true};
    auto it = std::lower_bound(_plugins.begin(), _plugins.end(), entry,
        [](const PluginEntry& a, const PluginEntry& b) {
            return a.priority > b.priority; // descending
        });
    _plugins.insert(it, entry);
}

void DetectorRegistry::setPluginEnabled(const std::string& pluginName, bool enabled) {
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& entry : _plugins) {
        if (entry.plugin->getName() == pluginName) {
            entry.enabled = enabled;
            break;
        }
    }
}

CompositeDetectionResult DetectorRegistry::detectWithAll(const std::string& value) const {
    CompositeDetectionResult result;
    result.winner           = DataType::TEXT;
    result.winnerName       = "Text";
    result.winnerConfidence = 0.0f;
    result.secondBest       = DataType::UNKNOWN;
    result.secondBestName   = "";
    result.secondBestConfidence = 0.0f;

    if (value.empty()) {
        result.winner     = DataType::BLANK;
        result.winnerName = "Blank";
        return result;
    }

    std::lock_guard<std::mutex> lock(_mutex);

    // Run all enabled plugins and collect confidence scores
    std::vector<CompositeDetectionResult::Candidate> candidates;
    for (const auto& entry : _plugins) {
        if (!entry.enabled) continue;
        float conf = entry.plugin->detect(value);  // detect() returns 0.0–1.0 confidence
        if (conf > 0.0f) {
            CompositeDetectionResult::Candidate cand;
            cand.type       = entry.plugin->getDataType();  // getDataType() returns DataType enum
            cand.name       = typeToName(entry.plugin->getDataType());
            cand.confidence = conf;
            candidates.push_back(cand);
        }
    }

    if (candidates.empty()) {
        // No plugin matched — fallback to TEXT
        result.winner           = DataType::TEXT;
        result.winnerName       = "Text";
        result.winnerConfidence = 0.45f;
        result.reason           = "No specific pattern detected — treated as plain text";
        CompositeDetectionResult::Candidate fallback{DataType::TEXT, "Text", 0.45f};
        result.allCandidates.push_back(fallback);
        return result;
    }

    // Sort by confidence descending
    std::sort(candidates.begin(), candidates.end(),
              [](const auto& a, const auto& b){ return a.confidence > b.confidence; });

    result.allCandidates = candidates;
    result.winner           = candidates[0].type;
    result.winnerName       = candidates[0].name;
    result.winnerConfidence = candidates[0].confidence;
    result.reason           = buildReason(result.winner, result.winnerConfidence);

    if (candidates.size() > 1) {
        result.secondBest           = candidates[1].type;
        result.secondBestName       = candidates[1].name;
        result.secondBestConfidence = candidates[1].confidence;
    }

    return result;
}

DataType DetectorRegistry::detect(const std::string& value) const {
    return detectWithAll(value).winner;
}

std::vector<std::string> DetectorRegistry::listPlugins() const {
    std::lock_guard<std::mutex> lock(_mutex);
    std::vector<std::string> names;
    for (const auto& e : _plugins) {
        std::string entry = e.plugin->getName()
            + " [priority=" + std::to_string(e.priority)
            + ", " + (e.enabled ? "enabled" : "disabled") + "]";
        names.push_back(entry);
    }
    return names;
}

std::string DetectorRegistry::typeToName(DataType type) {
    switch(type) {
        case DataType::PHONE:    return "Phone Number";
        case DataType::EMAIL:    return "Email Address";
        case DataType::DATE:     return "Date";
        case DataType::DATETIME: return "Date & Time";
        case DataType::CURRENCY: return "Currency / Price";
        case DataType::NUMBER:   return "Number";
        case DataType::TEXT:     return "Text";
        case DataType::BOOLEAN:  return "Boolean";
        case DataType::URL:      return "URL / Link";
        case DataType::UUID:     return "ID / Document";
        case DataType::BLANK:    return "Blank";
        case DataType::PAN:      return "PAN Card";
        case DataType::GST:      return "GST Number";
        case DataType::AADHAAR:  return "Aadhaar Number";
        case DataType::MIXED:    return "Mixed Data";
        default:                 return "Unknown";
    }
}

std::string DetectorRegistry::buildReason(DataType type, float conf) {
    std::string pct = std::to_string((int)(conf * 100)) + "% confidence";
    switch(type) {
        case DataType::PHONE:    return "Matches Indian/international phone pattern — " + pct;
        case DataType::EMAIL:    return "Contains '@' and valid domain — " + pct;
        case DataType::CURRENCY: return "Has currency symbol or comma-number format — " + pct;
        case DataType::DATE:     return "Matches date pattern (slashes/dashes) — " + pct;
        case DataType::NUMBER:   return "Parses cleanly as numeric value — " + pct;
        case DataType::UUID:     return "Matches Indian ID format (PAN/GST/Aadhaar) — " + pct;
        case DataType::URL:      return "Starts with http/https/www — " + pct;
        case DataType::BOOLEAN:  return "Is TRUE/FALSE/YES/NO value — " + pct;
        case DataType::TEXT:     return "Plain text, no specific pattern — " + pct;
        default:                 return pct;
    }
}

} // namespace Filters
