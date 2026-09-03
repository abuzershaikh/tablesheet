#include "cf_manager.h"
#include <algorithm>

namespace ConditionalFormatting {

void CFManager::addRule(const std::string& sheetId, const CFRule& rule) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto& rules = sheetRules_[sheetId];
    auto it = std::find_if(rules.begin(), rules.end(), [&](const CFRule& r) { return r.id == rule.id; });
    if (it != rules.end()) {
        *it = rule;
    } else {
        rules.push_back(rule);
    }
    std::sort(rules.begin(), rules.end(), [](const CFRule& a, const CFRule& b) {
        return a.priority > b.priority;
    });
}

void CFManager::removeRule(const std::string& sheetId, const std::string& ruleId) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto& rules = sheetRules_[sheetId];
    rules.erase(std::remove_if(rules.begin(), rules.end(), [&](const CFRule& r) {
        return r.id == ruleId;
    }), rules.end());
}

void CFManager::reorderRule(const std::string& sheetId, const std::string& ruleId, int newPriority) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto& rules = sheetRules_[sheetId];
    for (auto& r : rules) {
        if (r.id == ruleId) {
            r.priority = newPriority;
            break;
        }
    }
    std::sort(rules.begin(), rules.end(), [](const CFRule& a, const CFRule& b) {
        return a.priority > b.priority;
    });
}

std::vector<CFRule> CFManager::getRulesForSheet(const std::string& sheetId) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = sheetRules_.find(sheetId);
    if (it != sheetRules_.end()) {
        return it->second;
    }
    return {};
}

void CFManager::clearRules(const std::string& sheetId) {
    std::lock_guard<std::mutex> lock(mutex_);
    sheetRules_.erase(sheetId);
}

}
