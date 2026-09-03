#pragma once

#include "cf_rule.h"
#include <unordered_map>
#include <string>
#include <mutex>
#include <functional>

namespace ConditionalFormatting {

    class CFManager {
    public:
        // Adds or updates a rule for a specific sheet
        void addRule(const std::string& sheetId, const CFRule& rule);
        
        // Removes a rule by ID
        void removeRule(const std::string& sheetId, const std::string& ruleId);
        
        // Reorders a rule (changes priority)
        void reorderRule(const std::string& sheetId, const std::string& ruleId, int newPriority);
        
        // Returns a sorted list of rules (highest priority first) for a sheet
        std::vector<CFRule> getRulesForSheet(const std::string& sheetId) const;
        
        // Clear all rules for a sheet
        void clearRules(const std::string& sheetId);

        // Compute the final merged formatting for a specific cell, given its evaluated value
        // Note: The GridManager / Evaluator must provide a callback or context so the rule 
        // can evaluate formulas or query the sheet.
        struct EvalContext {
            std::string cellRef;
            int row;
            int col;
            std::string cellValue;
            double numericValue; // NaN if not numeric
            bool isBlank;
            
            // Callbacks for complex rules (Formulas, Top/Bottom, Avg, Duplicates)
            std::function<bool(const std::string&)> evaluateBooleanFormula;
            std::function<double(const std::string&)> getRangeMin;
            std::function<double(const std::string&)> getRangeMax;
            std::function<double(const std::string&)> getRangeAvg;
            std::function<bool(const std::string&)> isDuplicate;
            // Evaluates whether a cell is in the Top N values of a given range
            std::function<bool(const std::string&, int, bool isPercent, bool isTop)> isInTopBottom;
        };

    private:
        // Map from sheetId to a list of rules
        std::unordered_map<std::string, std::vector<CFRule>> sheetRules_;
        mutable std::mutex mutex_;
    };

}
