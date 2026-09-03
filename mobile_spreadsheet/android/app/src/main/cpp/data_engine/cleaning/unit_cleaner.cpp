/*
 * unit_cleaner.cpp  —  Enterprise Unit Normalizer & Converter Engine Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "unit_cleaner.h"
#include <cctype>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <cmath>

namespace Filters {

UnitCleaner::UnitCleaner() {
    initConversionTables();
}

void UnitCleaner::initConversionTables() {
    // 1. Mass (Base: kg)
    _massToBaseKg["kg"] = 1.0;
    _massToBaseKg["kilogram"] = 1.0;
    _massToBaseKg["kilograms"] = 1.0;
    _massToBaseKg["kgs"] = 1.0;

    _massToBaseKg["g"] = 0.001;
    _massToBaseKg["gram"] = 0.001;
    _massToBaseKg["grams"] = 0.001;
    _massToBaseKg["gm"] = 0.001;
    _massToBaseKg["gms"] = 0.001;

    _massToBaseKg["mg"] = 0.000001;
    _massToBaseKg["milligram"] = 0.000001;
    _massToBaseKg["milligrams"] = 0.000001;

    _massToBaseKg["lb"] = 0.45359237;
    _massToBaseKg["lbs"] = 0.45359237;
    _massToBaseKg["pound"] = 0.45359237;
    _massToBaseKg["pounds"] = 0.45359237;

    _massToBaseKg["oz"] = 0.028349523125;
    _massToBaseKg["ounce"] = 0.028349523125;
    _massToBaseKg["ounces"] = 0.028349523125;

    _massToBaseKg["ton"] = 1000.0;
    _massToBaseKg["tonne"] = 1000.0;
    _massToBaseKg["tons"] = 1000.0;
    _massToBaseKg["quintal"] = 100.0;

    // 2. Volume (Base: L)
    _volumeToBaseL["l"] = 1.0;
    _volumeToBaseL["ltr"] = 1.0;
    _volumeToBaseL["liter"] = 1.0;
    _volumeToBaseL["liters"] = 1.0;
    _volumeToBaseL["litre"] = 1.0;
    _volumeToBaseL["litres"] = 1.0;

    _volumeToBaseL["ml"] = 0.001;
    _volumeToBaseL["milliliter"] = 0.001;
    _volumeToBaseL["milliliters"] = 0.001;
    _volumeToBaseL["millilitre"] = 0.001;
    _volumeToBaseL["millilitres"] = 0.001;

    _volumeToBaseL["gal"] = 3.78541;
    _volumeToBaseL["gallon"] = 3.78541;
    _volumeToBaseL["gallons"] = 3.78541;

    _volumeToBaseL["fl oz"] = 0.0295735;
    _volumeToBaseL["floz"] = 0.0295735;
    _volumeToBaseL["cup"] = 0.236588;
    _volumeToBaseL["cups"] = 0.236588;
    _volumeToBaseL["tbsp"] = 0.0147868;
    _volumeToBaseL["tsp"] = 0.00492892;

    // 3. Length (Base: m)
    _lengthToBaseM["m"] = 1.0;
    _lengthToBaseM["meter"] = 1.0;
    _lengthToBaseM["meters"] = 1.0;
    _lengthToBaseM["metre"] = 1.0;
    _lengthToBaseM["metres"] = 1.0;

    _lengthToBaseM["cm"] = 0.01;
    _lengthToBaseM["centimeter"] = 0.01;
    _lengthToBaseM["centimeters"] = 0.01;

    _lengthToBaseM["mm"] = 0.001;
    _lengthToBaseM["millimeter"] = 0.001;
    _lengthToBaseM["millimeters"] = 0.001;

    _lengthToBaseM["km"] = 1000.0;
    _lengthToBaseM["kilometer"] = 1000.0;
    _lengthToBaseM["kilometers"] = 1000.0;

    _lengthToBaseM["inch"] = 0.0254;
    _lengthToBaseM["inches"] = 0.0254;
    _lengthToBaseM["in"] = 0.0254;

    _lengthToBaseM["ft"] = 0.3048;
    _lengthToBaseM["feet"] = 0.3048;
    _lengthToBaseM["foot"] = 0.3048;

    _lengthToBaseM["yd"] = 0.9144;
    _lengthToBaseM["yard"] = 0.9144;
    _lengthToBaseM["yards"] = 0.9144;
}

std::string UnitCleaner::normalizeUnitString(const std::string& u) {
    std::string s = u;
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return std::tolower(c); });
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(0, 1);
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
    while (!s.empty() && (s.back() == '.' || s.back() == ',')) s.pop_back();
    return s;
}

ParsedUnit UnitCleaner::parse(const std::string& input) const {
    ParsedUnit res;
    res.rawInput = input;
    if (input.empty()) return res;

    // Split numeric prefix and unit suffix
    std::string s = input;
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(0, 1);
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();

    std::string numPart = "";
    std::string unitPart = "";
    bool inNumber = true;

    for (size_t i = 0; i < s.size(); i++) {
        char c = s[i];
        if (inNumber) {
            if (std::isdigit(static_cast<unsigned char>(c)) || c == '.' || c == '-' || c == '+' || c == ',') {
                if (c != ',') numPart += c; // skip thousand commas
            } else if (std::isspace(static_cast<unsigned char>(c))) {
                if (!numPart.empty()) {
                    inNumber = false;
                }
            } else if (std::isalpha(static_cast<unsigned char>(c))) {
                inNumber = false;
                unitPart += c;
            }
        } else {
            unitPart += c;
        }
    }

    if (numPart.empty() || unitPart.empty()) return res;

    double val = 0.0;
    try {
        val = std::stod(numPart);
    } catch (...) {
        return res;
    }

    std::string normUnit = normalizeUnitString(unitPart);
    res.magnitude = val;
    res.unit = normUnit;

    // Check Mass
    auto itM = _massToBaseKg.find(normUnit);
    if (itM != _massToBaseKg.end()) {
        res.category = UnitCategory::MASS;
        res.baseMagnitude = val * itM->second;
        res.baseUnit = "kg";
        res.isValid = true;
        return res;
    }

    // Check Volume
    auto itV = _volumeToBaseL.find(normUnit);
    if (itV != _volumeToBaseL.end()) {
        res.category = UnitCategory::VOLUME;
        res.baseMagnitude = val * itV->second;
        res.baseUnit = "L";
        res.isValid = true;
        return res;
    }

    // Check Length
    auto itL = _lengthToBaseM.find(normUnit);
    if (itL != _lengthToBaseM.end()) {
        res.category = UnitCategory::LENGTH;
        res.baseMagnitude = val * itL->second;
        res.baseUnit = "m";
        res.isValid = true;
        return res;
    }

    // Generic Count Units
    if (normUnit == "pcs" || normUnit == "piece" || normUnit == "pieces" ||
        normUnit == "box" || normUnit == "boxes" || normUnit == "pack" || normUnit == "packs" ||
        normUnit == "unit" || normUnit == "units" || normUnit == "item" || normUnit == "items") {
        res.category = UnitCategory::COUNT;
        res.baseMagnitude = val;
        res.baseUnit = "pcs";
        res.isValid = true;
        return res;
    }

    return res;
}

double UnitCleaner::convert(double value, const std::string& fromUnit, const std::string& toUnit) const {
    std::string from = normalizeUnitString(fromUnit);
    std::string to = normalizeUnitString(toUnit);

    if (from == to) return value;

    // Check Mass
    auto itFromM = _massToBaseKg.find(from);
    auto itToM = _massToBaseKg.find(to);
    if (itFromM != _massToBaseKg.end() && itToM != _massToBaseKg.end()) {
        double baseKg = value * itFromM->second;
        return baseKg / itToM->second;
    }

    // Check Volume
    auto itFromV = _volumeToBaseL.find(from);
    auto itToV = _volumeToBaseL.end();
    if (itFromV != _volumeToBaseL.end()) {
        auto itToV_found = _volumeToBaseL.find(to);
        if (itToV_found != _volumeToBaseL.end()) {
            double baseL = value * itFromV->second;
            return baseL / itToV_found->second;
        }
    }

    // Check Length
    auto itFromL = _lengthToBaseM.find(from);
    auto itToL = _lengthToBaseM.find(to);
    if (itFromL != _lengthToBaseM.end() && itToL != _lengthToBaseM.end()) {
        double baseM = value * itFromL->second;
        return baseM / itToL->second;
    }

    return value;
}

std::string ParsedUnit::format(const std::string& targetUnit) const {
    if (!isValid) return rawInput;

    double outVal = magnitude;
    std::string outUnit = unit;

    if (!targetUnit.empty()) {
        outVal = UnitCleaner::getInstance().convert(magnitude, unit, targetUnit);
        outUnit = targetUnit;
    }

    char buf[64];
    // Format nicely without trailing zeros
    snprintf(buf, sizeof(buf), "%g %s", outVal, outUnit.c_str());
    return buf;
}

std::string UnitCleaner::cleanAndConvert(const std::string& input, const std::string& targetUnit) const {
    ParsedUnit p = parse(input);
    if (!p.isValid) return input;
    return p.format(targetUnit);
}

bool UnitCleaner::hasUnit(const std::string& input) const {
    return parse(input).isValid;
}

} // namespace Filters
