#pragma once

#include "cf_manager.h"
#include "cf_types.h"
#include <vector>

namespace ConditionalFormatting {

    class RuleEvaluator {
    public:
        // Evaluates a single rule against a cell
        static bool evaluateRule(const CFRule& rule, const CFManager::EvalContext& ctx);
        
        // Resolves the final computed style for a cell given a prioritized list of rules
        static CFComputedStyle resolveStyles(const std::vector<CFRule>& rules, const CFManager::EvalContext& ctx);

    private:
        static bool evaluateCellValue(const CFRule& rule, const CFManager::EvalContext& ctx);
        static bool evaluateText(const CFRule& rule, const CFManager::EvalContext& ctx);
        static bool evaluateDate(const CFRule& rule, const CFManager::EvalContext& ctx);
        static bool evaluateBlank(const CFRule& rule, const CFManager::EvalContext& ctx);
        static bool evaluateFormula(const CFRule& rule, const CFManager::EvalContext& ctx);
        
        // These return true if they apply, and they also configure the dataBar/colorScale
        // output in the CFComputedStyle output buffer during resolveStyles.
        static bool evaluateDataBar(const CFRule& rule, const CFManager::EvalContext& ctx, CFComputedStyle& outStyle);
        static bool evaluateColorScale(const CFRule& rule, const CFManager::EvalContext& ctx, CFComputedStyle& outStyle);
        static bool evaluateIconSet(const CFRule& rule, const CFManager::EvalContext& ctx, CFComputedStyle& outStyle);
    };

}
