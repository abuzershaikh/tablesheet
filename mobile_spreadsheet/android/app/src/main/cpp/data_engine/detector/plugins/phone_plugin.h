/*
 * phone_plugin.h  —  Advanced Indian & International Phone Number Detector
 *
 * FOLDER CONTEXT:
 *   This file lives in: data_engine/detector/plugins/
 *   Interface defined in: data_engine/detector/data_detector.h
 *   Registered in:        data_engine/detector/data_detector.cpp
 *   Cleaner lives in:     data_engine/cleaning/phone_cleaner.h
 *   DataType enum in:     data_engine/cache/column_metadata.h
 */
#pragma once
#include "../data_detector.h"
#include <string>

namespace Filters {

/**
 * PhonePlugin
 * Detects Indian domestic (10-digit), +91 prefixed, 0-prefixed,
 * and international phone numbers with country codes.
 * Confidence: 0.97 for Indian 10-digit, 0.90 for +CC format, 0.0 otherwise.
 */
class PhonePlugin : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override;
    DataType getDataType() const override { return DataType::PHONE; }
    std::string getName() const override { return "Phone"; }
};

} // namespace Filters
