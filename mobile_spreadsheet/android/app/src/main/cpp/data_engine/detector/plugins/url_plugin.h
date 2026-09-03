/*
 * url_plugin.h  —  URL / Web Link Detector
 *
 * FOLDER CONTEXT:
 *   Lives in:  data_engine/detector/plugins/
 *   Interface: data_engine/detector/data_detector.h
 *   DataType:  data_engine/cache/column_metadata.h  → DataType::URL
 */
#pragma once
#include "../data_detector.h"
#include <string>

namespace Filters {

/**
 * UrlPlugin
 * Detects HTTP/HTTPS URLs and www. prefixed links.
 * Confidence: 1.0 for http(s)://, 0.85 for www.
 */
class UrlPlugin : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override;
    DataType getDataType() const override { return DataType::URL; }
    std::string getName() const override { return "URL"; }
};

} // namespace Filters
