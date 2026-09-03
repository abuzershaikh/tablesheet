#ifndef RULE_GROUP_H
#define RULE_GROUP_H

#include "filter_rule.h"
#include <vector>
#include <memory>
#include <string>

namespace Filters {

enum class GroupLogic {
    AND,
    OR
};

class RuleGroup : public FilterRule {
public:
    RuleGroup(GroupLogic logic = GroupLogic::AND);

    void addRule(std::shared_ptr<FilterRule> rule);

    bool evaluate(const FilterContext& ctx) const override;

private:
    GroupLogic logic;
    std::vector<std::shared_ptr<FilterRule>> rules;
};

} // namespace Filters

#endif // RULE_GROUP_H
