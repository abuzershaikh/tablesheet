#pragma once

#include "cf_types.h"
#include <string>
#include <vector>

namespace ConditionalFormatting {

    struct CFRule {
        std::string id;
        std::string sheetId; // If rules are per sheet
        int priority = 0; // Higher number = higher priority
        bool enabled = true;
        bool stopIfTrue = false;
        
        // Ranges this rule applies to. e.g. "A1:B10", "A:A"
        std::vector<std::string> ranges; 
        
        RuleType type;
        
        // --- Data fields depending on RuleType ---
        
        // For CellValue, Text, Blank
        Operator op = Operator::None;
        std::vector<std::string> values; // E.g. "10", "20" for between. Or "Apple" for contains
        
        // For Date
        DateOperator dateOp = DateOperator::None;
        
        // For TopBottom
        TopBottomOperator topBottomOp = TopBottomOperator::None;
        int topBottomValue = 10;
        
        // For Average
        AverageOperator averageOp = AverageOperator::None;
        
        // For Duplicate
        DuplicateOperator duplicateOp = DuplicateOperator::None;
        
        // Custom Formula (or formula behind TopBottom, Average, etc.)
        std::string formula;
        
        // --- Formatting Output ---
        CFStyle style;
        std::optional<DataBarConfig> dataBar;
        std::optional<ColorScaleConfig> colorScale;
        std::optional<IconSetConfig> iconSet;
        
        // Parse from JSON string (for dart interop)
        static CFRule fromJson(const std::string& jsonStr);
        std::string toJson() const;
    };

}
