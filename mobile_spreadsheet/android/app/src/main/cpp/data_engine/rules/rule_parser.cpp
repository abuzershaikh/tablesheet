#include "rule_parser.h"
#include "phone_filter.h"
#include "text_filter.h"
#include "number_filter.h"
#include "rule_group.h"
#include "../../json.hpp"
#include <iostream>

using json = nlohmann::json;

namespace Filters {

std::shared_ptr<FilterRule> parseRuleNode(const json& j) {
    std::string type = j.value("type", "");
    
    if (type == "group") {
        GroupLogic logic = GroupLogic::AND;
        std::string logicStr = j.value("logic", "AND");
        if (logicStr == "OR") logic = GroupLogic::OR;
        
        auto group = std::make_shared<RuleGroup>(logic);
        if (j.contains("rules") && j["rules"].is_array()) {
            for (const auto& child : j["rules"]) {
                auto childRule = parseRuleNode(child);
                if (childRule) group->addRule(childRule);
            }
        }
        return group;
    } 
    else if (type == "text") {
        std::string opStr = j.value("operator", "equals");
        std::string val = j.value("value", "");
        
        TextOperator op = TextOperator::EQUALS;
        if (opStr == "contains") op = TextOperator::CONTAINS;
        else if (opStr == "startsWith") op = TextOperator::STARTS_WITH;
        else if (opStr == "endsWith") op = TextOperator::ENDS_WITH;
        else if (opStr == "notEquals") op = TextOperator::NOT_EQUALS;
        else if (opStr == "notContains") op = TextOperator::NOT_CONTAINS;
        
        return std::make_shared<TextFilter>(op, val);
    }
    else if (type == "number") {
        std::string opStr = j.value("operator", "equals");
        double val1 = j.value("value1", 0.0);
        double val2 = j.value("value2", 0.0);
        
        NumberOperator op = NumberOperator::EQUALS;
        if (opStr == "notEquals") op = NumberOperator::NOT_EQUALS;
        else if (opStr == "greaterThan") op = NumberOperator::GREATER_THAN;
        else if (opStr == "lessThan") op = NumberOperator::LESS_THAN;
        else if (opStr == "greaterEquals") op = NumberOperator::GREATER_EQUALS;
        else if (opStr == "lessEquals") op = NumberOperator::LESS_EQUALS;
        else if (opStr == "between") op = NumberOperator::BETWEEN;
        else if (opStr == "isEven") op = NumberOperator::IS_EVEN;
        else if (opStr == "isOdd") op = NumberOperator::IS_ODD;
        
        return std::make_shared<NumberFilter>(op, val1, val2);
    }
    else if (type == "phone") {
        auto filter = std::make_shared<PhoneFilter>();
        if (j.contains("conditions") && j["conditions"].is_array()) {
            for (const auto& cond : j["conditions"]) {
                std::string op = cond.value("operator", "");
                std::string valStr = "";
                if (cond.contains("value")) {
                    if (cond["value"].is_string()) valStr = cond["value"].get<std::string>();
                    else if (cond["value"].is_number()) valStr = std::to_string(cond["value"].get<int>());
                    else if (cond["value"].is_boolean()) valStr = cond["value"].get<bool>() ? "true" : "false";
                }
                
                int opCode = 0;
                if (op == "equals") opCode = 1;
                else if (op == "startsWith") opCode = 2;
                else if (op == "endsWith") opCode = 3;
                else if (op == "contains") opCode = 4;
                
                filter->addCondition(opCode, valStr);
            }
        }
        return filter;
    }
    
    return nullptr;
}

std::shared_ptr<FilterRule> RuleParser::parse(const std::string& jsonRule) {
    try {
        auto j = json::parse(jsonRule);
        
        // Root can have a version
        int version = j.value("version", 1);
        
        // Root is just a rule node itself
        return parseRuleNode(j);
        
    } catch (const std::exception& e) {
        return nullptr;
    }
}

} // namespace Filters
