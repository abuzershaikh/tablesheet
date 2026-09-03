#include "phone_filter.h"
#include <algorithm>
#include <cctype>

namespace Filters {

PhoneFilter::PhoneFilter(PhoneOperator op, const std::string& value) {
    conditions.push_back({op, value});
}

void PhoneFilter::addCondition(int opCode, const std::string& value) {
    conditions.push_back({static_cast<PhoneOperator>(opCode), value});
}

std::string PhoneFilter::normalize(const std::string& input) {
    std::string result;
    for (char c : input) {
        if (std::isdigit(c) || c == '+') {
            result += c;
        }
    }
    return result;
}

bool PhoneFilter::evaluate(const FilterContext& ctx) const {
    if (conditions.empty()) return true;

    std::string normCell = normalize(ctx.cellValue);
    
    // Evaluate all conditions (AND logic)
    for (const auto& cond : conditions) {
        bool pass = false;
        switch (cond.op) {
            case PhoneOperator::StartsWith:
                pass = normCell.find(cond.value) == 0; break;
            case PhoneOperator::EndsWith:
                if (cond.value.length() > normCell.length()) pass = false;
                else pass = normCell.rfind(cond.value) == (normCell.length() - cond.value.length()); 
                break;
            case PhoneOperator::Contains:
                pass = normCell.find(cond.value) != std::string::npos; break;
            case PhoneOperator::Length: {
                int targetLength = 0;
                try { targetLength = std::stoi(cond.value); } catch (...) {}
                int digitCount = 0;
                for (char c : normCell) if (std::isdigit(c)) digitCount++;
                pass = (digitCount == targetLength);
                break;
            }
            case PhoneOperator::KeepCountry:
                pass = normCell.find(cond.value) == 0; break;
            case PhoneOperator::ValidNumber: {
                int digitCount = 0;
                for (char c : normCell) if (std::isdigit(c)) digitCount++;
                pass = (digitCount >= 7 && digitCount <= 15);
                break;
            }
            case PhoneOperator::InvalidNumber: {
                int digitCount = 0;
                for (char c : normCell) if (std::isdigit(c)) digitCount++;
                pass = (digitCount < 7 || digitCount > 15);
                break;
            }
            case PhoneOperator::OnlyDigits: {
                pass = true;
                for (char c : ctx.cellValue) {
                    if (!std::isdigit(c) && c != '+' && !std::isspace(c) && c != '-') pass = false;
                }
                break;
            }
            default:
                pass = true; break;
        }
        if (!pass) return false; // Any condition fails, the whole filter fails
    }
    return true;
}

} // namespace Filters
