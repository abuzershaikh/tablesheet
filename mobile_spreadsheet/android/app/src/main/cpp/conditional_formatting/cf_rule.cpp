#include "cf_rule.h"
#include <sstream>
#include <iostream>
#include <algorithm>

namespace ConditionalFormatting {

    static std::string extractString(const std::string& json, const std::string& key) {
        std::string searchKey = "\"" + key + "\":\"";
        size_t pos = json.find(searchKey);
        if (pos == std::string::npos) {
            searchKey = "\"" + key + "\" : \"";
            pos = json.find(searchKey);
            if (pos == std::string::npos) return "";
        }
        pos += searchKey.length();
        size_t endPos = json.find("\"", pos);
        if (endPos != std::string::npos) {
            return json.substr(pos, endPos - pos);
        }
        return "";
    }

    static int extractInt(const std::string& json, const std::string& key) {
        std::string searchKey = "\"" + key + "\":";
        size_t pos = json.find(searchKey);
        if (pos == std::string::npos) return 0;
        pos += searchKey.length();
        size_t endPos = json.find_first_of(",}", pos);
        if (endPos != std::string::npos) {
            try { return std::stoi(json.substr(pos, endPos - pos)); } catch (...) { return 0; }
        }
        return 0;
    }

    static bool extractBool(const std::string& json, const std::string& key) {
        std::string searchKey = "\"" + key + "\":";
        size_t pos = json.find(searchKey);
        if (pos == std::string::npos) return false;
        pos += searchKey.length();
        return json.substr(pos, 4) == "true";
    }
    
    static std::optional<std::string> extractOptionalString(const std::string& json, const std::string& key) {
        std::string val = extractString(json, key);
        if (val.empty()) return std::nullopt;
        return val;
    }

    CFRule CFRule::fromJson(const std::string& jsonStr) {
        CFRule rule;
        rule.id = extractString(jsonStr, "id");
        rule.sheetId = extractString(jsonStr, "sheetId");
        rule.priority = extractInt(jsonStr, "priority");
        
        rule.enabled = jsonStr.find("\"enabled\":false") == std::string::npos;
        rule.stopIfTrue = extractBool(jsonStr, "stopIfTrue");
        
        std::string rangeStr = extractString(jsonStr, "range");
        if (!rangeStr.empty()) rule.ranges.push_back(rangeStr);

        // Also parse "ranges": ["A1:E1", "A2:E5"]
        size_t rangesPos = jsonStr.find("\"ranges\":");
        if (rangesPos != std::string::npos) {
            size_t openBracket = jsonStr.find("[", rangesPos);
            size_t closeBracket = jsonStr.find("]", rangesPos);
            if (openBracket != std::string::npos && closeBracket != std::string::npos && closeBracket > openBracket) {
                std::string inner = jsonStr.substr(openBracket + 1, closeBracket - openBracket - 1);
                size_t p = 0;
                while ((p = inner.find('"', p)) != std::string::npos) {
                    p++;
                    size_t ep = inner.find('"', p);
                    if (ep == std::string::npos) break;
                    std::string r = inner.substr(p, ep - p);
                    if (!r.empty() && std::find(rule.ranges.begin(), rule.ranges.end(), r) == rule.ranges.end()) {
                        rule.ranges.push_back(r);
                    }
                    p = ep + 1;
                }
            }
        }

        std::string typeStr = extractString(jsonStr, "type");
        std::string opStr = extractString(jsonStr, "op");

        if (typeStr == "Greater Than" || typeStr == "GreaterThan") {
            rule.type = RuleType::CellValue; rule.op = Operator::GreaterThan;
        } else if (typeStr == "Less Than" || typeStr == "LessThan") {
            rule.type = RuleType::CellValue; rule.op = Operator::LessThan;
        } else if (typeStr == "Equal To" || typeStr == "Equals" || typeStr == "Equal") {
            rule.type = RuleType::CellValue; rule.op = Operator::Equal;
        } else if (typeStr == "Between") {
            rule.type = RuleType::CellValue; rule.op = Operator::Between;
        } else if (typeStr == "Contains" || typeStr == "ContainsText") {
            rule.type = RuleType::Text; rule.op = Operator::ContainsText;
        } else if (typeStr == "Blank" || typeStr == "IsBlank") {
            rule.type = RuleType::Blank; rule.op = Operator::IsBlank;
        } else if (typeStr == "IsNotBlank") {
            rule.type = RuleType::Blank; rule.op = Operator::IsNotBlank;
        } else if (typeStr == "Static") {
            rule.type = RuleType::Static; rule.op = Operator::None;
        } else if (typeStr == "Custom Formula" || typeStr == "Formula") {
            rule.type = RuleType::Formula; rule.op = Operator::None;
        } else if (typeStr == "Data Bar" || typeStr == "DataBar") {
            rule.type = RuleType::DataBar; rule.op = Operator::None;
        } else if (typeStr == "Color Scale" || typeStr == "ColorScale") {
            rule.type = RuleType::ColorScale; rule.op = Operator::None;
        } else if (typeStr == "Icon Set" || typeStr == "IconSet") {
            rule.type = RuleType::IconSet; rule.op = Operator::None;
        } else if (typeStr == "CellValue") {
            rule.type = RuleType::CellValue;
            if (opStr == "GreaterThan") rule.op = Operator::GreaterThan;
            else if (opStr == "LessThan") rule.op = Operator::LessThan;
            else if (opStr == "Equals" || opStr == "Equal") rule.op = Operator::Equal;
            else if (opStr == "NotEqual") rule.op = Operator::NotEqual;
            else if (opStr == "Between") rule.op = Operator::Between;
            else rule.op = Operator::None;
        } else if (typeStr == "Text") {
            rule.type = RuleType::Text;
            if (opStr == "Contains" || opStr == "ContainsText") rule.op = Operator::ContainsText;
            else if (opStr == "BeginsWith") rule.op = Operator::BeginsWith;
            else if (opStr == "EndsWith") rule.op = Operator::EndsWith;
            else rule.op = Operator::ContainsText;
        } else {
            rule.type = RuleType::Static;
            rule.op = Operator::None;
        }

        std::string v1 = extractString(jsonStr, "value1");
        if (v1.empty()) v1 = extractString(jsonStr, "value");
        if (!v1.empty()) rule.values.push_back(v1);
        std::string v2 = extractString(jsonStr, "value2");
        if (!v2.empty()) rule.values.push_back(v2);

        rule.formula = extractString(jsonStr, "formula");
        if (rule.formula.empty() && typeStr == "Custom Formula" && !v1.empty()) {
            rule.formula = v1;
        }

        size_t stylePos = jsonStr.find("\"style\":");
        if (stylePos != std::string::npos) {
            size_t openBrace = jsonStr.find("{", stylePos);
            size_t closeBrace = jsonStr.find("}", stylePos);
            if (openBrace != std::string::npos && closeBrace != std::string::npos && closeBrace > openBrace) {
                std::string styleJson = jsonStr.substr(openBrace, closeBrace - openBrace + 1);
                rule.style.bgColor = extractOptionalString(styleJson, "bgColor");
                auto tc = extractOptionalString(styleJson, "textColor");
                if (!tc.has_value()) {
                    tc = extractOptionalString(styleJson, "fontColor");
                }
                rule.style.textColor = tc;
                rule.style.bold = extractBool(styleJson, "bold");
                rule.style.italic = extractBool(styleJson, "italic");
                rule.style.underline = extractBool(styleJson, "underline");
            }
        }

        size_t dbPos = jsonStr.find("\"dataBar\":{");
        if (dbPos != std::string::npos) {
            size_t dbEnd = jsonStr.find("}", dbPos);
            if (dbEnd != std::string::npos) {
                std::string dbJson = jsonStr.substr(dbPos, dbEnd - dbPos + 1);
                DataBarConfig db;
                db.gradientFill = extractBool(dbJson, "isGradient");
                std::string pc = extractString(dbJson, "positiveColor");
                if (!pc.empty()) db.positiveColor = pc;
                std::string nc = extractString(dbJson, "negativeColor");
                if (!nc.empty()) db.negativeColor = nc;
                rule.dataBar = db;
            }
        }
        
        return rule;
    }

