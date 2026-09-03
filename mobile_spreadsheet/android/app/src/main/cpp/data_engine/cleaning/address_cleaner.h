/*
 * address_cleaner.h  —  Enterprise Address Tokenizer & Component Parser Engine
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 *
 * PURPOSE:
 *   Parses raw unstructured address text into 8 distinct structured columns:
 *   [FlatNo, Building, Street, Locality, City, State, Pincode, Country]
 *
 * EXAMPLE:
 *   "Flat 402, Sunshine Heights, M.G. Road, Dadar West, Mumbai, Maharashtra 400028"
 *   → FlatNo:   "Flat 402"
 *   → Building: "Sunshine Heights"
 *   → Street:   "M.G. Road"
 *   → Locality: "Dadar West"
 *   → City:     "Mumbai"
 *   → State:    "Maharashtra"
 *   → Pincode:  "400028"
 *   → Country:  "India"
 */
#pragma once
#include <string>
#include <vector>

namespace Filters {

struct ParsedAddress {
    std::string flatNo = "";
    std::string building = "";
    std::string street = "";
    std::string locality = "";
    std::string city = "";
    std::string state = "";
    std::string pincode = "";
    std::string country = "";
    bool isValid = false;
    std::string rawAddress = "";

    std::string toJson() const;
};

class AddressCleaner {
public:
    static AddressCleaner& getInstance() {
        static AddressCleaner instance;
        return instance;
    }

    /// Parses any unstructured address string into structured components
    ParsedAddress parse(const std::string& rawAddress) const;

    /// Checks if a string looks like a physical street address
    bool isAddress(const std::string& input) const;

private:
    AddressCleaner();
    std::vector<std::string> _majorIndianCities;
    std::vector<std::string> _majorIndianStates;
    std::vector<std::string> _streetKeywords;
    std::vector<std::string> _buildingKeywords;

    void initDictionaries();
    static std::string extractPincode(const std::string& text);
};

} // namespace Filters
