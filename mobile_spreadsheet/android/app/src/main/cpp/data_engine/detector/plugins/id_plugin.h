/*
 * id_plugin.h  —  Indian Document ID Detector (PAN, GST, Aadhaar, IFSC)
 *
 * FOLDER CONTEXT:
 *   Lives in:  data_engine/detector/plugins/
 *   Interface: data_engine/detector/data_detector.h
 *   DataType:  data_engine/cache/column_metadata.h
 *
 * SUPPORTED ID TYPES:
 *   PAN Card:  ABCDE1234F     (5 letters + 4 digits + 1 letter)
 *   GST:       07AAHCM9639M1Z7 (15 chars, specific format)
 *   Aadhaar:   1234 5678 9012  (12 digits, optional spaces)
 *   IFSC:      SBIN0001234     (4 letters + 0 + 6 alphanumeric)
 *   CIN:       U12345MH2019PTC123456
 */
#pragma once
#include "../data_detector.h"
#include <string>

namespace Filters {

class IdPlugin : public IDataDetectorPlugin {
public:
    float detect(const std::string& val) const override;
    DataType getDataType() const override { return DataType::UUID; } // Reusing UUID for ID docs
    std::string getName() const override { return "IndianID"; }

    // Specific sub-type detectors (used by analyzer)
    static bool isPAN(const std::string& val);
    static bool isGST(const std::string& val);
    static bool isAadhaar(const std::string& val);
    static bool isIFSC(const std::string& val);
};

} // namespace Filters
