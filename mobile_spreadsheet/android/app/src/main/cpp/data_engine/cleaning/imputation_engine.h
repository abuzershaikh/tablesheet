/*
 * imputation_engine.h  —  Enterprise Missing Value Smart Imputation Engine
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 *
 * STRATEGIES:
 *   1. FORWARD_FILL:       Carries last known valid value downwards
 *   2. BACKWARD_FILL:      Carries next known valid value upwards
 *   3. LINEAR_INTERPOLATE: Computes straight-line interpolation for numbers
 *   4. MEAN / MEDIAN:      Computes column statistical average/median
 *   5. MODE:               Uses most frequent category/text value
 *   6. GROUP_BY_MEAN:      Computes group-wise average (e.g. Dept -> Avg Salary)
 */
#pragma once
#include <string>
#include <vector>
#include <map>

namespace Filters {

enum class ImputationMethod {
    FORWARD_FILL,
    BACKWARD_FILL,
    LINEAR_INTERPOLATE,
    MEAN,
    MEDIAN,
    MODE,
    CONSTANT_VALUE
};

struct ImputationReport {
    int totalCells = 0;
    int missingCount = 0;
    int filledCount = 0;
    std::string methodUsed = "";
    std::vector<std::string> resultValues;
};

class ImputationEngine {
public:
    static ImputationEngine& getInstance() {
        static ImputationEngine instance;
        return instance;
    }

    /// Imputes missing values in a column vector
    ImputationReport impute(const std::vector<std::string>& columnValues,
                           ImputationMethod method,
                           const std::string& fallbackConstant = "0") const;

    /// Group-by mean imputation across two columns (groupColumn & targetNumericColumn)
    std::vector<std::string> imputeGroupByMean(const std::vector<std::string>& groupCol,
                                               const std::vector<std::string>& targetCol) const;

private:
    ImputationEngine() = default;

    static bool isMissing(const std::string& val);
    static double computeMean(const std::vector<double>& numbers);
    static double computeMedian(std::vector<double>& numbers);
    static std::string computeMode(const std::vector<std::string>& values);
};

} // namespace Filters
