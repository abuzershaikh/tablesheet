/*
 * column_analyzer.cpp  —  Column Analysis Engine (Phase 2 — Full Enterprise)
 *
 * PHASE 2 FEATURES:
 *   ✅ Composite type detection (PRIMARY + SECONDARY)
 *   ✅ Full statistics: duplicates, invalid, format_consistency, quality score
 *   ✅ Explainability: reason per detection
 *   ✅ Knowledge Tags per data type
 *   ✅ Ranked recommended actions
 *   ✅ AI-Optimized JSON output
 *
 * FLOW:
 *   1. getRawGrid() → parse cell refs for target column
 *   2. Per cell: DataDetector.detect() → collect all candidates
 *   3. Aggregate → dominant type + secondary type
 *   4. Compute statistics: duplicate set, invalid count, format consistency
 *   5. Build issues list + recommended actions + knowledge tags
 *   6. Serialize to AI-optimized JSON
 *
 * RELATED FILES:
 *   GridManager:    grid_manager.h  (top-level cpp/)
 *   DataDetector:   data_engine/detector/data_detector.h
 *   DataCleaner:    data_engine/cleaning/data_cleaner.h
 *   SheetSummarizer:data_engine/analyzer/sheet_summarizer.h (calls this)
 *   FFI export:     ffi_bridge.cpp → analyzeColumn()
 */
#include "column_analyzer.h"
#include "../detector/data_detector.h"
#include "../../grid_manager.h"
#include <sstream>
#include <map>
#include <set>
#include <algorithm>
#include <cmath>
#include <cctype>

