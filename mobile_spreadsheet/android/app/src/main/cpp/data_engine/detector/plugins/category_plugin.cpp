#include "category_plugin.h"
#include <cctype>
#include <algorithm>
#include <unordered_set>

namespace Filters {

static std::string toLower(const std::string& s) {
    std::string r = s;
    for (char& c : r) c = (char)std::tolower((unsigned char)c);
    return r;
}

float CategoryPlugin::detect(const std::string& val) const {
    if (val.empty() || val.size() > 50) return 0.0f;
    std::string str = toLower(val);

    // Dictionaries for domain categories
    static const std::unordered_set<std::string> units = {
        "kg", "g", "mg", "l", "ml", "ltr", "liter", "liters", "cm", "mm", "m", "km",
        "sqft", "lbs", "oz", "pcs", "box", "pkt", "unit", "units", "ton", "quintal"
    };

    static const std::unordered_set<std::string> produce = {
        "fruit", "fruits", "vegetable", "vegetables", "veggies", "apple", "banana",
        "orange", "mango", "tomato", "potato", "onion", "berry", "dairy", "meat",
        "grocery", "spices", "beverage", "snack"
    };

    static const std::unordered_set<std::string> techBrands = {
        "samsung", "apple", "iphone", "xiaomi", "redmi", "realme", "vivo", "oppo",
        "oneplus", "google", "pixel", "huawei", "nokia", "sony", "lg", "motorola"
    };

    static const std::unordered_set<std::string> hardwareMachines = {
        "lathe", "cnc", "motor", "pump", "compressor", "generator", "drill", "boiler",
        "transformer", "inverter", "sensor", "conveyor", "printer", "engine", "valve"
    };

    // Check if whole string matches a known category or unit
    if (units.count(str) || produce.count(str) || techBrands.count(str) || hardwareMachines.count(str)) {
        return 0.95f;
    }

    // Check words
    bool hasLetter = false;
    for (char c : val) {
        if (std::isdigit((unsigned char)c)) return 0.0f;
        if (std::isalpha((unsigned char)c)) hasLetter = true;
        else if (c != ' ' && c != '&' && c != '-' && c != '/') return 0.0f;
    }

    return hasLetter ? 0.60f : 0.0f;
}

} // namespace Filters

