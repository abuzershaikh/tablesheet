/*
 * address_cleaner.cpp  —  Enterprise Address Tokenizer & Component Parser Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "address_cleaner.h"
#include <regex>
#include <algorithm>
#include <sstream>
#include <cctype>

namespace Filters {

AddressCleaner::AddressCleaner() {
    initDictionaries();
}

void AddressCleaner::initDictionaries() {
    _majorIndianCities = {
        "mumbai", "delhi", "bengaluru", "bangalore", "hyderabad", "chennai", "kolkata",
        "pune", "ahmedabad", "jaipur", "surat", "lucknow", "kanpur", "nagpur", "indore",
        "thane", "bhopal", "visakhapatnam", "patna", "vadodara", "ghaziabad", "ludhiana",
        "agra", "nashik", "faridabad", "meerut", "rajkot", "varanasi", "srinagar", "aurangabad",
        "dhanbad", "amritsar", "navi mumbai", "allahabad", "prayagraj", "ranchi", "howrah",
        "coimbatore", "jabalpur", "gwalior", "vijayawada", "jodhpur", "madurai", "raipur",
        "kota", "guwahati", "chandigarh", "solapur", "hubli", "dharwad", "bareilly", "moradabad",
        "mysore", "gurgaon", "gurugram", "aligarh", "jalandhar", "noida", "new york", "london", "dubai"
    };

    _majorIndianStates = {
        "maharashtra", "karnataka", "delhi", "tamil nadu", "tamilnadu", "uttar pradesh",
        "gujarat", "west bengal", "telangana", "andhra pradesh", "kerala", "rajasthan",
        "madhya pradesh", "bihar", "punjab", "haryana", "odisha", "jharkhand", "assam",
        "chhattisgarh", "uttarakhand", "goa", "himachal pradesh", "tripura", "meghalaya",
        "manipur", "nagaland", "california", "texas", "florida"
    };

    _streetKeywords = {"road", "rd", "marg", "street", "st", "lane", "ln", "avenue", "ave", "highway", "hwy", "cross", "main", "path", "gali", "chowk", "circle"};
    _buildingKeywords = {"tower", "towers", "heights", "apartment", "apartments", "apts", "apt", "residency", "enclave", "villa", "villas", "complex", "plaza", "house", "mansion", "bhavan", "niwas", "villa", "society", "soc"};
}

std::string AddressCleaner::extractPincode(const std::string& text) {
    // 6-digit Indian PIN (e.g. 400028 or 560 001) or 5-digit US ZIP (90210)
    std::regex pinRegex(R"(\b([1-9][0-9]{2}\s?[0-9]{3}|[0-9]{5})\b)");
    std::smatch match;
    if (std::regex_search(text, match, pinRegex)) {
        std::string pin = match.str();
        pin.erase(std::remove(pin.begin(), pin.end(), ' '), pin.end());
        return pin;
    }
    return "";
}

static std::string trimStr(const std::string& str) {
    if (str.empty()) return "";
    size_t start = 0;
    while (start < str.size() && (std::isspace(static_cast<unsigned char>(str[start])) || str[start] == '-' || str[start] == ',')) start++;
    if (start == str.size()) return "";
    size_t end = str.size() - 1;
    while (end > start && (std::isspace(static_cast<unsigned char>(str[end])) || str[end] == '-' || str[end] == ',')) end--;
    return str.substr(start, end - start + 1);
}

static std::string toTitle(const std::string& s) {
    std::string clean = trimStr(s);
    if (clean.empty()) return "";
    bool cap = true;
    for (size_t i = 0; i < clean.size(); i++) {
        if (std::isspace(static_cast<unsigned char>(clean[i])) || clean[i] == '.' || clean[i] == '/') {
            cap = true;
        } else if (cap) {
            clean[i] = static_cast<char>(std::toupper(static_cast<unsigned char>(clean[i])));
            cap = false;
        } else {
            clean[i] = static_cast<char>(std::tolower(static_cast<unsigned char>(clean[i])));
        }
    }
    return clean;
}

ParsedAddress AddressCleaner::parse(const std::string& rawAddress) const {
    ParsedAddress addr;
    addr.rawAddress = rawAddress;
    if (rawAddress.empty()) return addr;

    std::string s = rawAddress;

    // 1. Extract Pincode
    addr.pincode = extractPincode(s);
    if (!addr.pincode.empty()) {
        size_t pinPos = s.find(addr.pincode);
        if (pinPos != std::string::npos) {
            s.erase(pinPos, addr.pincode.length());
        }
    }

    // 2. Tokenize by commas / semicolons / slashes
    std::vector<std::string> tokens;
    std::string cur;
    for (char c : s) {
        if (c == ',' || c == ';' || c == '\n' || c == '\r') {
            std::string t = trimStr(cur);
            if (!t.empty()) tokens.push_back(t);
            cur.clear();
        } else {
            cur += c;
        }
    }
    if (!cur.empty()) {
        std::string t = trimStr(cur);
        if (!t.empty()) tokens.push_back(t);
    }

    if (tokens.empty()) return addr;

    // 3. Extract Flat / House / Plot No from first token
    std::regex flatRegex(R"(^(flat|house|plot|shop|room|office|suite|unit|bldg|no\.?|#)?\s*[\d]+[a-zA-Z\/-]*)", std::regex_constants::icase);
    std::smatch flatMatch;
    if (std::regex_search(tokens[0], flatMatch, flatRegex)) {
        addr.flatNo = toTitle(flatMatch.str());
        // Remove flat part from token
        tokens[0] = trimStr(tokens[0].substr(flatMatch.str().length()));
    }

    // 4. Match City, State, Country from tokens (right-to-left)
    std::vector<bool> consumed(tokens.size(), false);

    for (int i = static_cast<int>(tokens.size()) - 1; i >= 0; i--) {
        if (tokens[i].empty()) { consumed[i] = true; continue; }
        std::string lower = tokens[i];
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

        // Country
        if (addr.country.empty() && (lower == "india" || lower == "ind" || lower == "usa" || lower == "united states" || lower == "uk")) {
            addr.country = (lower == "india" || lower == "ind") ? "India" : toTitle(tokens[i]);
            consumed[i] = true;
            continue;
        }

        // State
        if (addr.state.empty()) {
            for (const auto& stateName : _majorIndianStates) {
                if (lower.find(stateName) != std::string::npos) {
                    addr.state = toTitle(stateName);
                    consumed[i] = true;
                    break;
                }
            }
            if (consumed[i]) continue;
        }

        // City
        if (addr.city.empty()) {
            for (const auto& cityName : _majorIndianCities) {
                if (lower.find(cityName) != std::string::npos) {
                    addr.city = toTitle(cityName);
                    consumed[i] = true;
                    break;
                }
            }
            if (consumed[i]) continue;
        }
    }

    // Default country if Indian city/state found
    if (addr.country.empty() && (!addr.city.empty() || !addr.state.empty() || (!addr.pincode.empty() && addr.pincode.length() == 6))) {
        addr.country = "India";
    }

    // 5. Match Building, Street, Locality from remaining tokens
    std::vector<std::string> remaining;
    for (size_t i = 0; i < tokens.size(); i++) {
        if (!consumed[i] && !tokens[i].empty()) {
            remaining.push_back(tokens[i]);
        }
    }

    for (const auto& rem : remaining) {
        std::string lower = rem;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

        bool isBuilding = false;
        for (const auto& bkw : _buildingKeywords) {
            if (lower.find(bkw) != std::string::npos) { isBuilding = true; break; }
        }

        bool isStreet = false;
        for (const auto& skw : _streetKeywords) {
            if (lower.find(skw) != std::string::npos) { isStreet = true; break; }
        }

        if (isBuilding && addr.building.empty()) {
            addr.building = toTitle(rem);
        } else if (isStreet && addr.street.empty()) {
            addr.street = toTitle(rem);
        } else if (addr.locality.empty()) {
            addr.locality = toTitle(rem);
        } else if (addr.street.empty()) {
            addr.street = toTitle(rem);
        } else {
            addr.locality += ", " + toTitle(rem);
        }
    }

    addr.isValid = !addr.city.empty() || !addr.pincode.empty() || !addr.street.empty() || !addr.building.empty();
    return addr;
}

std::string ParsedAddress::toJson() const {
    std::ostringstream o;
    o << "{";
    o << "\"flatNo\":\"" << flatNo << "\",";
    o << "\"building\":\"" << building << "\",";
    o << "\"street\":\"" << street << "\",";
    o << "\"locality\":\"" << locality << "\",";
    o << "\"city\":\"" << city << "\",";
    o << "\"state\":\"" << state << "\",";
    o << "\"pincode\":\"" << pincode << "\",";
    o << "\"country\":\"" << country << "\",";
    o << "\"isValid\":" << (isValid ? "true" : "false");
    o << "}";
    return o.str();
}

bool AddressCleaner::isAddress(const std::string& input) const {
    return parse(input).isValid;
}

} // namespace Filters
