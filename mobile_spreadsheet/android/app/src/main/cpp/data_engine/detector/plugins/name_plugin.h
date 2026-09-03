/*
 * name_plugin.h  —  Human Name Detector
 *
 * FOLDER CONTEXT:
 *   Lives in:  data_engine/detector/plugins/
 *   Interface: data_engine/detector/data_detector.h
 *   Cleaner:   data_engine/cleaning/name_cleaner.h
 *   DataType:  data_engine/cache/column_metadata.h  → DataType::TEXT (subtype: name)
 *
 * NOTE: Names are stored as DataType::TEXT with high confidence.
 *       The column_analyzer (data_engine/analyzer/column_analyzer.h) uses
 *       this plugin's score to label the column as "Name" type.
 */
#pragma once
#include "../data_detector.h"
#include <string>

namespace Filters {

/**
 * NamePlugin
 * Detects human names: 2-3 alphabetic words, optional dot for initials.
 * Examples: "Abuzer Khan", "M. Ali", "Priya Sharma", "RAHUL KUMAR"
 * Confidence: 0.80 for 2-word alpha-only, 0.70 for 1-word short alpha.
 */
class NamePlugin : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override;
    DataType getDataType() const override { return DataType::TEXT; }
    std::string getName() const override { return "Name"; }
};

} // namespace Filters
