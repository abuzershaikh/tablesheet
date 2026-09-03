/*
 * plugin_registry.h  —  Registry-Based Detector Plugin System (Phase 2)
 *
 * FOLDER CONTEXT:
 *   Lives in:     data_engine/detector/
 *   Plugins from: data_engine/detector/plugins/  (phone, email, currency, etc.)
 *   Interface:    data_engine/detector/data_detector.h  (IDataDetectorPlugin)
 *   Used by:      data_engine/detector/data_detector.cpp  (can delegate here)
 *   Also used by: data_engine/analyzer/column_analyzer.cpp (CompositeResult)
 *
 * BENEFIT:
 *   New plugins register themselves via static initializer (REGISTER_PLUGIN macro).
 *   No need to modify data_detector.cpp to add a new plugin!
 *   Plugins can be enabled/disabled at runtime.
 *   Priority controls detection order (higher priority = checked first).
 *
 * USAGE:
 *   // Auto-registration in plugin .cpp file:
 *   static bool _registered = [](){
 *       DetectorRegistry::getInstance().registerPlugin(
 *           std::make_shared<MyPlugin>(), 80);
 *       return true;
 *   }();
 *
 *   // Detection with all candidates:
 *   auto result = DetectorRegistry::getInstance().detectWithAll("9876543210");
 *   // result.winner = DataType::PHONE, result.allCandidates = [...]
 */
#pragma once
#include "data_detector.h"
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <mutex>

namespace Filters {

// ─────────────────────────────────────────────────────────────────────────────
// PluginEntry — registered plugin with priority and enabled state
// ─────────────────────────────────────────────────────────────────────────────
struct PluginEntry {
    std::shared_ptr<IDataDetectorPlugin> plugin;
    int priority;    ///< Higher = checked first (default 50)
    bool enabled;    ///< Can be toggled at runtime
};

// ─────────────────────────────────────────────────────────────────────────────
// CompositeDetectionResult — full result with all candidates + winner
// ─────────────────────────────────────────────────────────────────────────────
struct CompositeDetectionResult {
    DataType winner;             ///< Highest confidence type
    std::string winnerName;      ///< Human-readable
    float winnerConfidence;      ///< 0.0–1.0

    DataType secondBest;         ///< Second-highest confidence type
    std::string secondBestName;
    float secondBestConfidence;

    std::string reason;          ///< Explainability: why this type was chosen

    /// All detected candidates sorted by confidence desc
    struct Candidate {
        DataType type;
        std::string name;
        float confidence;
    };
    std::vector<Candidate> allCandidates;
};

// ─────────────────────────────────────────────────────────────────────────────
// DetectorRegistry — thread-safe plugin registry (singleton)
// ─────────────────────────────────────────────────────────────────────────────
class DetectorRegistry {
public:
    static DetectorRegistry& getInstance() {
        static DetectorRegistry instance;
        return instance;
    }

    /**
     * Register a plugin with a given priority.
     * @param plugin   Shared pointer to plugin
     * @param priority Higher = checked first. Range 0–100. Default 50.
     */
    void registerPlugin(std::shared_ptr<IDataDetectorPlugin> plugin,
                        int priority = 50);

    /**
     * Enable or disable a plugin by its getName() value.
     * Disabled plugins are skipped during detection.
     */
    void setPluginEnabled(const std::string& pluginName, bool enabled);

    /**
     * Detect type of a single value and return ALL candidates.
     * Returns CompositeDetectionResult with winner + all confidence scores.
     */
    CompositeDetectionResult detectWithAll(const std::string& value) const;

    /**
     * Simple detect: returns just the winning DataType (same API as DataDetector).
     */
    DataType detect(const std::string& value) const;

    /// List all registered plugin names and their priorities
    std::vector<std::string> listPlugins() const;

private:
    DetectorRegistry() = default;
    mutable std::mutex _mutex;
    std::vector<PluginEntry> _plugins;  // sorted by priority desc
    static std::string typeToName(DataType type);
    static std::string buildReason(DataType type, float conf);
};

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER_PLUGIN macro — auto-registers plugin in static initializer
// Usage in your plugin .cpp file:
//   REGISTER_PLUGIN(MyPlugin, 80)
// ─────────────────────────────────────────────────────────────────────────────
#define REGISTER_PLUGIN(PluginClass, Priority) \
    static bool _plugin_reg_##PluginClass = []() { \
        Filters::DetectorRegistry::getInstance().registerPlugin( \
            std::make_shared<PluginClass>(), Priority); \
        return true; \
    }()

} // namespace Filters
