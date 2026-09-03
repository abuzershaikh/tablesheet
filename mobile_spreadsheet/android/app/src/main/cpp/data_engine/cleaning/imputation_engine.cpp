/*
 * imputation_engine.cpp  —  Enterprise Missing Value Smart Imputation Engine Implementation
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#include "imputation_engine.h"
#include <algorithm>
#include <sstream>
#include <cmath>
#include <cctype>

namespace Filters {

bool ImputationEngine::isMissing(const std::string& val) {
    if (val.empty()) return true;
    std::string s = val;
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(0, 1);
    while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();

    if (s.empty()) return true;
    std::string lower = s;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

    return (lower == "null" || lower == "nan" || lower == "na" || lower == "n/a" ||
            lower == "none" || lower == "-" || lower == "--" || lower == "?" || lower == "nil");
}

double ImputationEngine::computeMean(const std::vector<double>& numbers) {
    if (numbers.empty()) return 0.0;
    double sum = 0.0;
    for (double n : numbers) sum += n;
    return sum / numbers.size();
}

double ImputationEngine::computeMedian(std::vector<double>& numbers) {
    if (numbers.empty()) return 0.0;
    std::sort(numbers.begin(), numbers.end());
    size_t n = numbers.size();
    if (n % 2 == 1) return numbers[n / 2];
    return (numbers[(n / 2) - 1] + numbers[n / 2]) / 2.0;
}

std::string ImputationEngine::computeMode(const std::vector<std::string>& values) {
    if (values.empty()) return "";
    std::map<std::string, int> counts;
    for (const auto& v : values) {
        if (!isMissing(v)) counts[v]++;
    }
    if (counts.empty()) return "";

    std::string bestVal = "";
    int maxCount = -1;
    for (const auto& pair : counts) {
        if (pair.second > maxCount) {
            maxCount = pair.second;
            bestVal = pair.first;
        }
    }
    return bestVal;
}

ImputationReport ImputationEngine::impute(const std::vector<std::string>& columnValues,
                                         ImputationMethod method,
                                         const std::string& fallbackConstant) const {
    ImputationReport report;
    report.totalCells = static_cast<int>(columnValues.size());
    report.resultValues = columnValues;

    if (columnValues.empty()) return report;

    // Collect non-missing numbers & text
    std::vector<double> validNums;
    std::vector<std::string> validTexts;

    for (const auto& v : columnValues) {
        if (isMissing(v)) {
            report.missingCount++;
        } else {
            validTexts.push_back(v);
            try {
                validNums.push_back(std::stod(v));
            } catch (...) {}
        }
    }

    if (report.missingCount == 0) {
        return report;
    }

    char numBuf[64];

    switch (method) {
        case ImputationMethod::FORWARD_FILL: {
            report.methodUsed = "Forward Fill";
            std::string lastKnown = "";
            for (size_t i = 0; i < report.resultValues.size(); i++) {
                if (!isMissing(report.resultValues[i])) {
                    lastKnown = report.resultValues[i];
                } else if (!lastKnown.empty()) {
                    report.resultValues[i] = lastKnown;
                    report.filledCount++;
                }
            }
            break;
        }

        case ImputationMethod::BACKWARD_FILL: {
            report.methodUsed = "Backward Fill";
            std::string nextKnown = "";
            for (int i = static_cast<int>(report.resultValues.size()) - 1; i >= 0; i--) {
                if (!isMissing(report.resultValues[i])) {
                    nextKnown = report.resultValues[i];
                } else if (!nextKnown.empty()) {
                    report.resultValues[i] = nextKnown;
                    report.filledCount++;
                }
            }
            break;
        }

        case ImputationMethod::LINEAR_INTERPOLATE: {
            report.methodUsed = "Linear Interpolation";
            // Interpolate continuous missing gaps between valid numeric points
            int n = static_cast<int>(report.resultValues.size());
            int i = 0;
            while (i < n) {
                if (isMissing(report.resultValues[i])) {
                    int gapStart = i;
                    while (i < n && isMissing(report.resultValues[i])) {
                        i++;
                    }
                    int gapEnd = i; // first non-missing after gap, or n

                    double startVal = 0.0, endVal = 0.0;
                    bool hasStart = false, hasEnd = false;

                    if (gapStart > 0 && !isMissing(report.resultValues[gapStart - 1])) {
                        try {
                            startVal = std::stod(report.resultValues[gapStart - 1]);
                            hasStart = true;
                        } catch (...) {}
                    }
                    if (gapEnd < n && !isMissing(report.resultValues[gapEnd])) {
                        try {
                            endVal = std::stod(report.resultValues[gapEnd]);
                            hasEnd = true;
                        } catch (...) {}
                    }

                    if (hasStart && hasEnd) {
                        int gapLen = gapEnd - gapStart;
                        double step = (endVal - startVal) / (gapLen + 1);
                        for (int k = gapStart; k < gapEnd; k++) {
                            double interpolated = startVal + step * (k - gapStart + 1);
                            snprintf(numBuf, sizeof(numBuf), "%g", interpolated);
                            report.resultValues[k] = numBuf;
                            report.filledCount++;
                        }
                    } else if (hasStart) {
                        for (int k = gapStart; k < gapEnd; k++) {
                            snprintf(numBuf, sizeof(numBuf), "%g", startVal);
                            report.resultValues[k] = numBuf;
                            report.filledCount++;
                        }
                    } else if (hasEnd) {
                        for (int k = gapStart; k < gapEnd; k++) {
                            snprintf(numBuf, sizeof(numBuf), "%g", endVal);
                            report.resultValues[k] = numBuf;
                            report.filledCount++;
                        }
                    }
                } else {
                    i++;
                }
            }
            break;
        }

        case ImputationMethod::MEAN: {
            report.methodUsed = "Mean Imputation";
            double mean = computeMean(validNums);
            snprintf(numBuf, sizeof(numBuf), "%g", mean);
            std::string fillVal = numBuf;
            for (size_t i = 0; i < report.resultValues.size(); i++) {
                if (isMissing(report.resultValues[i])) {
                    report.resultValues[i] = fillVal;
                    report.filledCount++;
                }
            }
            break;
        }

        case ImputationMethod::MEDIAN: {
            report.methodUsed = "Median Imputation";
            double med = computeMedian(validNums);
            snprintf(numBuf, sizeof(numBuf), "%g", med);
            std::string fillVal = numBuf;
            for (size_t i = 0; i < report.resultValues.size(); i++) {
                if (isMissing(report.resultValues[i])) {
                    report.resultValues[i] = fillVal;
                    report.filledCount++;
                }
            }
            break;
        }

        case ImputationMethod::MODE: {
            report.methodUsed = "Mode Imputation";
            std::string modeVal = computeMode(validTexts);
            if (modeVal.empty()) modeVal = fallbackConstant;
            for (size_t i = 0; i < report.resultValues.size(); i++) {
                if (isMissing(report.resultValues[i])) {
                    report.resultValues[i] = modeVal;
                    report.filledCount++;
                }
            }
            break;
        }

        case ImputationMethod::CONSTANT_VALUE: {
            report.methodUsed = "Constant Value";
            for (size_t i = 0; i < report.resultValues.size(); i++) {
                if (isMissing(report.resultValues[i])) {
                    report.resultValues[i] = fallbackConstant;
                    report.filledCount++;
                }
            }
            break;
        }
    }

    return report;
}

std::vector<std::string> ImputationEngine::imputeGroupByMean(
    const std::vector<std::string>& groupCol,
    const std::vector<std::string>& targetCol) const {

    std::vector<std::string> result = targetCol;
    size_t n = std::min(groupCol.size(), targetCol.size());
    if (n == 0) return result;

    // Calculate sum & count per group
    std::map<std::string, std::vector<double>> groupValues;
    for (size_t i = 0; i < n; i++) {
        if (!isMissing(groupCol[i]) && !isMissing(targetCol[i])) {
            try {
                double v = std::stod(targetCol[i]);
                groupValues[groupCol[i]].push_back(v);
            } catch (...) {}
        }
    }

    std::map<std::string, double> groupMeans;
    for (const auto& pair : groupValues) {
        groupMeans[pair.first] = computeMean(pair.second);
    }

    char buf[64];
    for (size_t i = 0; i < n; i++) {
        if (isMissing(result[i]) && !isMissing(groupCol[i])) {
            auto it = groupMeans.find(groupCol[i]);
            if (it != groupMeans.end()) {
                snprintf(buf, sizeof(buf), "%g", it->second);
                result[i] = buf;
            }
        }
    }

    return result;
}

} // namespace Filters