    std::string CFRule::toJson() const {
        std::stringstream ss;
        ss << "{";
        ss << "\"id\":\"" << id << "\",";
        if (!ranges.empty()) ss << "\"range\":\"" << ranges[0] << "\",";
        ss << "\"sheetId\":\"" << sheetId << "\",";
        ss << "\"priority\":" << priority << ",";
        ss << "\"enabled\":" << (enabled ? "true" : "false") << ",";
        ss << "\"stopIfTrue\":" << (stopIfTrue ? "true" : "false") << ",";
        
        std::string typeStr = "Unknown";
        if (type == RuleType::CellValue) typeStr = "Greater Than";
        else if (type == RuleType::Text) typeStr = "Contains";
        else if (type == RuleType::Blank) typeStr = "Blank";
        else if (type == RuleType::Formula) typeStr = "Custom Formula";
        else if (type == RuleType::DataBar) typeStr = "Data Bar";
        else if (type == RuleType::ColorScale) typeStr = "Color Scale";
        else if (type == RuleType::IconSet) typeStr = "Icon Set";
        
        ss << "\"type\":\"" << typeStr << "\",";
        
        if (values.size() > 0) ss << "\"value1\":\"" << values[0] << "\",";
        if (values.size() > 1) ss << "\"value2\":\"" << values[1] << "\",";
        
        ss << "\"formula\":\"" << formula << "\",";
        
        ss << "\"style\":{";
        ss << "\"bgColor\":\"" << style.bgColor.value_or("") << "\",";
        ss << "\"textColor\":\"" << style.textColor.value_or("") << "\",";
        ss << "\"bold\":" << (style.bold.value_or(false) ? "true" : "false") << ",";
        ss << "\"italic\":" << (style.italic.value_or(false) ? "true" : "false") << ",";
        ss << "\"underline\":" << (style.underline.value_or(false) ? "true" : "false");
        ss << "}";
        
        ss << "}";
        return ss.str();
    }

}
