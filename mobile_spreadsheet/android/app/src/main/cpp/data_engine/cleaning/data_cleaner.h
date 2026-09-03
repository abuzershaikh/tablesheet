/*
 * data_cleaner.h  —  Universal Type-Aware Data Cleaner (Main Entry Point)
 *
 * FOLDER CONTEXT:
 *   Lives in:       data_engine/cleaning/
 *   Type detection: data_engine/detector/data_detector.h  ← called by autoClean()
 *   Phone cleaner:  data_engine/cleaning/phone_cleaner.h
 *   Text cleaner:   data_engine/cleaning/text_cleaner.h
 *   DataType enum:  data_engine/cache/column_metadata.h
 *   FFI export:     ffi_bridge.cpp  → autoCleanValue() / cleanColumn()
 *
 * USAGE:
 *   std::string clean = DataCleaner::getInstance().autoClean(rawValue);
 *   std::string clean = DataCleaner::getInstance().clean(rawValue, DataType::PHONE);
 */
#pragma once
#include "../cache/column_metadata.h"
#include <string>

namespace Filters {

class DataCleaner {
public:
    static DataCleaner& getInstance() {
        static DataCleaner instance;
        return instance;
    }

    /**
     * Clean value given its already-known DataType.
     * Routes to the appropriate specialist cleaner.
     */
    std::string clean(const std::string& value, DataType type) const;

    /**
     * Auto-detect data type using DataDetector, then clean.
     * Use this when type is unknown.
     */
    std::string autoClean(const std::string& value) const;

private:
    DataCleaner() = default;
};

} // namespace Filters
