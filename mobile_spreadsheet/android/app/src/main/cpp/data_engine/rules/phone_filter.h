#ifndef PHONE_FILTER_H
#define PHONE_FILTER_H

#include "filter_rule.h"
#include <string>

namespace Filters {

enum class PhoneOperator {
    KeepCountry,
    RemoveCountry,
    StartsWith,
    EndsWith,
    Contains,
    Length,
    ValidNumber,
    InvalidNumber,
    DuplicateNumbers,
    UniqueNumbers,
    RemoveSpaces,
    Normalize,
    OnlyDigits
};

class PhoneFilter : public FilterRule {
public:
    PhoneFilter() = default;
    PhoneFilter(PhoneOperator op, const std::string& value = "");

    void addCondition(int opCode, const std::string& value);

    bool evaluate(const FilterContext& ctx) const override;
    
    // Normalize phone number string
    static std::string normalize(const std::string& input);

private:
    struct Condition {
        PhoneOperator op;
        std::string value;
    };
    std::vector<Condition> conditions;
};

} // namespace Filters

#endif // PHONE_FILTER_H
