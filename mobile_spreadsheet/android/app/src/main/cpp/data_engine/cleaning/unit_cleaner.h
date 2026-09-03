/*
 * unit_cleaner.h  —  Enterprise Unit Normalizer & Converter Engine
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 *
 * CAPABILITIES:
 *   - Parses: "1.5 kg", "500g", "2.2 lbs", "250 ml", "1.5 Litre", "12 inches", "5.5 meters"
 *   - Normalizes to single standard base unit (e.g. all weights to kg or g)
 *   - Detects unit category: Mass, Volume, Length, Temperature, Units
 */
#pragma once
#include <string>
#include <vector>
#include <map>

namespace Filters {

enum class UnitCategory {
    MASS,
    VOLUME,
    LENGTH,
    COUNT,
    UNKNOWN
};

struct ParsedUnit {
    double magnitude = 0.0;
    std::string unit = "";
    UnitCategory category = UnitCategory::UNKNOWN;
    double baseMagnitude = 0.0; // Converted to base SI unit (kg, L, m, count)
    std::string baseUnit = "";
    bool isValid = false;
    std::string rawInput = "";

    std::string format(const std::string& targetUnit = "") const;
};

class UnitCleaner {
public:
    static UnitCleaner& getInstance() {
        static UnitCleaner instance;
        return instance;
    }

    /// Parses any string containing number and physical unit
    ParsedUnit parse(const std::string& input) const;

    /// Converts a value from one unit to another
    double convert(double value, const std::string& fromUnit, const std::string& toUnit) const;

    /// Cleans and standardizes a single unit string (e.g., "500 g" -> "0.5 kg")
    std::string cleanAndConvert(const std::string& input, const std::string& targetUnit = "") const;

    /// Checks if a string has a recognizable unit
    bool hasUnit(const std::string& input) const;

private:
    UnitCleaner();
    std::map<std::string, double> _massToBaseKg;
    std::map<std::string, double> _volumeToBaseL;
    std::map<std::string, double> _lengthToBaseM;

    void initConversionTables();
    static std::string normalizeUnitString(const std::string& u);
};

} // namespace Filters
