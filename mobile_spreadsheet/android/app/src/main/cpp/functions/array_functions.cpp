#include "../function_registry.h"
#include <algorithm>
#include <cmath>
#include <random>
#include <ctime>
#include <string>
#include <sstream>
#include <iomanip>






static std::vector<EvalResult> flattenArray(const EvalResult& val) {
    std::vector<EvalResult> result;
    if (std::holds_alternative<ArrayVal>(val)) {
        for (const auto& row : std::get<ArrayVal>(val).matrix) {
            for (const auto& cell : row) {
                result.push_back(cell);
            }
        }
    } else {
        result.push_back(val);
    }
    return result;
}

void FunctionRegistry::registerArrayFunctions() {
    
    // SORTBY(array, by_array, [sort_order])
    // SORTBY(array, by_array1, [sort_order1], [by_array2], [sort_order2], ...)
    registerFunction("SORTBY", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2) return CellError{"#VALUE!"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (!std::holds_alternative<ArrayVal>(arrayVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(arrayVal).matrix;
        
        long long totalCells = (long long)mat.size() * (mat.empty() ? 0 : mat[0].size());
        if (totalCells > 1048576) return CellError{"#NUM!"};
        
        struct SortCriterion {
            std::vector<EvalResult> byFlat;
            bool ascending;
        };
        std::vector<SortCriterion> criteria;

        size_t argIdx = 1;
        while (argIdx < args.size()) {
            auto byArrayVal = EVAL_ARG(eval, args, argIdx++);
            if (Evaluator::isError(byArrayVal)) return byArrayVal;
            
            bool ascending = true;
            if (argIdx < args.size()) {
                auto orderVal = EVAL_ARG(eval, args, argIdx);
                if (Evaluator::isError(orderVal)) return orderVal;
                // If it's a number, 1 is ascending, -1 is descending. We treat >=0 as ascending, <0 as descending.
                // Wait, if it's not a number, maybe it's just the next by_array? 
                // Excel requires pairs, but [sort_order] is optional. If the next arg is an array of size > 1, it's a by_array.
                // To be safe, we just read it as sort_order if it's a number or blank. If it's an array, we backtrack.
                if (std::holds_alternative<double>(orderVal) || std::holds_alternative<Blank>(orderVal)) {
                    if (std::holds_alternative<double>(orderVal)) {
                        double order = std::get<double>(orderVal);
                        if (order != 1.0 && order != -1.0) return CellError{"#VALUE!"};
                        ascending = order > 0;
                    }
                    argIdx++;
                }
            }
            
            std::vector<EvalResult> byVec;
            if (std::holds_alternative<ArrayVal>(byArrayVal)) {
                const auto& byMat = std::get<ArrayVal>(byArrayVal).matrix;
                if (byMat.size() == mat.size()) {
                    for (size_t r = 0; r < byMat.size(); ++r) {
                        byVec.push_back(byMat[r].empty() ? Blank{} : byMat[r][0]);
                    }
                } else if (byMat.size() == 1 && byMat[0].size() == mat.size()) {
                    byVec = byMat[0];
                } else {
                    return CellError{"#VALUE!"};
                }
            } else {
                if (mat.size() == 1) byVec.push_back(byArrayVal);
                else return CellError{"#VALUE!"};
            }
            criteria.push_back({byVec, ascending});
        }

        std::vector<size_t> indices(mat.size());
        for (size_t i = 0; i < indices.size(); ++i) indices[i] = i;
        
        auto compareElements = [](const EvalResult& valA, const EvalResult& valB) -> bool {
            auto getType = [](const EvalResult& v) -> int {
                if (std::holds_alternative<double>(v)) return 0;
                if (std::holds_alternative<std::string>(v)) return 1;
                if (std::holds_alternative<bool>(v)) return 2;
                if (std::holds_alternative<CellError>(v)) return 3;
                return 4; // Blank
            };
            int typeA = getType(valA);
            int typeB = getType(valB);
            
            if (typeA != typeB) return typeA < typeB;
            
            if (typeA == 0) return std::get<double>(valA) < std::get<double>(valB);
            if (typeA == 1) return std::get<std::string>(valA) < std::get<std::string>(valB);
            if (typeA == 2) return std::get<bool>(valA) == false && std::get<bool>(valB) == true;
            if (typeA == 3) return std::get<CellError>(valA).type < std::get<CellError>(valB).type;
            return false;
        };

        std::stable_sort(indices.begin(), indices.end(), [&criteria, &compareElements](size_t a, size_t b) {
            for (const auto& criterion : criteria) {
                const auto& valA = criterion.byFlat[a];
                const auto& valB = criterion.byFlat[b];
                
                bool aLessThanB = compareElements(valA, valB);
                bool bLessThanA = compareElements(valB, valA);
                
                if (aLessThanB) return criterion.ascending;
                if (bLessThanA) return !criterion.ascending;
                // If equal, continue to the next criterion
            }
            return false;
        });
        
        ArrayVal resultArr;
        for (size_t idx : indices) {
            resultArr.matrix.push_back(mat[idx]);
        }
        
        return resultArr;
    });


    // XMATCH(lookup_value, lookup_array, [match_mode], [search_mode])
    registerFunction("XMATCH", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 4) return CellError{"#VALUE!"};
        
        auto lookupVal = EVAL_ARG(eval, args, 0);
        auto arrayVal = EVAL_ARG(eval, args, 1);
        
        if (Evaluator::isError(lookupVal)) return lookupVal;
        if (Evaluator::isError(arrayVal)) return arrayVal;
        
        int matchMode = 0; // 0=exact, -1=exact or next smaller, 1=exact or next larger, 2=wildcard
        if (args.size() >= 3) {
            auto mm = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(mm)) return mm;
            if (!std::holds_alternative<Blank>(mm)) matchMode = (int)Evaluator::asNumber(mm);
        }
        
        int searchMode = 1; // 1=first-to-last, -1=last-to-first
        if (args.size() == 4) {
            auto sm = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(sm)) return sm;
            if (!std::holds_alternative<Blank>(sm)) searchMode = (int)Evaluator::asNumber(sm);
        }
        
        auto arrFlat = flattenArray(arrayVal);
        if (arrFlat.empty()) return CellError{"#N/A"};
        
        bool isNumSearch = std::holds_alternative<double>(lookupVal);
        double searchNum = isNumSearch ? std::get<double>(lookupVal) : 0.0;
        std::string searchStr = Evaluator::asString(lookupVal);
        
        int start = (searchMode == -1) ? (int)arrFlat.size() - 1 : 0;
        int end = (searchMode == -1) ? -1 : (int)arrFlat.size();
        int step = (searchMode == -1) ? -1 : 1;
        
        int exactMatchIdx = -1;
        int bestSmallerIdx = -1;
        int bestLargerIdx = -1;
        
        for (int i = start; i != end; i += step) {
            if (Evaluator::isError(arrFlat[i])) continue;
            
            bool match = false;
            if (isNumSearch && std::holds_alternative<double>(arrFlat[i])) {
                match = (searchNum == std::get<double>(arrFlat[i]));
            } else {
                std::string s1 = searchStr, s2 = Evaluator::asString(arrFlat[i]);
                std::transform(s1.begin(), s1.end(), s1.begin(), [](unsigned char c){ return std::tolower(c); });
                std::transform(s2.begin(), s2.end(), s2.begin(), [](unsigned char c){ return std::tolower(c); });
                match = (s1 == s2);
            }
            
            if (match) {
                exactMatchIdx = i;
                break;
            }
            
            if (matchMode == -1 && isNumSearch && std::holds_alternative<double>(arrFlat[i])) {
                double val = std::get<double>(arrFlat[i]);
                if (val < searchNum) {
                    if (bestSmallerIdx == -1 || val > std::get<double>(arrFlat[bestSmallerIdx])) {
                        bestSmallerIdx = i;
                    }
                }
            } else if (matchMode == 1 && isNumSearch && std::holds_alternative<double>(arrFlat[i])) {
                double val = std::get<double>(arrFlat[i]);
                if (val > searchNum) {
                    if (bestLargerIdx == -1 || val < std::get<double>(arrFlat[bestLargerIdx])) {
                        bestLargerIdx = i;
                    }
                }
            }
        }
        
        if (exactMatchIdx != -1) return (double)(exactMatchIdx + 1);
        if (matchMode == -1 && bestSmallerIdx != -1) return (double)(bestSmallerIdx + 1);
        if (matchMode == 1 && bestLargerIdx != -1) return (double)(bestLargerIdx + 1);
        
        return CellError{"#N/A"};
    });

    // CHOOSECOLS(array, col_num1, [col_num2], ...)
    registerFunction("CHOOSECOLS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2) return CellError{"#VALUE!"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrayVal)
                   ? std::get<ArrayVal>(arrayVal).matrix
                   : std::vector<std::vector<EvalResult>>{{arrayVal}};
        if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};
        int maxCols = (int)mat[0].size();
        
        std::vector<int> cols;
        for (size_t i = 1; i < args.size(); i++) {
            auto argVal = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(argVal)) return argVal;
            int c = (int)Evaluator::asNumber(argVal);
            if (c == 0) return CellError{"#VALUE!"};
            if (c < 0) c = maxCols + c + 1; // Negative index support (-1 = last col)
            if (c <= 0 || c > maxCols) return CellError{"#VALUE!"};
            cols.push_back(c - 1);
        }
        
        ArrayVal resultArr;
        for (const auto& row : mat) {
            std::vector<EvalResult> newRow;
            for (int c : cols) {
                if (c >= 0 && c < (int)row.size()) {
                    newRow.push_back(row[c]);
                } else {
                    newRow.push_back(CellError{"#N/A"});
                }
            }
            resultArr.matrix.push_back(newRow);
        }
        
        return resultArr;
    });

    // CHOOSEROWS(array, row_num1, [row_num2], ...)
    registerFunction("CHOOSEROWS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2) return CellError{"#VALUE!"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrayVal)
                   ? std::get<ArrayVal>(arrayVal).matrix
                   : std::vector<std::vector<EvalResult>>{{arrayVal}};
        if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};
        int maxRows = (int)mat.size();
        
        std::vector<int> rows;
        for (size_t i = 1; i < args.size(); i++) {
            auto argVal = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(argVal)) return argVal;
            int r = (int)Evaluator::asNumber(argVal);
            if (r == 0) return CellError{"#VALUE!"};
            if (r < 0) r = maxRows + r + 1; // Negative index support (-1 = last row)
            if (r <= 0 || r > maxRows) return CellError{"#VALUE!"};
            rows.push_back(r - 1);
        }
        
        ArrayVal resultArr;
        for (int r : rows) {
            resultArr.matrix.push_back(mat[r]);
        }
        
        return resultArr;
    });

    // WRAPROWS(vector, wrap_count, [pad_with])
    registerFunction("WRAPROWS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto wrapCountVal = EVAL_ARG(eval, args, 1);
        
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(wrapCountVal)) return wrapCountVal;
        
        int wrapCount = (int)Evaluator::asNumber(wrapCountVal);
        if (wrapCount <= 0) return CellError{"#VALUE!"};
        
        EvalResult padWith = CellError{"#N/A"};
        if (args.size() == 3) {
            padWith = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(padWith)) return padWith;
        }
        
        auto arrFlat = flattenArray(arrayVal);
        ArrayVal resultArr;
        
        std::vector<EvalResult> currentRow;
        for (size_t i = 0; i < arrFlat.size(); i++) {
            currentRow.push_back(arrFlat[i]);
            if (currentRow.size() == wrapCount) {
                resultArr.matrix.push_back(currentRow);
                currentRow.clear();
            }
        }
        
        if (!currentRow.empty()) {
            while (currentRow.size() < wrapCount) {
                currentRow.push_back(padWith);
            }
            resultArr.matrix.push_back(currentRow);
        }
        
        return resultArr;
    });

    // WRAPCOLS(vector, wrap_count, [pad_with])
    registerFunction("WRAPCOLS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto wrapCountVal = EVAL_ARG(eval, args, 1);
        
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(wrapCountVal)) return wrapCountVal;
        
        int wrapCount = (int)Evaluator::asNumber(wrapCountVal);
        if (wrapCount <= 0) return CellError{"#VALUE!"};
        
        EvalResult padWith = CellError{"#N/A"};
        if (args.size() == 3) {
            padWith = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(padWith)) return padWith;
        }
        
        auto arrFlat = flattenArray(arrayVal);
        ArrayVal resultArr;
        
        size_t cols = (arrFlat.size() + wrapCount - 1) / wrapCount;
        for (size_t r = 0; r < wrapCount; r++) {
            std::vector<EvalResult> row;
            for (size_t c = 0; c < cols; c++) {
                size_t idx = c * wrapCount + r;
                if (idx < arrFlat.size()) {
                    row.push_back(arrFlat[idx]);
                } else {
                    row.push_back(padWith);
                }
            }
            resultArr.matrix.push_back(row);
        }
        
        return resultArr;
    });

    // SEQUENCE(rows, [columns], [start], [step]) — date-aware like Excel
    registerFunction("SEQUENCE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 4) return CellError{"#VALUE!"};
        
        auto rowsVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(rowsVal)) return rowsVal;
        int numRows = (int)Evaluator::asNumber(rowsVal);
        if (numRows <= 0) return CellError{"#VALUE!"};
        
        int numCols = 1;
        if (args.size() >= 2) {
            auto colsVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(colsVal)) return colsVal;
            if (!std::holds_alternative<Blank>(colsVal)) {
                numCols = (int)Evaluator::asNumber(colsVal);
            }
        }
        if (numCols <= 0) return CellError{"#VALUE!"};
        
        long long totalCells = (long long)numRows * numCols;
        if (totalCells > 1048576) return CellError{"#NUM!"}; // PREVENT OOM
        
        bool isDateMode = false;
        double start = 1.0;
        if (args.size() >= 3) {
            auto startVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(startVal)) return startVal;
            if (!std::holds_alternative<Blank>(startVal)) {
                if (std::holds_alternative<std::string>(startVal)) {
                    std::string str = std::get<std::string>(startVal);
                    if (str.size() >= 10 && str[4] == '-' && str[7] == '-') {
                        try {
                            int y = std::stoi(str.substr(0, 4));
                            int m = std::stoi(str.substr(5, 2));
                            int d = std::stoi(str.substr(8, 2));
                            
                            auto isValidDate = [](int yr, int mo, int dy) -> bool {
                                if (yr < 1 || yr > 9999 || mo < 1 || mo > 12 || dy < 1) return false;
                                static const int daysInMonth[] = { 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
                                int maxDays = daysInMonth[mo];
                                if (mo == 2) {
                                    bool isLeap = (yr % 4 == 0 && (yr % 100 != 0 || yr % 400 == 0));
                                    if (isLeap) maxDays = 29;
                                }
                                return dy <= maxDays;
                            };

                            if (isValidDate(y, m, d)) {
                                std::tm tm = {};
                                tm.tm_year = y - 1900;
                                tm.tm_mon = m - 1;
                                tm.tm_mday = d;
                                tm.tm_hour = 12; // Use noon to avoid DST issues
                                std::time_t time = std::mktime(&tm);
                                if (time != -1) {
                                    start = (double)time / 86400.0 + 25569.0;
                                    if (y > 1900 || (y == 1900 && m > 2)) start += 1.0;
                                    isDateMode = true;
                                }
                            }
                        } catch (...) {}
                    }
                }
                if (!isDateMode) {
                    start = Evaluator::asNumber(startVal);
                }
            }
        }
        
        double step = 1.0;
        if (args.size() == 4) {
            auto stepVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(stepVal)) return stepVal;
            if (!std::holds_alternative<Blank>(stepVal)) {
                step = Evaluator::asNumber(stepVal);
            }
        }
        
        auto serialToDateStr = [](double serial) -> std::string {
            double adj = serial;
            if (serial >= 60.0) adj -= 1.0; 
            std::time_t time = (std::time_t)((adj - 25569.0) * 86400.0 + 43200); // add 12h
            std::tm tm_buf = {};
#ifdef _WIN32
            gmtime_s(&tm_buf, &time);
            std::tm* tm = &tm_buf;
#else
            std::tm* tm = gmtime_r(&time, &tm_buf);
#endif
            if (!tm) return "#VALUE!";
            char buf[32];
            snprintf(buf, sizeof(buf), "%04d-%02d-%02d",
                     tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday);
            return std::string(buf);
        };
        
        ArrayVal resultArr;
        double current = start;
        int processedCells = 0;
        
        // Notify progress start for large arrays
        if (totalCells > 10000) {
            eval.notifyProgress(0, totalCells);
        }
        
        for (int r = 0; r < numRows; r++) {
            std::vector<EvalResult> row;
            for (int c = 0; c < numCols; c++) {
                if (isDateMode) {
                    row.push_back(serialToDateStr(current));
                } else {
                    row.push_back(current);
                }
                current += step;
                
                // Update progress every 1000 cells
                processedCells++;
                if (totalCells > 10000 && processedCells % 1000 == 0) {
                    eval.notifyProgress(processedCells, totalCells);
                }
            }
            resultArr.matrix.push_back(row);
        }
        
        // Final progress notification
        if (totalCells > 10000) {
            eval.notifyProgress(totalCells, totalCells);
        }
        
        return resultArr;
    });

    // RANDARRAY([rows], [columns], [min], [max], [whole_number])
    registerFunction("RANDARRAY", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() > 5) return CellError{"#VALUE!"};
        
        int numRows = 1;
        if (args.size() >= 1) {
            auto rVal = EVAL_ARG(eval, args, 0);
            if (Evaluator::isError(rVal)) return rVal;
            if (!std::holds_alternative<Blank>(rVal)) numRows = (int)Evaluator::asNumber(rVal);
        }
        if (numRows <= 0) return CellError{"#VALUE!"};

        int numCols = 1;
        if (args.size() >= 2) {
            auto cVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(cVal)) return cVal;
            if (!std::holds_alternative<Blank>(cVal)) numCols = (int)Evaluator::asNumber(cVal);
        }
        if (numCols <= 0) return CellError{"#VALUE!"};

        double minVal = 0.0;
        if (args.size() >= 3) {
            auto minV = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(minV)) return minV;
            if (!std::holds_alternative<Blank>(minV)) minVal = Evaluator::asNumber(minV);
        }

        double maxVal = 1.0;
        if (args.size() >= 4) {
            auto maxV = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(maxV)) return maxV;
            if (!std::holds_alternative<Blank>(maxV)) maxVal = Evaluator::asNumber(maxV);
        }

        bool wholeNumber = false;
        if (args.size() == 5) {
            auto wholeV = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(wholeV)) return wholeV;
            if (!std::holds_alternative<Blank>(wholeV)) wholeNumber = Evaluator::asBool(wholeV);
        }

        long long totalCells = (long long)numRows * numCols;
        if (totalCells > 1048576) return CellError{"#NUM!"};

        if (minVal > maxVal) return CellError{"#VALUE!"};

        std::random_device rd;
        std::mt19937 gen(rd());

        ArrayVal res;
        for (int r = 0; r < numRows; r++) {
            std::vector<EvalResult> row;
            for (int c = 0; c < numCols; c++) {
                if (wholeNumber) {
                    std::uniform_int_distribution<> dis((int)minVal, (int)maxVal);
                    row.push_back((double)dis(gen));
                } else {
                    std::uniform_real_distribution<> dis(minVal, maxVal);
                    row.push_back(dis(gen));
                }
            }
            res.matrix.push_back(row);
        }
        return res;
    });

    static auto evalAsFilterBool = [](const EvalResult& c) -> bool {
        if (std::holds_alternative<Blank>(c)) return false;
        if (std::holds_alternative<bool>(c)) return std::get<bool>(c);
        if (std::holds_alternative<double>(c)) return std::get<double>(c) != 0.0;
        if (std::holds_alternative<std::string>(c)) {
            std::string s = std::get<std::string>(c);
            if (s.empty()) return false;
            std::string sUpper = s;
            for (char& ch : sUpper) ch = std::toupper((unsigned char)ch);
            if (sUpper == "FALSE") return false;
            return true;
        }
        return false;
    };

    // FILTER(array, include, [if_empty])
    registerFunction("FILTER", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        auto incVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrVal)) return arrVal;
        if (Evaluator::isError(incVal)) return incVal;

        std::vector<std::vector<EvalResult>> mat;
        if (std::holds_alternative<ArrayVal>(arrVal)) {
            mat = std::get<ArrayVal>(arrVal).matrix;
        } else {
            mat = {{arrVal}};
        }

        if (mat.empty() || mat[0].empty()) return CellError{"#CALC!"};

        long long totalCells = (long long)mat.size() * mat[0].size();
        if (totalCells > 1048576) return CellError{"#NUM!"};

        std::vector<bool> flags;
        if (std::holds_alternative<ArrayVal>(incVal)) {
            const auto& incMat = std::get<ArrayVal>(incVal).matrix;
            if (incMat.size() != mat.size()) return CellError{"#VALUE!"};
            for (const auto& r : incMat) {
                EvalResult cell = r.empty() ? Blank{} : r[0];
                flags.push_back(evalAsFilterBool(cell));
            }
        } else {
            if (mat.size() == 1) {
                flags.push_back(evalAsFilterBool(incVal));
            } else {
                return CellError{"#VALUE!"};
            }
        }

        ArrayVal res;
        for (size_t r = 0; r < mat.size(); r++) {
            if (r < flags.size() && flags[r]) {
                res.matrix.push_back(mat[r]);
            }
        }

        if (res.matrix.empty()) {
            if (args.size() == 3) {
                auto ifEmpty = EVAL_ARG(eval, args, 2);
                return ifEmpty;
            }
            return CellError{"#CALC!"};
        }
        
        if (!std::holds_alternative<ArrayVal>(arrVal) && res.matrix.size() == 1 && res.matrix[0].size() == 1) {
            return res.matrix[0][0];
        }
        return res;
    });

    // UNIQUE(array)
    // UNIQUE(array, [by_col], [exactly_once])
    registerFunction("UNIQUE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 3) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        bool byCol = false;
        if (args.size() >= 2) {
            auto byColVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(byColVal)) return byColVal;
            byCol = Evaluator::asBool(byColVal);
        }

        bool exactlyOnce = false;
        if (args.size() == 3) {
            auto exactVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(exactVal)) return exactVal;
            exactlyOnce = Evaluator::asBool(exactVal);
        }

        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};

        if (mat.empty() || mat[0].empty()) return CellError{"#CALC!"};

        long long totalCells = (long long)mat.size() * mat[0].size();
        if (totalCells > 1048576) return CellError{"#NUM!"};

        auto transposeMatrix = [](const std::vector<std::vector<EvalResult>>& m) {
            if (m.empty()) return m;
            size_t maxCols = 0;
            for (const auto& r : m) maxCols = std::max(maxCols, r.size());
            if (maxCols == 0) return m;
            
            std::vector<std::vector<EvalResult>> t(maxCols, std::vector<EvalResult>(m.size(), Blank{}));
            for (size_t r = 0; r < m.size(); ++r) {
                for (size_t c = 0; c < m[r].size(); ++c) {
                    t[c][r] = m[r][c];
                }
            }
            return t;
        };

        if (byCol) mat = transposeMatrix(mat);

        std::unordered_map<std::string, int> rowFreq;
        std::vector<std::string> rowKeys;
        std::unordered_map<std::string, std::vector<EvalResult>> rowData;

        auto cellToUniqueKey = [](const EvalResult& cell) -> std::string {
            if (std::holds_alternative<Blank>(cell)) return "B:";
            if (std::holds_alternative<double>(cell)) {
                std::ostringstream oss;
                oss << "N:" << std::setprecision(17) << std::get<double>(cell);
                return oss.str();
            }
            if (std::holds_alternative<bool>(cell)) return "L:" + std::to_string(std::get<bool>(cell));
            if (std::holds_alternative<std::string>(cell)) return "S:" + std::get<std::string>(cell);
            if (std::holds_alternative<CellError>(cell)) return "E:" + std::get<CellError>(cell).type;
            return "X:";
        };

        for (const auto& row : mat) {
            std::string key;
            for (const auto& cell : row) {
                key += cellToUniqueKey(cell) + "\x1F";
            }
            rowFreq[key]++;
            if (rowFreq[key] == 1) {
                rowKeys.push_back(key);
                rowData[key] = row;
            }
        }

        std::vector<std::vector<EvalResult>> filteredMat;
        for (const auto& key : rowKeys) {
            if (exactlyOnce && rowFreq[key] > 1) continue;
            filteredMat.push_back(rowData[key]);
        }

        if (filteredMat.empty()) return CellError{"#CALC!"};

        if (byCol) filteredMat = transposeMatrix(filteredMat);

        ArrayVal res;
        res.matrix = filteredMat;
        return res;
    });

    // DROP(array, rows, [columns])
    registerFunction("DROP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};
        if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};
        
        int origRows = (int)mat.size();
        int origCols = (int)mat[0].size();
        
        int dropRows = 0;
        auto rVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(rVal)) return rVal;
        if (!std::holds_alternative<Blank>(rVal)) dropRows = (int)Evaluator::asNumber(rVal);
        
        int dropCols = 0;
        if (args.size() == 3) {
            auto cVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(cVal)) return cVal;
            if (!std::holds_alternative<Blank>(cVal)) dropCols = (int)Evaluator::asNumber(cVal);
        }
        
        int startRow = 0, endRow = origRows;
        if (dropRows > 0) startRow = std::min(dropRows, origRows);
        else if (dropRows < 0) endRow = std::max(0, origRows + dropRows);
        
        int startCol = 0, endCol = origCols;
        if (dropCols > 0) startCol = std::min(dropCols, origCols);
        else if (dropCols < 0) endCol = std::max(0, origCols + dropCols);
        
        if (startRow >= endRow || startCol >= endCol) return CellError{"#CALC!"};
        
        ArrayVal res;
        for (int r = startRow; r < endRow; r++) {
            std::vector<EvalResult> row;
            for (int c = startCol; c < endCol; c++) {
                row.push_back(mat[r][c]);
            }
            res.matrix.push_back(row);
        }
        return res;
    });

    // EXPAND(array, rows, [columns], [pad_with])
    registerFunction("EXPAND", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 4) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};
        if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};
        
        int origRows = (int)mat.size();
        int origCols = (int)mat[0].size();
        
        int targetRows = origRows;
        auto rVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(rVal)) return rVal;
        if (!std::holds_alternative<Blank>(rVal)) targetRows = (int)Evaluator::asNumber(rVal);
        
        int targetCols = origCols;
        if (args.size() >= 3) {
            auto cVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(cVal)) return cVal;
            if (!std::holds_alternative<Blank>(cVal)) targetCols = (int)Evaluator::asNumber(cVal);
        }
        
        if (targetRows <= 0 || targetCols <= 0 || targetRows < origRows || targetCols < origCols) return CellError{"#VALUE!"};
        
        EvalResult padWith = CellError{"#N/A"};
        if (args.size() == 4) {
            auto pVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(pVal)) return pVal;
            if (!std::holds_alternative<Blank>(pVal)) padWith = pVal;
        }
        
        ArrayVal res;
        for (int r = 0; r < targetRows; r++) {
            std::vector<EvalResult> row;
            for (int c = 0; c < targetCols; c++) {
                if (r < origRows && c < origCols) {
                    row.push_back(mat[r][c]);
                } else {
                    row.push_back(padWith);
                }
            }
            res.matrix.push_back(row);
        }
        return res;
    });

    // TOCOL(array, [ignore], [by_col])
    registerFunction("TOCOL", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 3) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};
        
        int ignore = 0; // 0=keep all, 1=ignore blanks, 2=ignore errors, 3=ignore blanks and errors
        if (args.size() >= 2) {
            auto igVal = EVAL_ARG(eval, args, 1);
            if (!std::holds_alternative<Blank>(igVal)) ignore = (int)Evaluator::asNumber(igVal);
        }
        
        bool byCol = false;
        if (args.size() == 3) {
            auto bcVal = EVAL_ARG(eval, args, 2);
            if (!std::holds_alternative<Blank>(bcVal)) byCol = Evaluator::asBool(bcVal);
        }
        
        ArrayVal res;
        auto processCell = [&](const EvalResult& cell) {
            bool isB = std::holds_alternative<Blank>(cell);
            bool isE = Evaluator::isError(cell);
            if ((ignore == 1 || ignore == 3) && isB) return;
            if ((ignore == 2 || ignore == 3) && isE) return;
            res.matrix.push_back({cell});
        };
        
        if (!byCol) {
            for (const auto& row : mat) {
                for (const auto& cell : row) processCell(cell);
            }
        } else {
            size_t maxCols = mat.empty() ? 0 : mat[0].size();
            for (size_t c = 0; c < maxCols; c++) {
                for (size_t r = 0; r < mat.size(); r++) {
                    if (c < mat[r].size()) processCell(mat[r][c]);
                }
            }
        }
        
        if (res.matrix.empty()) return CellError{"#CALC!"};
        return res;
    });

    // TOROW(array, [ignore], [by_col])
    registerFunction("TOROW", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 3) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};
        
        int ignore = 0;
        if (args.size() >= 2) {
            auto igVal = EVAL_ARG(eval, args, 1);
            if (!std::holds_alternative<Blank>(igVal)) ignore = (int)Evaluator::asNumber(igVal);
        }
        
        bool byCol = false;
        if (args.size() == 3) {
            auto bcVal = EVAL_ARG(eval, args, 2);
            if (!std::holds_alternative<Blank>(bcVal)) byCol = Evaluator::asBool(bcVal);
        }
        
        std::vector<EvalResult> rowVec;
        auto processCell = [&](const EvalResult& cell) {
            bool isB = std::holds_alternative<Blank>(cell);
            bool isE = Evaluator::isError(cell);
            if ((ignore == 1 || ignore == 3) && isB) return;
            if ((ignore == 2 || ignore == 3) && isE) return;
            rowVec.push_back(cell);
        };
        
        if (!byCol) {
            for (const auto& row : mat) {
                for (const auto& cell : row) processCell(cell);
            }
        } else {
            size_t maxCols = mat.empty() ? 0 : mat[0].size();
            for (size_t c = 0; c < maxCols; c++) {
                for (size_t r = 0; r < mat.size(); r++) {
                    if (c < mat[r].size()) processCell(mat[r][c]);
                }
            }
        }
        
        if (rowVec.empty()) return CellError{"#CALC!"};
        ArrayVal res;
        res.matrix.push_back(rowVec);
        return res;
    });

    // SORT(array, [sort_index], [sort_order], [by_col])
    registerFunction("SORT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 4) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};

        if (mat.empty() || mat[0].empty()) return CellError{"#CALC!"};

        size_t sortIndex = 0;
        if (args.size() >= 2) {
            auto sIdx = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(sIdx)) return sIdx;
            if (!std::holds_alternative<Blank>(sIdx)) {
                int idx = (int)Evaluator::asNumber(sIdx);
                if (idx < 1) return CellError{"#VALUE!"};
                sortIndex = idx - 1;
            }
        }

        bool ascending = true;
        if (args.size() >= 3) {
            auto sOrd = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(sOrd)) return sOrd;
            if (!std::holds_alternative<Blank>(sOrd)) {
                double ord = Evaluator::asNumber(sOrd);
                if (ord != 1.0 && ord != -1.0) return CellError{"#VALUE!"};
                ascending = ord == 1.0;
            }
        }
        
        bool byCol = false;
        if (args.size() == 4) {
            auto bcVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(bcVal)) return bcVal;
            byCol = Evaluator::asBool(bcVal);
        }

        auto transposeMatrix = [](const std::vector<std::vector<EvalResult>>& m) {
            if (m.empty()) return m;
            size_t maxCols = 0;
            for (const auto& r : m) maxCols = std::max(maxCols, r.size());
            if (maxCols == 0) return m;
            
            std::vector<std::vector<EvalResult>> t(maxCols, std::vector<EvalResult>(m.size(), Blank{}));
            for (size_t r = 0; r < m.size(); ++r) {
                for (size_t c = 0; c < m[r].size(); ++c) {
                    t[c][r] = m[r][c];
                }
            }
            return t;
        };

        if (byCol) mat = transposeMatrix(mat);
        if (sortIndex >= mat[0].size()) return CellError{"#VALUE!"};

        auto compareElements = [](const EvalResult& valA, const EvalResult& valB) -> bool {
            auto getType = [](const EvalResult& v) -> int {
                if (std::holds_alternative<double>(v)) return 0;
                if (std::holds_alternative<std::string>(v)) return 1;
                if (std::holds_alternative<bool>(v)) return 2;
                if (std::holds_alternative<CellError>(v)) return 3;
                return 4; // Blank
            };
            int typeA = getType(valA);
            int typeB = getType(valB);
            
            if (typeA != typeB) return typeA < typeB;
            
            if (typeA == 0) return std::get<double>(valA) < std::get<double>(valB);
            if (typeA == 1) return std::get<std::string>(valA) < std::get<std::string>(valB);
            if (typeA == 2) return std::get<bool>(valA) == false && std::get<bool>(valB) == true;
            if (typeA == 3) return std::get<CellError>(valA).type < std::get<CellError>(valB).type;
            return false;
        };

        std::stable_sort(mat.begin(), mat.end(), [sortIndex, ascending, &compareElements](const std::vector<EvalResult>& a, const std::vector<EvalResult>& b) {
            EvalResult valA = (sortIndex < a.size()) ? a[sortIndex] : Blank{};
            EvalResult valB = (sortIndex < b.size()) ? b[sortIndex] : Blank{};
            
            bool aLessThanB = compareElements(valA, valB);
            bool bLessThanA = compareElements(valB, valA);
            
            if (!aLessThanB && !bLessThanA) return false; // Equal
            return ascending ? aLessThanB : bLessThanA;
        });

        if (byCol) mat = transposeMatrix(mat);

        ArrayVal res;
        res.matrix = mat;
        return res;
    });

    // VSTACK(array1, [array2], ...)
    registerFunction("VSTACK", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        
        std::vector<ArrayVal> arrs;
        size_t totalRows = 0;
        size_t maxCols = 0;
        
        for (size_t i = 0; i < args.size(); i++) {
            auto val = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(val)) return val;
            if (std::holds_alternative<ArrayVal>(val)) {
                const auto& a = std::get<ArrayVal>(val);
                totalRows += a.matrix.size();
                for (const auto& row : a.matrix) maxCols = std::max(maxCols, row.size());
                arrs.push_back(a);
            } else {
                totalRows += 1;
                maxCols = std::max(maxCols, (size_t)1);
                arrs.push_back(ArrayVal{{ {val} }});
            }
            if ((long long)totalRows * maxCols > 1048576) return CellError{"#NUM!"};
        }

        ArrayVal res;
        for (const auto& a : arrs) {
            for (const auto& row : a.matrix) {
                std::vector<EvalResult> newRow = row;
                while (newRow.size() < maxCols) {
                    newRow.push_back(CellError{"#N/A"});
                }
                res.matrix.push_back(newRow);
            }
        }
        return res;
    });

    // HSTACK(array1, [array2], ...)
    registerFunction("HSTACK", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        std::vector<ArrayVal> arrs;
        size_t maxRows = 0;
        size_t totalCols = 0;
        for (size_t i = 0; i < args.size(); i++) {
            auto val = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(val)) return val;
            if (std::holds_alternative<ArrayVal>(val)) {
                auto a = std::get<ArrayVal>(val);
                maxRows = std::max(maxRows, a.matrix.size());
                totalCols += a.matrix.empty() ? 1 : a.matrix[0].size();
                arrs.push_back(a);
            } else {
                maxRows = std::max(maxRows, (size_t)1);
                totalCols += 1;
                arrs.push_back(ArrayVal{{ {val} }});
            }
            if ((long long)maxRows * totalCols > 1048576) return CellError{"#NUM!"};
        }

        ArrayVal res;
        for (size_t r = 0; r < maxRows; r++) {
            std::vector<EvalResult> combinedRow;
            for (const auto& a : arrs) {
                if (r < a.matrix.size()) {
                    for (const auto& c : a.matrix[r]) combinedRow.push_back(c);
                } else {
                    size_t colsToPad = a.matrix.empty() ? 1 : a.matrix[0].size();
                    for (size_t i = 0; i < colsToPad; i++) combinedRow.push_back(CellError{"#N/A"});
                }
            }
            res.matrix.push_back(combinedRow);
        }
        return res;
    });

    // TAKE(array, rows, [cols])
    registerFunction("TAKE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrayVal) 
                   ? std::get<ArrayVal>(arrayVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrayVal}};
        if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};
        
        auto rowsVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(rowsVal)) return rowsVal;
        int takeRows = 0;
        if (!std::holds_alternative<Blank>(rowsVal)) {
            takeRows = (int)Evaluator::asNumber(rowsVal);
        }
        
        int takeCols = 0;
        bool hasCols = false;
        if (args.size() == 3) {
            auto colsVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(colsVal)) return colsVal;
            if (!std::holds_alternative<Blank>(colsVal)) {
                takeCols = (int)Evaluator::asNumber(colsVal);
                hasCols = true;
            }
        }
        
        if (takeRows == 0 || (hasCols && takeCols == 0)) return CellError{"#CALC!"};
        
        int origRows = mat.size();
        int origCols = mat[0].size();
        
        int startRow = 0;
        int endRow = origRows;
        if (takeRows > 0) {
            endRow = std::min(takeRows, origRows);
        } else if (takeRows < 0) {
            startRow = std::max(0, origRows + takeRows);
        }
        
        int startCol = 0;
        int endCol = origCols;
        if (hasCols) {
            if (takeCols > 0) {
                endCol = std::min(takeCols, origCols);
            } else if (takeCols < 0) {
                startCol = std::max(0, origCols + takeCols);
            }
        }
        
        ArrayVal resultArr;
        for (int r = startRow; r < endRow; r++) {
            std::vector<EvalResult> newRow;
            for (int c = startCol; c < endCol; c++) {
                newRow.push_back(mat[r][c]);
            }
            if (!newRow.empty()) {
                resultArr.matrix.push_back(newRow);
            }
        }
        
        if (resultArr.matrix.empty()) return CellError{"#CALC!"};
        return resultArr;
    });

    // TRANSPOSE(array)
    registerFunction("TRANSPOSE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};

        if (mat.empty()) return CellError{"#CALC!"};
        size_t maxCols = 0;
        for (const auto& r : mat) maxCols = std::max(maxCols, r.size());
        if (maxCols == 0) return CellError{"#CALC!"};

        std::vector<std::vector<EvalResult>> t(maxCols, std::vector<EvalResult>(mat.size(), Blank{}));
        for (size_t r = 0; r < mat.size(); ++r) {
            for (size_t c = 0; c < mat[r].size(); ++c) {
                t[c][r] = mat[r][c];
            }
        }
        
        ArrayVal res;
        res.matrix = t;
        return res;
    });

}
