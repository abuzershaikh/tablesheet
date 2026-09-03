#include "../function_registry.h"
#include "../spreadsheet_compute.h"
#include <algorithm>
#include <cmath>
#include <map>
#include <regex>

extern SpreadsheetCompute* g_computeEngine;

void FunctionRegistry::registerStatisticalFunctions() {
    
    auto extractNumbers = [](const EvalResult& val, std::vector<double>& out) -> EvalResult {
        auto recurse = [&](auto& self, const EvalResult& v, bool isArray) -> EvalResult {
            if (Evaluator::isError(v)) return v;
            if (std::holds_alternative<ArrayVal>(v)) {
                for (const auto& row : std::get<ArrayVal>(v).matrix) {
                    for (const auto& cell : row) {
                        auto err = self(self, cell, true);
                        if (Evaluator::isError(err)) return err;
                    }
                }
            } else {
                if (isArray) {
                    if (std::holds_alternative<double>(v)) {
                        out.push_back(std::get<double>(v));
                    } else if (std::holds_alternative<std::string>(v)) {
                        try {
                            std::string s = std::get<std::string>(v);
                            size_t first = s.find_first_not_of(" \t\r\n");
                            if (first != std::string::npos) {
                                size_t last = s.find_last_not_of(" \t\r\n");
                                s = s.substr(first, last - first + 1);
                                size_t idx = 0;
                                double d = std::stod(s, &idx);
                                if (idx == s.length()) {
                                    out.push_back(d);
                                }
                            }
                        } catch (...) {}
                    }
                } else {
                    if (!std::holds_alternative<Blank>(v)) {
                        try {
                            out.push_back(Evaluator::asNumber(v));
                        } catch (...) {
                            return CellError{"#VALUE!"};
                        }
                    }
                }
            }
            return true;
        };
        return recurse(recurse, val, false);
    };

    // TRIMMEAN(array, percent)
    registerFunction("TRIMMEAN", [&extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto percentVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(percentVal)) return percentVal;
        
        double percent = Evaluator::asNumber(percentVal);
        if (percent < 0.0 || percent >= 1.0) return CellError{"#NUM!"};
        
        std::vector<double> vals;
        auto err = extractNumbers(arrayVal, vals);
        if (Evaluator::isError(err)) return err;
        
        if (vals.empty()) return CellError{"#NUM!"};
        
        int excludeCount = (int)std::floor(vals.size() * percent);
        excludeCount = (excludeCount / 2) * 2; // round down to nearest multiple of 2
        
        if (excludeCount >= (int)vals.size()) return CellError{"#NUM!"};
        
        std::sort(vals.begin(), vals.end());
        int excludePerEnd = excludeCount / 2;
        
        double sum = 0.0;
        int count = 0;
        for (int i = excludePerEnd; i < (int)vals.size() - excludePerEnd; ++i) {
            sum += vals[i];
            count++;
        }
        
        if (count == 0) return CellError{"#DIV/0!"};
        return sum / count;
    });

    auto matchCriteria = [](const EvalResult& cellVal, const EvalResult& criteriaVal) -> bool {
        if (Evaluator::isError(cellVal)) return false;
        
        std::string critStr = Evaluator::asString(criteriaVal);
        std::string op = "=";
        std::string valPart = critStr;

        if (critStr.rfind(">=", 0) == 0 || critStr.rfind("<=", 0) == 0 || critStr.rfind("<>", 0) == 0) {
            op = critStr.substr(0, 2);
            valPart = critStr.substr(2);
        } else if (critStr.rfind(">", 0) == 0 || critStr.rfind("<", 0) == 0 || critStr.rfind("=", 0) == 0) {
            op = critStr.substr(0, 1);
            valPart = critStr.substr(1);
        }

        try {
            size_t idx = 0;
            double targetNum = std::stod(valPart, &idx);
            if (idx == valPart.length()) {
                double cellNum = Evaluator::asNumber(cellVal);
                if (op == ">=") return cellNum >= targetNum;
                if (op == "<=") return cellNum <= targetNum;
                if (op == "<>") return cellNum != targetNum;
                if (op == ">") return cellNum > targetNum;
                if (op == "<") return cellNum < targetNum;
                if (op == "=") return cellNum == targetNum;
            }
        } catch (...) {}

        std::string cellStr = Evaluator::asString(cellVal);
        std::string regexStr = "^";
        for (size_t i = 0; i < valPart.length(); ++i) {
            char c = valPart[i];
            if (c == '~' && i + 1 < valPart.length() && (valPart[i+1] == '*' || valPart[i+1] == '?' || valPart[i+1] == '~')) {
                regexStr += '\\';
                regexStr += valPart[i+1];
                i++;
            } else if (c == '*') {
                regexStr += ".*";
            } else if (c == '?') {
                regexStr += ".";
            } else if (std::string(".+()[]{}^$|\\\\").find(c) != std::string::npos) {
                regexStr += '\\';
                regexStr += c;
            } else {
                regexStr += c;
            }
        }
        regexStr += "$";
        try {
            std::regex re(regexStr, std::regex_constants::icase);
            bool matched = std::regex_match(cellStr, re);
            if (op == "<>") return !matched;
            return matched;
        } catch (...) {
            if (op == "<>") return cellStr != valPart;
            return cellStr == valPart;
        }
    };

    // COUNT(value1, [value2], ...)
    registerFunction("COUNT", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        return (double)numbers.size();
    });

    // COUNTA(value1, [value2], ...)
    registerFunction("COUNTA", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        int count = 0;
        
        // Helper to flatten and count non-blank
        auto countNonBlank = [&](auto& self, const EvalResult& v) -> void {
            if (std::holds_alternative<ArrayVal>(v)) {
                for (const auto& row : std::get<ArrayVal>(v).matrix) {
                    for (const auto& cell : row) {
                        self(self, cell);
                    }
                }
            } else if (!std::holds_alternative<Blank>(v) && !Evaluator::isError(v)) {
                count++;
            }
        };
        
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            countNonBlank(countNonBlank, val);
        }
        return (double)count;
    });

    // COUNTBLANK(range)
    registerFunction("COUNTBLANK", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        int count = 0;
        
        auto countBlanks = [&](auto& self, const EvalResult& v) -> void {
            if (std::holds_alternative<ArrayVal>(v)) {
                for (const auto& row : std::get<ArrayVal>(v).matrix) {
                    for (const auto& cell : row) {
                        self(self, cell);
                    }
                }
            } else if (std::holds_alternative<Blank>(v) || (std::holds_alternative<std::string>(v) && std::get<std::string>(v).empty())) {
                count++;
            }
        };
        
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            countBlanks(countBlanks, val);
        }
        return (double)count;
    });

    // MAX(number1, [number2], ...)
    registerFunction("MAX", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.empty()) return 0.0;
        
        double max_val = numbers[0];
        for (double d : numbers) {
            if (d > max_val) max_val = d;
        }
        return max_val;
    });

    // MIN(number1, [number2], ...)
    registerFunction("MIN", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.empty()) return 0.0;
        
        double min_val = numbers[0];
        for (double d : numbers) {
            if (d < min_val) min_val = d;
        }
        return min_val;
    });

    // MEDIAN(number1, [number2], ...)
    registerFunction("MEDIAN", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.empty()) return CellError{"#NUM!"};
        
        if (g_computeEngine) return g_computeEngine->median(numbers);
        
        std::sort(numbers.begin(), numbers.end());
        size_t mid = numbers.size() / 2;
        if (numbers.size() % 2 == 0) return (numbers[mid - 1] + numbers[mid]) / 2.0;
        return numbers[mid];
    });

    // MODE(number1, [number2], ...)
    registerFunction("MODE", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.empty()) return CellError{"#N/A"};
        
        std::vector<double> unique_nums;
        std::map<double, int> counts;
        for (double d : numbers) {
            if (counts[d] == 0) unique_nums.push_back(d);
            counts[d]++;
        }
        
        double mode_val = numbers[0];
        int max_count = 0;
        for (double d : unique_nums) {
            if (counts[d] > max_count) {
                max_count = counts[d];
                mode_val = d;
            }
        }
        if (max_count == 1) return CellError{"#N/A"};
        return mode_val;
    });

    // STDEV(number1, [number2], ...)
    registerFunction("STDEV", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.size() <= 1) return CellError{"#DIV/0!"};
        
        double sum = 0;
        for (double d : numbers) sum += d;
        double mean = sum / numbers.size();
        
        double variance = 0;
        for (double d : numbers) variance += (d - mean) * (d - mean);
        
        return std::sqrt(variance / (numbers.size() - 1));
    });

    // VAR(number1, [number2], ...)
    registerFunction("VAR", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.size() <= 1) return CellError{"#DIV/0!"};
        
        double sum = 0;
        for (double d : numbers) sum += d;
        double mean = sum / numbers.size();
        
        double variance = 0;
        for (double d : numbers) variance += (d - mean) * (d - mean);
        
        return variance / (numbers.size() - 1);
    });

    // COUNTIFS(criteria_range1, criteria1, ...)
    registerFunction("COUNTIFS", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() % 2 != 0) return CellError{"#VALUE!"};
        struct CritPair {
            EvalResult range;
            EvalResult crit;
        };
        std::vector<CritPair> pairs;
        for (size_t i = 0; i < args.size(); i += 2) {
            auto rVal = EVAL_ARG(eval, args, i);
            auto cVal = EVAL_ARG(eval, args, i + 1);
            if (Evaluator::isError(rVal)) return rVal;
            if (Evaluator::isError(cVal)) return cVal;
            pairs.push_back({rVal, cVal});
        }
        
        int count = 0;
        if (std::holds_alternative<ArrayVal>(pairs[0].range)) {
            const auto& firstMat = std::get<ArrayVal>(pairs[0].range).matrix;
            for (size_t r = 0; r < firstMat.size(); r++) {
                for (size_t c = 0; c < firstMat[r].size(); c++) {
                    bool allMatch = true;
                    for (const auto& p : pairs) {
                        if (std::holds_alternative<ArrayVal>(p.range)) {
                            const auto& rMat = std::get<ArrayVal>(p.range).matrix;
                            if (r >= rMat.size() || c >= rMat[r].size() || !matchCriteria(rMat[r][c], p.crit)) {
                                allMatch = false; break;
                            }
                        } else {
                            if (r != 0 || c != 0 || !matchCriteria(p.range, p.crit)) {
                                allMatch = false; break;
                            }
                        }
                    }
                    if (allMatch) count++;
                }
            }
        } else {
            bool allMatch = true;
            for (const auto& p : pairs) {
                if (std::holds_alternative<ArrayVal>(p.range)) {
                    const auto& rMat = std::get<ArrayVal>(p.range).matrix;
                    if (rMat.empty() || rMat[0].empty() || !matchCriteria(rMat[0][0], p.crit)) {
                        allMatch = false; break;
                    }
                } else {
                    if (!matchCriteria(p.range, p.crit)) {
                        allMatch = false; break;
                    }
                }
            }
            if (allMatch) count++;
        }
        return (double)count;
    });

    // AVERAGEIF(range, criteria, [average_range])
    registerFunction("AVERAGEIF", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto rangeVal = EVAL_ARG(eval, args, 0);
        auto critVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(rangeVal)) return rangeVal;
        if (Evaluator::isError(critVal)) return critVal;

        auto avgRangeVal = (args.size() == 3) ? EVAL_ARG(eval, args, 2) : rangeVal;
        if (Evaluator::isError(avgRangeVal)) return avgRangeVal;

        double sum = 0.0;
        int count = 0;
        if (std::holds_alternative<ArrayVal>(rangeVal)) {
            const auto& rMat = std::get<ArrayVal>(rangeVal).matrix;
            for (size_t r = 0; r < rMat.size(); r++) {
                for (size_t c = 0; c < rMat[r].size(); c++) {
                    if (matchCriteria(rMat[r][c], critVal)) {
                        if (std::holds_alternative<ArrayVal>(avgRangeVal)) {
                            const auto& sMat = std::get<ArrayVal>(avgRangeVal).matrix;
                            if (r < sMat.size() && c < sMat[r].size()) {
                                try { sum += Evaluator::asNumber(sMat[r][c]); count++; } catch (...) {}
                            }
                        } else {
                            if (r == 0 && c == 0) {
                                try { sum += Evaluator::asNumber(avgRangeVal); count++; } catch (...) {}
                            }
                        }
                    }
                }
            }
        } else {
            if (matchCriteria(rangeVal, critVal)) {
                if (std::holds_alternative<ArrayVal>(avgRangeVal)) {
                    const auto& sMat = std::get<ArrayVal>(avgRangeVal).matrix;
                    if (!sMat.empty() && !sMat[0].empty()) {
                        try { sum += Evaluator::asNumber(sMat[0][0]); count++; } catch (...) {}
                    }
                } else {
                    try { sum += Evaluator::asNumber(avgRangeVal); count++; } catch (...) {}
                }
            }
        }
        if (count == 0) return CellError{"#DIV/0!"};
        return sum / count;
    });

    // AVERAGEIFS(average_range, criteria_range1, criteria1, ...)
    registerFunction("AVERAGEIFS", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() % 2 == 0) return CellError{"#VALUE!"};
        auto avgRangeVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(avgRangeVal)) return avgRangeVal;

        struct CritPair {
            EvalResult range;
            EvalResult crit;
        };
        std::vector<CritPair> pairs;

        for (size_t i = 1; i < args.size(); i += 2) {
            auto rVal = EVAL_ARG(eval, args, i);
            auto cVal = EVAL_ARG(eval, args, i + 1);
            if (Evaluator::isError(rVal)) return rVal;
            if (Evaluator::isError(cVal)) return cVal;
            pairs.push_back({rVal, cVal});
        }

        double sum = 0.0;
        int count = 0;
        if (std::holds_alternative<ArrayVal>(avgRangeVal)) {
            const auto& sMat = std::get<ArrayVal>(avgRangeVal).matrix;
            for (size_t r = 0; r < sMat.size(); r++) {
                for (size_t c = 0; c < sMat[r].size(); c++) {
                    bool allMatch = true;
                    for (const auto& p : pairs) {
                        if (std::holds_alternative<ArrayVal>(p.range)) {
                            const auto& rMat = std::get<ArrayVal>(p.range).matrix;
                            if (r >= rMat.size() || c >= rMat[r].size() || !matchCriteria(rMat[r][c], p.crit)) {
                                allMatch = false; break;
                            }
                        } else {
                            if (r != 0 || c != 0 || !matchCriteria(p.range, p.crit)) {
                                allMatch = false; break;
                            }
                        }
                    }
                    if (allMatch) {
                        try { sum += Evaluator::asNumber(sMat[r][c]); count++; } catch (...) {}
                    }
                }
            }
        } else {
            bool allMatch = true;
            for (const auto& p : pairs) {
                if (std::holds_alternative<ArrayVal>(p.range)) {
                    const auto& rMat = std::get<ArrayVal>(p.range).matrix;
                    if (rMat.empty() || rMat[0].empty() || !matchCriteria(rMat[0][0], p.crit)) {
                        allMatch = false; break;
                    }
                } else {
                    if (!matchCriteria(p.range, p.crit)) {
                        allMatch = false; break;
                    }
                }
            }
            if (allMatch) {
                try { sum += Evaluator::asNumber(avgRangeVal); count++; } catch (...) {}
            }
        }
        if (count == 0) return CellError{"#DIV/0!"};
        return sum / count;
    });

    // LARGE(array, k)
    registerFunction("LARGE", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#N/A"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto kVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(kVal)) return kVal;
        
        std::vector<double> numbers;
        auto err = extractNumbers(arrayVal, numbers);
        if (Evaluator::isError(err)) return err;
        
        int k;
        try {
            k = (int)Evaluator::asNumber(kVal);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
        
        if (k <= 0 || (size_t)k > numbers.size()) return CellError{"#NUM!"};
        
        std::sort(numbers.begin(), numbers.end(), std::greater<double>());
        return numbers[k - 1];
    });

    // SMALL(array, k)
    registerFunction("SMALL", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#N/A"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto kVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(kVal)) return kVal;
        
        std::vector<double> numbers;
        auto err = extractNumbers(arrayVal, numbers);
        if (Evaluator::isError(err)) return err;
        
        int k;
        try {
            k = (int)Evaluator::asNumber(kVal);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
        
        if (k <= 0 || (size_t)k > numbers.size()) return CellError{"#NUM!"};
        
        std::sort(numbers.begin(), numbers.end());
        return numbers[k - 1];
    });

    // RANK(number, ref, [order])
    registerFunction("RANK", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#N/A"};
        auto numVal = EVAL_ARG(eval, args, 0);
        auto refVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(numVal)) return numVal;
        if (Evaluator::isError(refVal)) return refVal;
        
        double number;
        try {
            number = Evaluator::asNumber(numVal);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
        
        int order = 0;
        if (args.size() == 3) {
            auto orderVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(orderVal)) return orderVal;
            try {
                order = (int)Evaluator::asNumber(orderVal);
            } catch (...) {
                return CellError{"#VALUE!"};
            }
        }
        
        std::vector<double> numbers;
        auto err = extractNumbers(refVal, numbers);
        if (Evaluator::isError(err)) return err;
        
        if (std::find(numbers.begin(), numbers.end(), number) == numbers.end()) return CellError{"#N/A"};
        
        if (order == 0) {
            std::sort(numbers.begin(), numbers.end(), std::greater<double>());
        } else {
            std::sort(numbers.begin(), numbers.end());
        }
        
        for (size_t i = 0; i < numbers.size(); ++i) {
            if (numbers[i] == number) return (double)(i + 1);
        }
        return CellError{"#N/A"};
    });

    // PERCENTILE(array, k)
    registerFunction("PERCENTILE", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#N/A"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto kVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(kVal)) return kVal;
        
        std::vector<double> numbers;
        auto err = extractNumbers(arrayVal, numbers);
        if (Evaluator::isError(err)) return err;
        if (numbers.empty()) return CellError{"#NUM!"};
        
        double k;
        try {
            k = Evaluator::asNumber(kVal);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
        if (k < 0.0 || k > 1.0) return CellError{"#NUM!"};
        
        std::sort(numbers.begin(), numbers.end());
        double n = (numbers.size() - 1) * k;
        int i = (int)std::floor(n);
        double f = n - i;
        
        if (i + 1 < numbers.size()) {
            return numbers[i] + (numbers[i + 1] - numbers[i]) * f;
        }
        return numbers[i];
    });

    // QUARTILE(array, quart)
    registerFunction("QUARTILE", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#N/A"};
        auto arrayVal = EVAL_ARG(eval, args, 0);
        auto quartVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrayVal)) return arrayVal;
        if (Evaluator::isError(quartVal)) return quartVal;
        
        std::vector<double> numbers;
        auto err = extractNumbers(arrayVal, numbers);
        if (Evaluator::isError(err)) return err;
        if (numbers.empty()) return CellError{"#NUM!"};
        
        int quart;
        try {
            quart = (int)Evaluator::asNumber(quartVal);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
        
        double k = 0.0;
        if (quart == 0) k = 0.0;
        else if (quart == 1) k = 0.25;
        else if (quart == 2) k = 0.5;
        else if (quart == 3) k = 0.75;
        else if (quart == 4) k = 1.0;
        else return CellError{"#NUM!"};
        
        std::sort(numbers.begin(), numbers.end());
        double n = (numbers.size() - 1) * k;
        int i = (int)std::floor(n);
        double f = n - i;
        
        if (i + 1 < numbers.size()) {
            return numbers[i] + (numbers[i + 1] - numbers[i]) * f;
        }
        return numbers[i];
    });

    // STDEV.P(number1, [number2], ...)
    registerFunction("STDEV.P", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.size() == 0) return CellError{"#DIV/0!"};
        
        double sum = 0;
        for (double d : numbers) sum += d;
        double mean = sum / numbers.size();
        
        double variance = 0;
        for (double d : numbers) variance += (d - mean) * (d - mean);
        
        return std::sqrt(variance / numbers.size());
    });

    // VAR.P(number1, [number2], ...)
    registerFunction("VAR.P", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.size() == 0) return CellError{"#DIV/0!"};
        
        double sum = 0;
        for (double d : numbers) sum += d;
        double mean = sum / numbers.size();
        
        double variance = 0;
        for (double d : numbers) variance += (d - mean) * (d - mean);
        
        return variance / numbers.size();
    });

    // CORREL(array1, array2)
    registerFunction("CORREL", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#N/A"};
        auto array1Val = EVAL_ARG(eval, args, 0);
        auto array2Val = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(array1Val)) return array1Val;
        if (Evaluator::isError(array2Val)) return array2Val;
        
        std::vector<double> x, y;
        auto err1 = extractNumbers(array1Val, x);
        if (Evaluator::isError(err1)) return err1;
        auto err2 = extractNumbers(array2Val, y);
        if (Evaluator::isError(err2)) return err2;
        
        if (x.size() != y.size() || x.empty()) return CellError{"#N/A"};
        if (x.size() == 1) return CellError{"#DIV/0!"};
        
        double sumX = 0, sumY = 0;
        for (double d : x) sumX += d;
        for (double d : y) sumY += d;
        
        double meanX = sumX / x.size();
        double meanY = sumY / y.size();
        
        double num = 0, denX = 0, denY = 0;
        for (size_t i = 0; i < x.size(); ++i) {
            num += (x[i] - meanX) * (y[i] - meanY);
            denX += (x[i] - meanX) * (x[i] - meanX);
            denY += (y[i] - meanY) * (y[i] - meanY);
        }
        
        if (denX == 0 || denY == 0) return CellError{"#DIV/0!"};
        return num / std::sqrt(denX * denY);
    });

    // COVAR(array1, array2)
    registerFunction("COVAR", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#N/A"};
        auto array1Val = EVAL_ARG(eval, args, 0);
        auto array2Val = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(array1Val)) return array1Val;
        if (Evaluator::isError(array2Val)) return array2Val;
        
        std::vector<double> x, y;
        auto err1 = extractNumbers(array1Val, x);
        if (Evaluator::isError(err1)) return err1;
        auto err2 = extractNumbers(array2Val, y);
        if (Evaluator::isError(err2)) return err2;
        
        if (x.size() != y.size() || x.empty()) return CellError{"#N/A"};
        
        double sumX = 0, sumY = 0;
        for (double d : x) sumX += d;
        for (double d : y) sumY += d;
        
        double meanX = sumX / x.size();
        double meanY = sumY / y.size();
        
        double covar = 0;
        for (size_t i = 0; i < x.size(); ++i) {
            covar += (x[i] - meanX) * (y[i] - meanY);
        }
        
        return covar / x.size();
    });

    // FREQUENCY(data_array, bins_array)
    registerFunction("FREQUENCY", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#N/A"};
        auto dataVal = EVAL_ARG(eval, args, 0);
        auto binsVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(dataVal)) return dataVal;
        if (Evaluator::isError(binsVal)) return binsVal;
        
        std::vector<double> data, bins;
        auto err1 = extractNumbers(dataVal, data);
        if (Evaluator::isError(err1)) return err1;
        auto err2 = extractNumbers(binsVal, bins);
        if (Evaluator::isError(err2)) return err2;
        
        if (bins.empty()) {
            ArrayVal result;
            result.matrix.push_back({(double)data.size()});
            return result;
        }
        
        std::vector<double> sorted_bins = bins;
        std::sort(sorted_bins.begin(), sorted_bins.end());
        
        std::vector<int> freqs(sorted_bins.size() + 1, 0);
        for (double d : data) {
            bool placed = false;
            for (size_t i = 0; i < sorted_bins.size(); ++i) {
                if (d <= sorted_bins[i]) {
                    freqs[i]++;
                    placed = true;
                    break;
                }
            }
            if (!placed) {
                freqs[sorted_bins.size()]++;
            }
        }
        
        ArrayVal result;
        for (int count : freqs) {
            result.matrix.push_back({(double)count});
        }
        return result;
    });

    // SUBTOTAL(func_num, ref1, ...)
    registerFunction("SUBTOTAL", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2) return CellError{"#VALUE!"};
        auto funcNumVal = eval.evaluate(args[0].get());
        if (Evaluator::isError(funcNumVal)) return funcNumVal;
        int func_num = 0;
        try { func_num = (int)Evaluator::asNumber(funcNumVal); }
        catch (...) { return CellError{"#VALUE!"}; }

        std::vector<double> numbers;
        for (size_t i = 1; i < args.size(); ++i) {
            auto val = eval.evaluate(args[i].get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }

        auto computeAggregate = [](int f_num, std::vector<double>& nums) -> EvalResult {
            if (f_num >= 101 && f_num <= 111) f_num -= 100;
            if (nums.empty() && f_num != 2 && f_num != 3) {
                if (f_num == 9) return 0.0;
                return CellError{"#DIV/0!"};
            }
            if (f_num == 2 || f_num == 3) return (double)nums.size();
            
            double sum = 0;
            for (double d : nums) sum += d;
            
            switch (f_num) {
                case 1: return sum / nums.size();
                case 4: { double mx = nums[0]; for (double d : nums) if (d > mx) mx = d; return mx; }
                case 5: { double mn = nums[0]; for (double d : nums) if (d < mn) mn = d; return mn; }
                case 6: { double prod = 1; for (double d : nums) prod *= d; return prod; }
                case 7:
                case 10: {
                    if (nums.size() <= 1) return CellError{"#DIV/0!"};
                    double mean = sum / nums.size();
                    double var = 0;
                    for (double d : nums) var += (d - mean) * (d - mean);
                    if (f_num == 7) return std::sqrt(var / (nums.size() - 1));
                    return var / (nums.size() - 1);
                }
                case 8:
                case 11: {
                    if (nums.size() == 0) return CellError{"#DIV/0!"};
                    double mean = sum / nums.size();
                    double var = 0;
                    for (double d : nums) var += (d - mean) * (d - mean);
                    if (f_num == 8) return std::sqrt(var / nums.size());
                    return var / nums.size();
                }
                case 9: return sum;
            }
            return CellError{"#VALUE!"};
        };
        
        return computeAggregate(func_num, numbers);
    });

    // AGGREGATE(func_num, options, ref1, ...)
    registerFunction("AGGREGATE", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3) return CellError{"#VALUE!"};
        auto funcNumVal = eval.evaluate(args[0].get());
        auto optsVal = eval.evaluate(args[1].get());
        if (Evaluator::isError(funcNumVal)) return funcNumVal;
        if (Evaluator::isError(optsVal)) return optsVal;
        
        int func_num = 0;
        try { func_num = (int)Evaluator::asNumber(funcNumVal); }
        catch (...) { return CellError{"#VALUE!"}; }

        std::vector<double> numbers;
        for (size_t i = 2; i < args.size(); ++i) {
            auto val = eval.evaluate(args[i].get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }

        auto computeAggregate = [](int f_num, std::vector<double>& nums) -> EvalResult {
            if (f_num >= 101 && f_num <= 111) f_num -= 100;
            
            double k = 0;
            if (f_num >= 14 && f_num <= 19) {
                if (nums.empty()) return CellError{"#NUM!"};
                k = nums.back();
                nums.pop_back();
            }

            if (nums.empty() && f_num != 2 && f_num != 3) {
                if (f_num == 9) return 0.0;
                return CellError{"#DIV/0!"};
            }
            if (f_num == 2 || f_num == 3) return (double)nums.size();
            
            double sum = 0;
            for (double d : nums) sum += d;
            
            switch (f_num) {
                case 1: return sum / nums.size();
                case 4: { double mx = nums[0]; for (double d : nums) if (d > mx) mx = d; return mx; }
                case 5: { double mn = nums[0]; for (double d : nums) if (d < mn) mn = d; return mn; }
                case 6: { double prod = 1; for (double d : nums) prod *= d; return prod; }
                case 7:
                case 10: {
                    if (nums.size() <= 1) return CellError{"#DIV/0!"};
                    double mean = sum / nums.size();
                    double var = 0;
                    for (double d : nums) var += (d - mean) * (d - mean);
                    if (f_num == 7) return std::sqrt(var / (nums.size() - 1));
                    return var / (nums.size() - 1);
                }
                case 8:
                case 11: {
                    if (nums.size() == 0) return CellError{"#DIV/0!"};
                    double mean = sum / nums.size();
                    double var = 0;
                    for (double d : nums) var += (d - mean) * (d - mean);
                    if (f_num == 8) return std::sqrt(var / nums.size());
                    return var / nums.size();
                }
                case 9: return sum;
                case 12: { // MEDIAN
                    std::sort(nums.begin(), nums.end());
                    size_t mid = nums.size() / 2;
                    if (nums.size() % 2 == 0) return (nums[mid - 1] + nums[mid]) / 2.0;
                    return nums[mid];
                }
                case 13: { // MODE
                    std::vector<double> unique_nums;
                    std::map<double, int> counts;
                    for (double d : nums) {
                        if (counts[d] == 0) unique_nums.push_back(d);
                        counts[d]++;
                    }
                    double mode_val = nums[0];
                    int max_count = 0;
                    for (double d : unique_nums) {
                        if (counts[d] > max_count) {
                            max_count = counts[d];
                            mode_val = d;
                        }
                    }
                    if (max_count == 1) return CellError{"#N/A"};
                    return mode_val;
                }
                case 14: { // LARGE
                    int k_idx = (int)k;
                    if (k_idx <= 0 || (size_t)k_idx > nums.size()) return CellError{"#NUM!"};
                    std::sort(nums.begin(), nums.end(), std::greater<double>());
                    return nums[k_idx - 1];
                }
                case 15: { // SMALL
                    int k_idx = (int)k;
                    if (k_idx <= 0 || (size_t)k_idx > nums.size()) return CellError{"#NUM!"};
                    std::sort(nums.begin(), nums.end());
                    return nums[k_idx - 1];
                }
                case 16: // PERCENTILE
                case 18: { // PERCENTILE.EXC (approx)
                    if (k < 0.0 || k > 1.0) return CellError{"#NUM!"};
                    std::sort(nums.begin(), nums.end());
                    double n = (nums.size() - 1) * k;
                    int i = (int)std::floor(n);
                    double f = n - i;
                    if (i + 1 < nums.size()) return nums[i] + (nums[i + 1] - nums[i]) * f;
                    return nums[i];
                }
                case 17: // QUARTILE
                case 19: { // QUARTILE.EXC (approx)
                    int quart = (int)k;
                    double p = 0.0;
                    if (quart == 0) p = 0.0;
                    else if (quart == 1) p = 0.25;
                    else if (quart == 2) p = 0.5;
                    else if (quart == 3) p = 0.75;
                    else if (quart == 4) p = 1.0;
                    else return CellError{"#NUM!"};
                    
                    std::sort(nums.begin(), nums.end());
                    double n = (nums.size() - 1) * p;
                    int i = (int)std::floor(n);
                    double f = n - i;
                    if (i + 1 < nums.size()) return nums[i] + (nums[i + 1] - nums[i]) * f;
                    return nums[i];
                }
            }
            return CellError{"#VALUE!"};
        };
        
        return computeAggregate(func_num, numbers);
    });
}
