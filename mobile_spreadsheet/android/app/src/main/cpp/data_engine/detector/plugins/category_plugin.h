/*
 * category_plugin.h  —  Category / Label Detector
 *
 * FOLDER CONTEXT:
 *   Lives in:  data_engine/detector/plugins/
 *   Interface: data_engine/detector/data_detector.h
 *
 * NOTE: For single-value detection, this gives a low confidence score.
 *       Column-level category detection (finding repeated labels) is handled by:
 *       data_engine/analyzer/column_analyzer.cpp
 */
#pragma once
#include "../data_detector.h"
#include <string>

namespace Filters {

/**
 * CategoryPlugin
 * Heuristic: short (3–30 chars), purely alphabetic (with spaces), no digits.
 * These are likely category labels: "Electronics", "Food & Bev", "In Stock".
 * Confidence: 0.45 (low, only wins if no other plugin matches better)
 */
class CategoryPlugin : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override;
    DataType getDataType() const override { return DataType::TEXT; }
    std::string getName() const override { return "Category"; }
};

} // namespace Filters
