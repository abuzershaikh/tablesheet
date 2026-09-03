#ifndef RULE_PARSER_H
#define RULE_PARSER_H

#include "filter_rule.h"
#include <string>
#include <memory>
#include "../../json.hpp"

namespace Filters {

std::shared_ptr<FilterRule> parseRuleNode(const nlohmann::json& j);

class RuleParser {
public:
    // Parses a JSON string into a specific FilterRule (e.g. PhoneFilter, TextFilter)
    static std::shared_ptr<FilterRule> parse(const std::string& jsonRule);
};

} // namespace Filters

#endif // RULE_PARSER_H
