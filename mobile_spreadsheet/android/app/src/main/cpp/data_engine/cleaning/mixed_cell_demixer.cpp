/*
 * mixed_cell_demixer.cpp  —  Universal Multi-Entity Cell De-Mixer Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "mixed_cell_demixer.h"
#include "extreme_cleaning_engine.h"
#include "phone_cleaner.h"
#include "email_cleaner.h"
#include <regex>
#include <cctype>

namespace Filters {

static std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\n\r|,;");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\n\r|,;");
    return str.substr(first, (last - first + 1));
}

DeMixedRecord MixedCellDeMixer::demixCell(const std::string& rawText) const {
    DeMixedRecord record;
    if (rawText.empty()) return record;

    std::string text = rawText;

    // 1. Extract Email
    std::regex emailRegex(R"([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})");
    std::smatch emailMatch;
    if (std::regex_search(text, emailMatch, emailRegex)) {
        record.email = emailMatch.str();
        text = emailMatch.prefix().str() + " " + emailMatch.suffix().str();
    }

    // 2. Extract GSTIN (15-char Indian Tax ID)
    std::regex gstinRegex(R"(\b[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b)");
    std::smatch gstinMatch;
    if (std::regex_search(text, gstinMatch, gstinRegex)) {
        record.gstin = gstinMatch.str();
        text = gstinMatch.prefix().str() + " " + gstinMatch.suffix().str();
    }

    // 3. Extract Phone Number
    std::regex phoneRegex(R"((\+?\d{1,3}[-.\s]?)?\(?\d{3,5}\)?[-.\s]?\d{3,5}[-.\s]?\d{3,5})");
    std::smatch phoneMatch;
    if (std::regex_search(text, phoneMatch, phoneRegex)) {
        std::string rawPhone = phoneMatch.str();
        // Validate digit count
        int digits = 0;
        for (char c : rawPhone) if (std::isdigit(static_cast<unsigned char>(c))) digits++;
        if (digits >= 7 && digits <= 15) {
            record.phone = PhoneCleaner::getInstance().clean(rawPhone);
            text = phoneMatch.prefix().str() + " " + phoneMatch.suffix().str();
        }
    }

    // 4. Extract Amount / Currency
    std::regex amountRegex(R"((?:₹|\$|€|£|¥|Rs\.?|INR|USD|EUR)\s*[-+]?[0-9]{1,3}(?:[,\.][0-9]{3})*(?:[,\.][0-9]{2})?|\b[0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?\s*(?:\/-|DR|CR)\b)");
    std::smatch amountMatch;
    if (std::regex_search(text, amountMatch, amountRegex)) {
        record.amount = ExtremeCleaningEngine::cleanNumericString(amountMatch.str(), true);
        text = amountMatch.prefix().str() + " " + amountMatch.suffix().str();
    }

    // 5. Deconstruct Remainder Text into Name and Address/Notes
    std::string remaining = trim(text);
    if (!remaining.empty()) {
        // If pipe or comma separator exists, first token is likely name, rest is address/notes
        size_t pipePos = remaining.find('|');
        if (pipePos != std::string::npos) {
            record.name = trim(remaining.substr(0, pipePos));
            record.addressOrNotes = trim(remaining.substr(pipePos + 1));
        } else {
            // Check if address keywords exist (Flat, Road, Street, Tower, Nagar, Mumbai, Delhi, etc.)
            std::regex addrKeywords(R"(\b(Flat|Plot|Sector|Street|Road|Nagar|Lane|Avenue|Floor|Building|Tower|Bldg|Apt|Near|Opp|City|State|Pincode|Pin)\b)", std::regex_constants::icase);
            std::smatch addrMatch;
            if (std::regex_search(remaining, addrMatch, addrKeywords)) {
                size_t kwPos = addrMatch.position();
                if (kwPos > 0) {
                    record.name = trim(remaining.substr(0, kwPos));
                    record.addressOrNotes = trim(remaining.substr(kwPos));
                } else {
                    record.addressOrNotes = remaining;
                }
            } else {
                record.name = remaining;
            }
        }
    }

    int entityCount = 0;
    if (!record.name.empty()) entityCount++;
    if (!record.phone.empty()) entityCount++;
    if (!record.email.empty()) entityCount++;
    if (!record.gstin.empty()) entityCount++;
    if (!record.amount.empty()) entityCount++;
    if (!record.addressOrNotes.empty()) entityCount++;

    record.isValid = (entityCount >= 2);
    return record;
}

DeMixColumnResult MixedCellDeMixer::demixColumn(const std::vector<std::string>& columnValues) const {
    DeMixColumnResult result;
    result.columnHeaders = {"Name", "Phone", "Email", "GSTIN", "Amount", "Address/Notes"};

    for (const auto& val : columnValues) {
        DeMixedRecord rec = demixCell(val);
        std::vector<std::string> row = {
            rec.name,
            rec.phone,
            rec.email,
            rec.gstin,
            rec.amount,
            rec.addressOrNotes
        };
        result.matrix.push_back(row);
        if (rec.isValid) {
            result.successfullyExtractedCount++;
        }
    }

    return result;
}

} // namespace Filters