namespace Filters {

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

static int colLetterToIdx(const std::string& col) {
    int idx = 0;
    for (char c : col) idx = idx * 26 + (std::toupper((unsigned char)c) - 'A' + 1);
    return idx - 1;
}

// Escape JSON string (handle quotes and backslashes)
static std::string jsonEsc(const std::string& s) {
    std::string r;
    for (char c : s) {
        if (c == '"')  r += "\\\"";
        else if (c == '\\') r += "\\\\";
        else if (c == '\n') r += "\\n";
        else if (c == '\r') r += "\\r";
        else r += c;
    }
    return r;
}

// ─────────────────────────────────────────────────────────────────────────────
// Static helpers
// ─────────────────────────────────────────────────────────────────────────────

std::string ColumnAnalyzer::dataTypeToString(DataType type) {
    switch(type) {
        case DataType::PHONE:    return "Phone Number";
        case DataType::EMAIL:    return "Email Address";
        case DataType::DATE:     return "Date";
        case DataType::DATETIME: return "Date & Time";
        case DataType::CURRENCY: return "Currency / Price";
        case DataType::NUMBER:   return "Number";
        case DataType::TEXT:     return "Text";
        case DataType::BOOLEAN:  return "Boolean";
        case DataType::URL:      return "URL / Link";
        case DataType::UUID:     return "ID / Document";
        case DataType::BLANK:    return "Blank";
        case DataType::FORMULA:  return "Formula";
        case DataType::MIXED:    return "Mixed Data";
        case DataType::PAN:      return "PAN Card";
        case DataType::GST:      return "GST Number";
        case DataType::AADHAAR:  return "Aadhaar Number";
        case DataType::IP_ADDRESS: return "IP Address";
        case DataType::MAC_ADDRESS: return "MAC Address";
        default:                 return "Unknown";
    }
}

std::string ColumnAnalyzer::suggestReason(DataType type, float confidence,
                                           int total, int matchCount) {
    std::string pct = std::to_string((int)(confidence * 100)) + "%";
    std::string cnt = std::to_string(matchCount) + "/" + std::to_string(total);
    switch(type) {
        case DataType::PHONE:
            return cnt + " cells match Indian/international phone pattern (" + pct + " confidence)";
        case DataType::EMAIL:
            return cnt + " cells contain '@' and valid domain (" + pct + " confidence)";
        case DataType::CURRENCY:
            return cnt + " cells have currency symbols or comma-formatted numbers (" + pct + " confidence)";
        case DataType::DATE:
            return cnt + " cells match date pattern (slashes/dashes) (" + pct + " confidence)";
        case DataType::NUMBER:
            return cnt + " cells are pure numeric (" + pct + " confidence)";
        case DataType::UUID:
            return cnt + " cells match Indian ID format (PAN/GST/Aadhaar/IFSC) (" + pct + " confidence)";
        case DataType::URL:
            return cnt + " cells start with http/https/www (" + pct + " confidence)";
        case DataType::BOOLEAN:
            return cnt + " cells are true/false values (" + pct + " confidence)";
        case DataType::TEXT:
            return cnt + " cells are plain text (" + pct + " confidence)";
        case DataType::MIXED:
            return "Column has mixed data types — no single dominant type found";
        default:
            return pct + " of cells match this type";
    }
}

std::vector<std::string> ColumnAnalyzer::getKnowledgeTags(DataType type) {
    switch(type) {
        case DataType::PHONE:    return {"Contact", "PII", "Customer", "Telecom"};
        case DataType::EMAIL:    return {"Contact", "PII", "Digital", "Communication"};
        case DataType::CURRENCY: return {"Finance", "Transaction", "Monetary", "Accounting"};
        case DataType::DATE:     return {"Temporal", "Timeline", "Audit"};
        case DataType::DATETIME: return {"Temporal", "Audit", "Log"};
        case DataType::NUMBER:   return {"Numeric", "Quantitative", "Metric"};
        case DataType::URL:      return {"Digital", "Web", "Reference"};
        case DataType::UUID:     return {"ID", "Identity", "Reference"};
        case DataType::BOOLEAN:  return {"Flag", "Status", "Binary"};
        case DataType::PAN:      return {"Finance", "Tax", "PII", "Government", "ID"};
        case DataType::GST:      return {"Finance", "Tax", "Business", "Government"};
        case DataType::AADHAAR:  return {"PII", "Government", "ID", "Biometric"};
        case DataType::TEXT:     return {"Descriptive", "Label"};
        case DataType::MIXED:    return {"Mixed", "NeedsReview"};
        default:                 return {"General"};
    }
}

std::vector<std::string> ColumnAnalyzer::buildRecommendedActions(
    DataType type, const ColumnStatistics& stats) {
    std::vector<std::string> actions;

    // Type-specific primary action
    switch(type) {
        case DataType::PHONE:
            actions.push_back("normalize_phone");     // +91XXXXXXXXXX format
            break;
        case DataType::EMAIL:
            actions.push_back("normalize_email");     // lowercase + trim
            break;
        case DataType::CURRENCY:
            actions.push_back("extract_currency");    // strip symbols, extract number
            break;
        case DataType::DATE:
            actions.push_back("normalize_date");      // DD-MM-YYYY
            break;
        case DataType::TEXT:
            actions.push_back("clean_text");          // trim + collapse spaces
            break;
        case DataType::MIXED:
            actions.push_back("inspect_and_split");   // review mixed column
            break;
        default:
            break;
    }

    // Quality-based additional actions
    if (stats.duplicateCount > 0)
        actions.push_back("remove_duplicates");
    if (stats.blankCells > 0)
        actions.push_back("fill_or_flag_blanks");
    if (stats.invalidCount > 0)
        actions.push_back("validate_and_flag_invalid");
    if (stats.formatConsistency < 70)
        actions.push_back("standardize_format");

    return actions;
}

DataType ColumnAnalyzer::findSecondaryType(
    const std::vector<DetectionCandidate>& candidates, DataType primary) {
    for (const auto& c : candidates) {
        if (c.type != primary && c.confidence >= 0.5f) {
            return c.type;
        }
    }
    return DataType::UNKNOWN;
}

int ColumnAnalyzer::computeFormatConsistency(
    const std::vector<std::string>& values, DataType type) {
    if (values.empty()) return 100;
    if (type == DataType::TEXT || type == DataType::MIXED) return 50;

    // For phone: check uniform length
    if (type == DataType::PHONE) {
        std::map<size_t, int> lenCount;
        for (const auto& v : values) {
            std::string digits;
            for (char c : v) if (std::isdigit((unsigned char)c)) digits += c;
            lenCount[digits.size()]++;
        }
        auto maxIt = std::max_element(lenCount.begin(), lenCount.end(),
            [](const auto& a, const auto& b){ return a.second < b.second; });
        return (int)((float)maxIt->second / values.size() * 100.0f);
    }

    // For numbers: check decimal uniformity
    if (type == DataType::NUMBER || type == DataType::CURRENCY) {
        int withDecimal = 0;
        for (const auto& v : values) {
            if (v.find('.') != std::string::npos) withDecimal++;
        }
        int without = (int)values.size() - withDecimal;
        return 100 - (int)((float)std::min(withDecimal, without) / values.size() * 100.0f);
    }

    return 75; // Default moderate consistency
}

float ColumnAnalyzer::computeQualityScore(const ColumnStatistics& stats, int total) {
    if (total == 0) return 0.0f;
    float score = 100.0f;
    int grandTotal = total + stats.blankCells;
    if (grandTotal == 0) return 0.0f;

    // Penalize blanks: up to -25 points
    score -= (float)stats.blankCells / grandTotal * 25.0f;
    // Penalize duplicates: up to -20 points
    score -= (float)stats.duplicateCount / grandTotal * 20.0f;
    // Penalize invalid: up to -25 points
    score -= (float)stats.invalidCount / grandTotal * 25.0f;
    // Penalize dirty: up to -20 points
    score -= (float)stats.dirtyCount / grandTotal * 20.0f;
    // Format consistency bonus/penalty: -10 to 0
    score -= (float)(100 - stats.formatConsistency) / 100.0f * 10.0f;

    return std::max(0.0f, std::min(100.0f, score));
}

// Robust JSON map parser handling escaped quotes and special characters
static std::map<std::string, std::string> parseGridJson(const std::string& json) {
    std::map<std::string, std::string> res;
    if (json.empty() || json == "{}") return res;

    size_t i = 0;
    while (i < json.size()) {
        size_t kStart = json.find('"', i);
        if (kStart == std::string::npos) break;
        size_t kEnd = json.find('"', kStart + 1);
        if (kEnd == std::string::npos) break;

        std::string key = json.substr(kStart + 1, kEnd - kStart - 1);
        i = kEnd + 1;

        size_t colon = json.find(':', i);
        if (colon == std::string::npos) break;
        i = colon + 1;

        while (i < json.size() && std::isspace((unsigned char)json[i])) i++;
        if (i >= json.size()) break;

        std::string val;
        if (json[i] == '"') {
            i++; // skip opening quote
            while (i < json.size()) {
                if (json[i] == '\\' && i + 1 < json.size()) {
                    char nextChar = json[i + 1];
                    if (nextChar == '"') val += '"';
                    else if (nextChar == '\\') val += '\\';
                    else if (nextChar == 'n') val += '\n';
                    else if (nextChar == 'r') val += '\r';
                    else if (nextChar == 't') val += '\t';
                    else val += nextChar;
                    i += 2;
                } else if (json[i] == '"') {
                    i++; // closing quote
                    break;
                } else {
                    val += json[i];
                    i++;
                }
            }
        } else {
            size_t valEnd = json.find_first_of(",}", i);
            if (valEnd == std::string::npos) valEnd = json.size();
            val = json.substr(i, valEnd - i);
            while (!val.empty() && std::isspace((unsigned char)val.back())) val.pop_back();
            i = valEnd;
        }

        res[key] = val;
    }
    return res;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main analyze() function
// ─────────────────────────────────────────────────────────────────────────────

ColumnAnalysisResult ColumnAnalyzer::analyze(const std::string& columnLetter,
                                              bool includeHeader) const {
    ColumnAnalysisResult result;
    result.columnLetter = columnLetter;
    result.dominantType = DataType::UNKNOWN;
    result.secondaryType = DataType::UNKNOWN;
    result.typeConfidence = 0.0f;
    result.stats = ColumnStatistics{};

    std::string colUpper = columnLetter;
    for (char& c : colUpper) c = std::toupper((unsigned char)c);

    // Get raw grid JSON from GridManager
    std::string rawGrid = GridManager::getInstance().getRawGrid();
    if (rawGrid.empty() || rawGrid == "{}") {
        result.issues.push_back("Sheet is empty");
        result.detectionReason = "No data found";
        return result;
    }

    auto gridMap = parseGridJson(rawGrid);
    int lastRow = GridManager::getInstance().getLastRow();

    std::string headerKey = colUpper + "1";
    if (gridMap.count(headerKey)) {
        result.headerName = gridMap[headerKey];
    }

    std::map<int, std::string> rowValues;
    int startRow = includeHeader ? 2 : 1;
    for (int r = startRow; r <= lastRow; r++) {
        std::string ref = colUpper + std::to_string(r);
        if (gridMap.count(ref)) {
            rowValues[r] = gridMap[ref];
        } else {
            rowValues[r] = "";
        }
    }


    // ── Analyze each value ────────────────────────────────────────────────────
    std::map<DataType, int> typeCounts;
    std::map<DataType, float> typeMaxConf;
    std::set<std::string> uniqueSet;
    std::set<std::string> seenSet;
    std::vector<std::string> allValues;
    int sampleCount = 0;

    DataDetector& detector = DataDetector::getInstance();

    for (auto& [row, val] : rowValues) {
        std::string trimmed = val;
        while (!trimmed.empty() && std::isspace((unsigned char)trimmed.front())) trimmed.erase(0, 1);
        while (!trimmed.empty() && std::isspace((unsigned char)trimmed.back())) trimmed.pop_back();

        if (trimmed.empty() || trimmed == "0" || trimmed == "null" || trimmed == "N/A" || trimmed == "undefined") {
            result.stats.blankCells++;
            std::string cellRef = colUpper + std::to_string(row);
            if (result.missingCellRefs.size() < 20) {
                result.missingCellRefs.push_back(cellRef);
            }
            continue;
        }

        result.stats.totalCells++;
        allValues.push_back(val);


        // Duplicate detection
        if (seenSet.count(val)) {
            result.stats.duplicateCount++;
        }
        seenSet.insert(val);
        uniqueSet.insert(val);

        // Sample
        if (sampleCount < 5) {
            result.samples.push_back(val);
            sampleCount++;
        }

        // Type detection
        DataType type = detector.detect(val);
        typeCounts[type]++;
        // Track max confidence approximation via plugin scores
        float pluginConf = 0.0f;
        if (type == DataType::PHONE)    pluginConf = 0.95f;
        else if (type == DataType::EMAIL) pluginConf = 1.0f;
        else if (type == DataType::CURRENCY) pluginConf = 0.98f;
        else if (type == DataType::UUID) pluginConf = 1.0f;
        else if (type == DataType::URL) pluginConf = 1.0f;
        else if (type == DataType::BOOLEAN) pluginConf = 1.0f;
        else if (type == DataType::DATE) pluginConf = 0.7f;
        else if (type == DataType::NUMBER) pluginConf = 0.8f;
        else pluginConf = 0.45f;
        typeMaxConf[type] = std::max(typeMaxConf[type], pluginConf);
    }

    result.stats.uniqueCount = (int)uniqueSet.size();

    if (typeCounts.empty()) {
        result.dominantType = DataType::BLANK;
        result.dominantTypeName = "Blank";
        result.detectionReason = "Column is entirely empty";
        result.issues.push_back("Column is entirely empty");
        result.stats.qualityScore = 0.0f;
        return result;
    }

    // ── Header & 70% Threshold Email Override ────────────────────────────────
    std::string lowerHeader = result.headerName;
    for (char& c : lowerHeader) c = std::tolower((unsigned char)c);
    bool headerIsEmail = (lowerHeader.find("email") != std::string::npos ||
                          lowerHeader.find("gmail") != std::string::npos ||
                          lowerHeader.find("mail") != std::string::npos);

    int emailCount = typeCounts[DataType::EMAIL];
    float emailRatio = (result.stats.totalCells > 0) ? (float)emailCount / (float)result.stats.totalCells : 0.0f;

    if (headerIsEmail || emailRatio >= 0.70f) {
        result.dominantType = DataType::EMAIL;
        result.dominantTypeName = "Email";
        result.typeConfidence = (emailRatio >= 0.70f) ? emailRatio : 0.95f;
    } else {
        // ── Find dominant type ────────────────────────────────────────────────────
        auto maxIt = std::max_element(typeCounts.begin(), typeCounts.end(),
            [](const auto& a, const auto& b){ return a.second < b.second; });
        result.dominantType = maxIt->first;
        result.dominantTypeName = dataTypeToString(result.dominantType);
        result.typeConfidence = (float)maxIt->second / (float)result.stats.totalCells;
    }


    // ── Build all candidates (sorted by count desc) ──────────────────────────
    std::vector<std::pair<int,DataType>> sorted;
    for (auto& [t, cnt] : typeCounts) sorted.push_back({cnt, t});
    std::sort(sorted.begin(), sorted.end(),
              [](const auto& a, const auto& b){ return a.first > b.first; });

    for (auto& [cnt, type] : sorted) {
        if (cnt == 0) continue;
        float conf = (float)cnt / result.stats.totalCells;
        DetectionCandidate cand;
        cand.type       = type;
        cand.typeName   = dataTypeToString(type);
        cand.confidence = conf;
        cand.reason     = suggestReason(type, conf, result.stats.totalCells, cnt);
        result.allCandidates.push_back(cand);
    }

    // ── Secondary type ────────────────────────────────────────────────────────
    result.secondaryType = findSecondaryType(result.allCandidates, result.dominantType);
    result.secondaryTypeName = (result.secondaryType != DataType::UNKNOWN)
        ? dataTypeToString(result.secondaryType) : "";

    // ── Dirty values ──────────────────────────────────────────────────────────
    for (auto& [type, count] : typeCounts) {
        if (type != result.dominantType && type != DataType::BLANK) {
            result.stats.dirtyCount += count;
        }
    }

    // ── Mixed detection ───────────────────────────────────────────────────────
    if (result.typeConfidence < 0.6f) {
        result.dominantType = DataType::MIXED;
        result.dominantTypeName = "Mixed Data";
    }

    // ── Format consistency ────────────────────────────────────────────────────
    result.stats.formatConsistency = computeFormatConsistency(allValues, result.dominantType);

    // ── Quality score ─────────────────────────────────────────────────────────
    result.stats.qualityScore = computeQualityScore(result.stats,
        result.stats.totalCells + result.stats.blankCells);

    // ── Detection reason (explainability) ────────────────────────────────────
    int matchCount = (int)(result.typeConfidence * result.stats.totalCells);
    result.detectionReason = suggestReason(result.dominantType, result.typeConfidence,
                                            result.stats.totalCells, matchCount);


    // ── Knowledge tags ────────────────────────────────────────────────────────
    result.knowledgeTags = getKnowledgeTags(result.dominantType);

    // ── Issues list & 80% Threshold Anomaly Alert Engine ────────────────────
    if (result.typeConfidence >= 0.80f && (result.stats.blankCells > 0 || result.stats.dirtyCount > 0)) {
        result.issues.push_back("[ANOMALY_ALERT] 80%+ column match for " + result.dominantTypeName + ". Missing/dirty cells (" + std::to_string(result.stats.blankCells + result.stats.dirtyCount) + ") highlighted for AI Agent verification!");
    }
    if (result.stats.blankCells > 0)
        result.issues.push_back(std::to_string(result.stats.blankCells) + " blank/missing cells");
    if (result.stats.duplicateCount > 0)

        result.issues.push_back(std::to_string(result.stats.duplicateCount) + " duplicate values");
    if (result.stats.dirtyCount > 0)
        result.issues.push_back(std::to_string(result.stats.dirtyCount) +
            " values don't match type (" + result.dominantTypeName + ")");
    if (result.typeConfidence < 0.6f)
        result.issues.push_back("Mixed data types — consider splitting column");
    if (result.stats.uniqueCount == result.stats.totalCells && result.stats.totalCells > 5)
        result.issues.push_back("All values unique — possibly an ID column");
    if (result.stats.uniqueCount == 1 && result.stats.totalCells > 3)
        result.issues.push_back("All values identical — possibly a constant column");
    if (result.stats.formatConsistency < 70)
        result.issues.push_back("Inconsistent formatting detected (" +
            std::to_string(result.stats.formatConsistency) + "% consistent)");

    // ── Recommended actions ───────────────────────────────────────────────────
    result.recommendedActions = buildRecommendedActions(result.dominantType, result.stats);

    return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// AI-Optimized JSON Serialization
// Output matches the ideal format discussed in Phase 2 planning
// ─────────────────────────────────────────────────────────────────────────────
std::string ColumnAnalysisResult::toJson() const {
    std::ostringstream j;
    j << "{";

    // Identity
    j << "\"column\":\"" << jsonEsc(columnLetter) << "\",";
    j << "\"header\":\"" << jsonEsc(headerName) << "\",";

    // Primary detection
    j << "\"primary_type\":\"" << jsonEsc(dominantTypeName) << "\",";
    j << "\"secondary_type\":\"" << jsonEsc(secondaryTypeName) << "\",";
    j << "\"confidence\":" << (int)(typeConfidence * 100) << ",";
    j << "\"reason\":\"" << jsonEsc(detectionReason) << "\",";

    // Statistics
    j << "\"statistics\":{";
    j << "\"total\":" << stats.totalCells << ",";
    j << "\"blank\":" << stats.blankCells << ",";
    j << "\"duplicates\":" << stats.duplicateCount << ",";
    j << "\"invalid\":" << stats.invalidCount << ",";
    j << "\"dirty\":" << stats.dirtyCount << ",";
    j << "\"unique\":" << stats.uniqueCount << ",";
    j << "\"format_consistency\":" << stats.formatConsistency << ",";
    j << "\"quality_score\":" << (int)stats.qualityScore;
    j << "},";

    // All type candidates
    j << "\"candidates\":[";
    for (size_t i = 0; i < allCandidates.size(); i++) {
        if (i) j << ",";
        j << "{\"type\":\"" << jsonEsc(allCandidates[i].typeName)
          << "\",\"confidence\":" << (int)(allCandidates[i].confidence * 100)
          << ",\"reason\":\"" << jsonEsc(allCandidates[i].reason) << "\"}";
    }
    j << "],";

    // Knowledge tags
    j << "\"knowledge_tags\":[";
    for (size_t i = 0; i < knowledgeTags.size(); i++) {
        if (i) j << ",";
        j << "\"" << jsonEsc(knowledgeTags[i]) << "\"";
    }
    j << "],";

    // Issues
    j << "\"issues\":[";
    for (size_t i = 0; i < issues.size(); i++) {
        if (i) j << ",";
        j << "\"" << jsonEsc(issues[i]) << "\"";
    }
    j << "],";

    // Recommended actions
    j << "\"recommended_actions\":[";
    for (size_t i = 0; i < recommendedActions.size(); i++) {
        if (i) j << ",";
        j << "\"" << jsonEsc(recommendedActions[i]) << "\"";
    }
    j << "],";

    // Samples
    j << "\"samples\":[";
    for (size_t i = 0; i < samples.size(); i++) {
        if (i) j << ",";
        j << "\"" << jsonEsc(samples[i]) << "\"";
    }
    j << "],";

    // Missing Cell References & Alert Engine
    j << "\"missing_cells\":[";
    for (size_t i = 0; i < missingCellRefs.size(); i++) {
        if (i) j << ",";
        j << "\"" << jsonEsc(missingCellRefs[i]) << "\"";
    }
    j << "],";

    std::string alert = "";
    if (!missingCellRefs.empty()) {
        alert = "ALERT: Column " + columnLetter + " (" + dominantTypeName + ") has " +
                std::to_string(missingCellRefs.size()) + " missing/blank cells requiring attention!";
    }
    j << "\"alert\":\"" << jsonEsc(alert) << "\"";

    j << "}";
    return j.str();
}
} // namespace Filters

