/*
 * id_plugin.cpp  —  Indian Document ID Detection Logic
 *
 * DETECTION PATTERNS:
 *   PAN:     Regex: [A-Z]{5}[0-9]{4}[A-Z]{1}
 *   GST:     15 chars: digits(2) + letters(10) + digits(1) + alphanumeric(1) + Z + digit
 *   Aadhaar: 12 digits (with optional spaces every 4 digits)
 *   IFSC:    4 letters + '0' + 6 alphanumeric
 */
#include "id_plugin.h"
#include <cctype>
#include <regex>

namespace Filters {

bool IdPlugin::isPAN(const std::string& val) {
    // PAN: AAAAA9999A — 5 uppercase letters, 4 digits, 1 uppercase letter
    if (val.size() != 10) return false;
    for (int i = 0; i < 5; i++) if (!std::isupper((unsigned char)val[i])) return false;
    for (int i = 5; i < 9; i++) if (!std::isdigit((unsigned char)val[i])) return false;
    if (!std::isupper((unsigned char)val[9])) return false;
    return true;
}

bool IdPlugin::isGST(const std::string& val) {
    // GST: 15 chars — 2 digits + 10 PAN chars + 1 digit + 1 alpha + 'Z' + 1 digit
    if (val.size() != 15) return false;
    if (!std::isdigit((unsigned char)val[0]) || !std::isdigit((unsigned char)val[1])) return false;
    // chars 2-11 should be PAN-like (5 letters + 4 digits + 1 letter)
    std::string panPart = val.substr(2, 10);
    if (!isPAN(panPart)) return false;
    if (!std::isdigit((unsigned char)val[12])) return false;
    if (!std::isalnum((unsigned char)val[13])) return false;
    if (val[14] != 'Z' && !std::isdigit((unsigned char)val[14])) return false;
    return true;
}

bool IdPlugin::isAadhaar(const std::string& val) {
    // Aadhaar: 12 digits (spaces allowed after every 4)
    std::string digits;
    for (char c : val) {
        if (std::isdigit(c)) digits += c;
        else if (c != ' ') return false;
    }
    return digits.size() == 12;
}

bool IdPlugin::isIFSC(const std::string& val) {
    // IFSC: 4 uppercase letters + '0' + 6 alphanumeric
    if (val.size() != 11) return false;
    for (int i = 0; i < 4; i++) if (!std::isupper((unsigned char)val[i])) return false;
    if (val[4] != '0') return false;
    for (int i = 5; i < 11; i++) if (!std::isalnum((unsigned char)val[i])) return false;
    return true;
}

float IdPlugin::detect(const std::string& val) const {
    if (val.size() < 8) return 0.0f;
    std::string upper = val;
    for (char& c : upper) c = std::toupper((unsigned char)c);

    if (isPAN(upper))     return 1.0f;
    if (isGST(upper))     return 1.0f;
    if (isAadhaar(upper)) return 0.98f;
    if (isIFSC(upper))    return 0.98f;
    return 0.0f;
}

} // namespace Filters
