#include "rule_group.h"

namespace Filters {

RuleGroup::RuleGroup(GroupLogic logic) : logic(logic) {}

void RuleGroup::addRule(std::shared_ptr<FilterRule> rule) {
    if (rule) {
        rules.push_back(rule);
    }
}

bool RuleGroup::evaluate(const FilterContext& ctx) const {
    if (rules.empty()) return true;

    if (logic == GroupLogic::AND) {
        for (const auto& rule : rules) {
            if (!rule->evaluate(ctx)) return false;
        }
        return true;
    } else { // OR logic
        for (const auto& rule : rules) {
            if (rule->evaluate(ctx)) return true;
        }
        return false;
    }
}

} // namespace Filters
