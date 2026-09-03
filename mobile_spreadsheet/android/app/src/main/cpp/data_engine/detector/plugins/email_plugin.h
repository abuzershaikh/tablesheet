/*
 * email_plugin.h  —  Enterprise Layered Email Detector Plugin
 *
 * FOLDER CONTEXT:
 *   Lives in:    data_engine/detector/plugins/
 *   Interface:   data_engine/detector/data_detector.h
 *   Cleaner:     data_engine/cleaning/email_cleaner.h
 *   DataType:    data_engine/cache/column_metadata.h  → DataType::EMAIL
 */
#pragma once
#include "../data_detector.h"
#include <string>

namespace Filters {

/**
 * EmailPlugin
 * Detects email addresses using the layered EmailCleaner parser.
 * Confidence: 0.95–1.00 for valid emails, 0.0 for invalid string.
 */
class EmailPlugin : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override;
    DataType getDataType() const override { return DataType::EMAIL; }
    std::string getName() const override { return "Email"; }
};

} // namespace Filters
