#pragma once

#include <string>
#include <vector>
#include <optional>
#include <memory>
#include <variant>

namespace ConditionalFormatting {

    enum class RuleType {
        CellValue,
        Text,
        Date,
        Blank,
        Duplicate,
        TopBottom,
        Average,
        Formula,
        DataBar,
        ColorScale,
        IconSet,
        Static
    };

    enum class Operator {
        None,
        Equal,
        NotEqual,
        GreaterThan,
        GreaterThanOrEqual,
        LessThan,
        LessThanOrEqual,
        Between,
        NotBetween,
        ContainsText,
        NotContainsText,
        BeginsWith,
        EndsWith,
        IsBlank,
        IsNotBlank
    };

    enum class DateOperator {
        None,
        Today,
        Yesterday,
        Tomorrow,
        Last7Days,
        ThisMonth,
        LastMonth,
        NextMonth
    };

    enum class TopBottomOperator {
        None,
        Top10,
        Top10Percent,
        Bottom10,
        Bottom10Percent,
        TopN,
        BottomN,
        TopNPercent,
        BottomNPercent
    };

    enum class AverageOperator {
        None,
        AboveAverage,
        BelowAverage,
        EqualOrAboveAverage,
        EqualOrBelowAverage,
        StandardDeviation1Above,
        StandardDeviation1Below,
        StandardDeviation2Above,
        StandardDeviation2Below,
        StandardDeviation3Above,
        StandardDeviation3Below
    };

    enum class DuplicateOperator {
        None,
        DuplicateValues,
        UniqueValues
    };
    
    enum class IconSetType {
        Arrows3, Arrows4, Arrows5,
        TrafficLights3, TrafficLights4,
        Stars3,
        Flags3,
        Ratings4, Ratings5,
        UpDown
    };

    struct BorderStyle {
        bool show = false;
        std::string color = "#000000";
        std::string style = "solid"; // solid, dashed, dotted
    };

    struct BorderConfig {
        std::optional<BorderStyle> top;
        std::optional<BorderStyle> bottom;
        std::optional<BorderStyle> left;
        std::optional<BorderStyle> right;
    };

    struct CFStyle {
        std::optional<std::string> bgColor;
        std::optional<std::string> textColor;
        std::optional<bool> bold;
        std::optional<bool> italic;
        std::optional<bool> underline;
        std::optional<bool> strike;
        std::optional<std::string> numberFormat;
        
        // Advanced visuals
        std::optional<int> fontSize;
        std::optional<std::string> horizontalAlignment; // left, center, right
        std::optional<bool> wrapText;
        std::optional<BorderConfig> border;
        
        bool hasFormatting() const {
            return bgColor.has_value() || textColor.has_value() || bold.has_value() || 
                   italic.has_value() || underline.has_value() || strike.has_value() || 
                   numberFormat.has_value() || fontSize.has_value() || 
                   horizontalAlignment.has_value() || wrapText.has_value() || border.has_value();
        }
        
        // Merge styles: other overrides this, unless other's field is null
        void mergeWith(const CFStyle& other) {
            if (other.bgColor.has_value()) bgColor = other.bgColor;
            if (other.textColor.has_value()) textColor = other.textColor;
            if (other.bold.has_value()) bold = other.bold;
            if (other.italic.has_value()) italic = other.italic;
            if (other.underline.has_value()) underline = other.underline;
            if (other.strike.has_value()) strike = other.strike;
            if (other.numberFormat.has_value()) numberFormat = other.numberFormat;
            
            if (other.fontSize.has_value()) fontSize = other.fontSize;
            if (other.horizontalAlignment.has_value()) horizontalAlignment = other.horizontalAlignment;
            if (other.wrapText.has_value()) wrapText = other.wrapText;
            
            if (other.border.has_value()) {
                if (!border.has_value()) border = BorderConfig();
                if (other.border->top.has_value()) border->top = other.border->top;
                if (other.border->bottom.has_value()) border->bottom = other.border->bottom;
                if (other.border->left.has_value()) border->left = other.border->left;
                if (other.border->right.has_value()) border->right = other.border->right;
            }
        }
    };

    struct DataBarConfig {
        std::string positiveColor = "#4285F4"; // Default Blue
        std::string negativeColor = "#EA4335"; // Default Red
        bool gradientFill = true;
        std::optional<double> customMin;
        std::optional<double> customMax;
    };

    struct ColorScaleConfig {
        std::string minColor = "#F8696B"; // Red
        std::string midColor = "#FFEB84"; // Yellow
        std::string maxColor = "#63BE7B"; // Green
        bool twoColor = false;
        std::optional<double> customMin;
        std::optional<double> customMid;
        std::optional<double> customMax;
    };

    struct IconSetConfig {
        IconSetType type = IconSetType::TrafficLights3;
        bool reverseIconOrder = false;
        bool showIconOnly = false;
        std::vector<double> thresholds; 
        bool isPercent = true; 
    };
    
    struct CFComputedStyle {
        CFStyle style;
        std::optional<DataBarConfig> dataBar;
        std::optional<double> dataBarPercent; 
        std::optional<std::string> colorScaleColor;
        std::optional<std::string> iconName;
    };

}
