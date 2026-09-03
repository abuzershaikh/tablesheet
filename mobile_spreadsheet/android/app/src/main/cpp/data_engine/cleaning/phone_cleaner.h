/*
 * phone_cleaner.h  —  Indian Phone Number Normalizer
 *
 * FOLDER CONTEXT:
 *   Lives in:     data_engine/cleaning/
 *   Called by:    data_engine/cleaning/data_cleaner.cpp  (for DataType::PHONE)
 *   Detector:     data_engine/detector/plugins/phone_plugin.h
 *   FFI export:   ffi_bridge.cpp  → cleanColumn()
 *
 * OUTPUT FORMAT: +91XXXXXXXXXX (E.164 international format for Indian numbers)
 *                or original if can't normalize
 */
#pragma once
#include <string>

namespace Filters {

class PhoneCleaner {
public:
    /**
     * Normalize a phone number string to E.164 format.
     *   "9876543210"     → "+919876543210"
     *   "09876543210"    → "+919876543210"
     *   "+91 9876 543210" → "+919876543210"
     *   "+1-800-555-0100" → "+18005550100" (international passthrough)
     */
    static std::string normalize(const std::string& rawPhone);
};

} // namespace Filters
