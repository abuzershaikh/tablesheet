#include "rule_evaluator.h"
#include "../grid_manager.h"
#include "../evaluator.h"
#include <cmath>
#include <algorithm>
#include <cctype>

namespace ConditionalFormatting {

static bool isCellInRange(const std::string& rangeStr, const std::string& cellRef, int row, int col) {
    if (rangeStr.empty() || rangeStr == cellRef) return true;
    size_t colon = rangeStr.find(':');
    if (colon == std::string::npos) {
        int r = 0, c = 0;
        if (Evaluator::parseCellCoordinates(rangeStr, r, c)) {
            return r == row && c == col;
        }
        return false;
    }
    std::string topLeft = rangeStr.substr(0, colon);
    std::string bottomRight = rangeStr.substr(colon + 1);
    int r1 = 0, c1 = 0, r2 = 0, c2 = 0;
    bool topIsRow = false, topIsCol = false;
    bool botIsRow = false, botIsCol = false;
    if (!Evaluator::parseCellCoordinates(topLeft, r1, c1, &topIsRow, &topIsCol) ||
        !Evaluator::parseCellCoordinates(bottomRight, r2, c2, &botIsRow, &botIsCol)) {
        return false;
    }
    if (topIsCol || botIsCol) { r1 = std::min(r1, r2); r2 = 9999; }
    if (topIsRow || botIsRow) { c1 = std::min(c1, c2); c2 = 255; }
    int minR = std::min(r1, r2), maxR = std::max(r1, r2);
    int minC = std::min(c1, c2), maxC = std::max(c1, c2);
    return row >= minR && row <= maxR && col >= minC && col <= maxC;
}

bool RuleEvaluator::evaluateRule(const CFRule& rule, const CFManager::EvalContext& ctx) {
    switch (rule.type) {
        case RuleType::CellValue: return evaluateCellValue(rule, ctx);
        case RuleType::Text: return evaluateText(rule, ctx);
        case RuleType::Date: return evaluateDate(rule, ctx);
        case RuleType::Blank: return evaluateBlank(rule, ctx);
        case RuleType::Formula: return evaluateFormula(rule, ctx);
        case RuleType::Duplicate: 
            if (ctx.isDuplicate) return ctx.isDuplicate(rule.ranges.empty() ? "" : rule.ranges[0]) == (rule.duplicateOp == DuplicateOperator::DuplicateValues);
            return false;
        case RuleType::TopBottom: 
            if (ctx.isInTopBottom) return ctx.isInTopBottom(rule.ranges.empty() ? "" : rule.ranges[0], rule.topBottomValue, 
                rule.topBottomOp == TopBottomOperator::Top10Percent || rule.topBottomOp == TopBottomOperator::Bottom10Percent || rule.topBottomOp == TopBottomOperator::TopNPercent || rule.topBottomOp == TopBottomOperator::BottomNPercent,
                rule.topBottomOp == TopBottomOperator::Top10 || rule.topBottomOp == TopBottomOperator::Top10Percent || rule.topBottomOp == TopBottomOperator::TopN || rule.topBottomOp == TopBottomOperator::TopNPercent);
            return false;
        case RuleType::Average: {
            if (!ctx.getRangeAvg) return false;
            double avg = ctx.getRangeAvg(rule.ranges.empty() ? "" : rule.ranges[0]);
            if (std::isnan(avg) || std::isnan(ctx.numericValue)) return false;
            switch(rule.averageOp) {
                case AverageOperator::AboveAverage: return ctx.numericValue > avg;
                case AverageOperator::BelowAverage: return ctx.numericValue < avg;
                case AverageOperator::EqualOrAboveAverage: return ctx.numericValue >= avg;
                case AverageOperator::EqualOrBelowAverage: return ctx.numericValue <= avg;
                default: return false; // Stdev ops omitted for brevity
            }
        }
        case RuleType::DataBar: 
        case RuleType::ColorScale: 
        case RuleType::IconSet: 
            return true; // Handle these in resolveStyles
        case RuleType::Static:
            return true; // Unconditional formatting
        default: return false;
    }
}

CFComputedStyle RuleEvaluator::resolveStyles(const std::vector<CFRule>& rules, const CFManager::EvalContext& ctx) {
    CFComputedStyle computed;
    for (const auto& rule : rules) {
        if (!rule.enabled) continue;

        bool inRange = false;
        if (rule.ranges.empty()) {
            inRange = true;
        } else {
            for (const auto& r : rule.ranges) {
                if (isCellInRange(r, ctx.cellRef, ctx.row, ctx.col)) {
                    inRange = true;
                    break;
                }
            }
        }
        if (!inRange) continue;

        bool applies = false;
        if (rule.type == RuleType::DataBar) {
            applies = evaluateDataBar(rule, ctx, computed);
        } else if (rule.type == RuleType::ColorScale) {
            applies = evaluateColorScale(rule, ctx, computed);
        } else if (rule.type == RuleType::IconSet) {
            applies = evaluateIconSet(rule, ctx, computed);
        } else {
            applies = evaluateRule(rule, ctx);
            if (applies) {
                computed.style.mergeWith(rule.style);
            }
        }

        if (applies && rule.stopIfTrue) {
            break;
        }
    }
    return computed;
}

static bool safeStod(const std::string& str, double& outVal) {
    if (str.empty()) return false;
    try {
        size_t idx = 0;
        outVal = std::stod(str, &idx);
        return idx == str.length();
    } catch (...) {
        return false;
    }
}

bool RuleEvaluator::evaluateCellValue(const CFRule& rule, const CFManager::EvalContext& ctx) {
    if (std::isnan(ctx.numericValue)) return false;
    if (rule.values.empty()) return false;
    double val1 = 0.0;
    if (!safeStod(rule.values[0], val1)) return false;

    switch(rule.op) {
        case Operator::Equal: return ctx.numericValue == val1;
        case Operator::NotEqual: return ctx.numericValue != val1;
        case Operator::GreaterThan: return ctx.numericValue > val1;
        case Operator::GreaterThanOrEqual: return ctx.numericValue >= val1;
        case Operator::LessThan: return ctx.numericValue < val1;
        case Operator::LessThanOrEqual: return ctx.numericValue <= val1;
        case Operator::Between: {
            if (rule.values.size() < 2) return false;
            double val2 = 0.0;
            if (!safeStod(rule.values[1], val2)) return false;
            return ctx.numericValue >= val1 && ctx.numericValue <= val2;
        }
        case Operator::NotBetween: {
            if (rule.values.size() < 2) return false;
            double val2 = 0.0;
            if (!safeStod(rule.values[1], val2)) return false;
            return ctx.numericValue < val1 || ctx.numericValue > val2;
        }
        default: return false;
    }
}

bool RuleEvaluator::evaluateText(const CFRule& rule, const CFManager::EvalContext& ctx) {
    if (rule.values.empty()) return false;
    const std::string& target = rule.values[0];
    switch (rule.op) {
        case Operator::ContainsText: return ctx.cellValue.find(target) != std::string::npos;
        case Operator::NotContainsText: return ctx.cellValue.find(target) == std::string::npos;
        case Operator::BeginsWith: return ctx.cellValue.rfind(target, 0) == 0;
        case Operator::EndsWith: 
            if (target.length() > ctx.cellValue.length()) return false;
            return std::equal(target.rbegin(), target.rend(), ctx.cellValue.rbegin());
        default: return false;
    }
}

bool RuleEvaluator::evaluateDate(const CFRule& rule, const CFManager::EvalContext& ctx) {
    if (std::isnan(ctx.numericValue)) return false;
    // Excel dates are days since 1900. Approx 45000 for year 2023+.
    // A simple stub for "Today" could be checking if it's within a reasonable date range.
    // In a real app we'd get current time and compute Excel serial.
    // For now, if it's Date type, we assume it matches if it's a valid date > 0
    return ctx.numericValue > 0 && ctx.numericValue < 100000; 
}

bool RuleEvaluator::evaluateBlank(const CFRule& rule, const CFManager::EvalContext& ctx) {
    if (rule.op == Operator::IsBlank) return ctx.isBlank;
    if (rule.op == Operator::IsNotBlank) return !ctx.isBlank;
    return false;
}

bool RuleEvaluator::evaluateFormula(const CFRule& rule, const CFManager::EvalContext& ctx) {
    if (!ctx.evaluateBooleanFormula) return false;
    
    std::string formulaToEval = rule.formula;
    if (!rule.ranges.empty()) {
        int anchorRow = 0, anchorCol = 0;
        std::string rangeStr = rule.ranges[0];
        size_t colon = rangeStr.find(':');
        if (colon != std::string::npos) {
            rangeStr = rangeStr.substr(0, colon);
        }
        
        // Quick parse for anchor
        int i = 0;
        int col = 0;
        while (i < rangeStr.length() && std::isalpha(rangeStr[i])) {
            col = col * 26 + (std::toupper(rangeStr[i]) - 'A' + 1);
            i++;
        }
        col--;
        if (col < 0) col = 0;
        int row = 0;
        if (i < rangeStr.length()) {
            try { row = std::stoi(rangeStr.substr(i)) - 1; } catch(...) {}
        }
        if (row < 0) row = 0;
        
        int rowOffset = ctx.row - row;
        int colOffset = ctx.col - col;
        
        if (rowOffset != 0 || colOffset != 0) {
            formulaToEval = GridManager::getInstance().shiftFormula(formulaToEval, rowOffset, colOffset);
        }
    }
    
    return ctx.evaluateBooleanFormula(formulaToEval);
}

bool RuleEvaluator::evaluateDataBar(const CFRule& rule, const CFManager::EvalContext& ctx, CFComputedStyle& outStyle) {
    if (!rule.dataBar.has_value() || std::isnan(ctx.numericValue)) return false;
    if (!ctx.getRangeMin || !ctx.getRangeMax) return false;
    
    double min = rule.dataBar->customMin.has_value() ? rule.dataBar->customMin.value() : ctx.getRangeMin(rule.ranges.empty() ? "" : rule.ranges[0]);
    double max = rule.dataBar->customMax.has_value() ? rule.dataBar->customMax.value() : ctx.getRangeMax(rule.ranges.empty() ? "" : rule.ranges[0]);
    
    outStyle.dataBar = rule.dataBar;
    if (max == min) outStyle.dataBarPercent = 0.5;
    else outStyle.dataBarPercent = std::clamp((ctx.numericValue - min) / (max - min), 0.0, 1.0);
    return true;
}

// Helper to interpolate hex colors
static std::string interpolateColor(const std::string& c1, const std::string& c2, double t) {
    if (c1.length() < 7 || c2.length() < 7) return c1;
    auto parseHex = [](const std::string& hex) {
        return std::stoi(hex.substr(1), nullptr, 16);
    };
    int val1 = parseHex(c1);
    int val2 = parseHex(c2);
    int r1 = (val1 >> 16) & 0xFF, g1 = (val1 >> 8) & 0xFF, b1 = val1 & 0xFF;
    int r2 = (val2 >> 16) & 0xFF, g2 = (val2 >> 8) & 0xFF, b2 = val2 & 0xFF;
    int r = r1 + (r2 - r1) * t;
    int g = g1 + (g2 - g1) * t;
    int b = b1 + (b2 - b1) * t;
    char buf[10];
    snprintf(buf, sizeof(buf), "#%02X%02X%02X", r, g, b);
    return std::string(buf);
}

bool RuleEvaluator::evaluateColorScale(const CFRule& rule, const CFManager::EvalContext& ctx, CFComputedStyle& outStyle) {
    if (std::isnan(ctx.numericValue)) return false;
    if (!ctx.getRangeMin || !ctx.getRangeMax) return false;
    
    double min = ctx.getRangeMin(rule.ranges.empty() ? "" : rule.ranges[0]);
    double max = ctx.getRangeMax(rule.ranges.empty() ? "" : rule.ranges[0]);
    double t = (max == min) ? 0.5 : std::clamp((ctx.numericValue - min) / (max - min), 0.0, 1.0);
    
    std::string minColor = rule.colorScale.has_value() ? rule.colorScale->minColor : "#F8696B";
    std::string midColor = rule.colorScale.has_value() ? rule.colorScale->midColor : "#FFEB84";
    std::string maxColor = rule.colorScale.has_value() ? rule.colorScale->maxColor : "#63BE7B";
    
    if (t < 0.5) {
        outStyle.style.bgColor = interpolateColor(minColor, midColor, t * 2.0);
    } else {
        outStyle.style.bgColor = interpolateColor(midColor, maxColor, (t - 0.5) * 2.0);
    }
    return true;
}

bool RuleEvaluator::evaluateIconSet(const CFRule& rule, const CFManager::EvalContext& ctx, CFComputedStyle& outStyle) {
    if (std::isnan(ctx.numericValue)) return false;
    if (!ctx.getRangeMin || !ctx.getRangeMax) return false;
    
    double min = ctx.getRangeMin(rule.ranges.empty() ? "" : rule.ranges[0]);
    double max = ctx.getRangeMax(rule.ranges.empty() ? "" : rule.ranges[0]);
    double percent = (max == min) ? 0.5 : std::clamp((ctx.numericValue - min) / (max - min), 0.0, 1.0);
    
    if (percent < 0.33) outStyle.iconName = "down";
    else if (percent < 0.66) outStyle.iconName = "flat";
    else outStyle.iconName = "up";
    
    return true;
}

}
