/*
 * currency_plugin.h  —  Currency & Price Detector (₹/$/ € / comma-separated)
 *
 * FOLDER CONTEXT:
 *   Lives in:    data_engine/detector/plugins/
 *   Interface:   data_engine/detector/data_detector.h
 *   Cleaner:     data_engine/cleaning/currency_cleaner.h  (planned)
 *   DataType:    data_engine/cache/column_metadata.h  → DataType::CURRENCY
 */
#pragma once
#include "../data_detector.h"
#include <string>

namespace Filters {

/**
 * CurrencyPlugin
 * Detects numeric values formatted as currency:
 *   ₹1,250.00  $5.99  €100  1,000  1250.50
 * Confidence: 0.98 with currency symbol, 0.75 for comma-formatted number.
 */
class CurrencyPlugin : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override;
    DataType getDataType() const override { return DataType::CURRENCY; }
    std::string getName() const override { return "Currency"; }
};

} // namespace Filters
