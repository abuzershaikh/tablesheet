#include "../function_registry.h"
#include "../spreadsheet_compute.h"
#include <cmath>
#include <random>
#include <regex>

extern SpreadsheetCompute* g_computeEngine;

void FunctionRegistry::registerMathFunctions() {
    
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

    // SUM(number1, [number2], ...)
    registerFunction("SUM", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (g_computeEngine) return g_computeEngine->sumRange(numbers);
        double sum = 0;
        for(double d : numbers) sum += d;
        return sum;
    });

    // AVERAGE(number1, [number2], ...)
    registerFunction("AVERAGE", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.empty()) return CellError{"#DIV/0!"};
        if (g_computeEngine) return g_computeEngine->averageRange(numbers);
        double sum = 0;
        for(double d : numbers) sum += d;
        return sum / numbers.size();
    });

    // ABS(number)
    registerFunction("ABS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return std::abs(Evaluator::asNumber(val));
    });

    // ROUND(number, num_digits)
    registerFunction("ROUND", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto digits = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(digits)) return digits;
        
        double num = Evaluator::asNumber(val);
        double dec = std::floor(Evaluator::asNumber(digits));
        if (std::isnan(num) || std::isnan(dec) || std::isinf(num) || std::isinf(dec)) return CellError{"#NUM!"};
        double factor = std::pow(10.0, dec);
        return std::round(num * factor) / factor;
    });

    // ROUNDUP(number, num_digits)
    registerFunction("ROUNDUP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto digits = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(digits)) return digits;
        
        double num = Evaluator::asNumber(val);
        double dec = std::floor(Evaluator::asNumber(digits));
        if (std::isnan(num) || std::isnan(dec) || std::isinf(num) || std::isinf(dec)) return CellError{"#NUM!"};
        
        double factor = std::pow(10.0, dec);
        double scaled = num * factor;
        double rounded = (num >= 0) ? std::ceil(scaled - 1e-12) : std::floor(scaled + 1e-12);
        return rounded / factor;
    });

    // ROUNDDOWN(number, num_digits)
    registerFunction("ROUNDDOWN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto digits = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(digits)) return digits;
        
        double num = Evaluator::asNumber(val);
        double dec = std::floor(Evaluator::asNumber(digits));
        if (std::isnan(num) || std::isnan(dec) || std::isinf(num) || std::isinf(dec)) return CellError{"#NUM!"};
        
        double factor = std::pow(10.0, dec);
        double scaled = num * factor;
        double rounded = (num >= 0) ? std::floor(scaled + 1e-12) : std::ceil(scaled - 1e-12);
        return rounded / factor;
    });

    // CEILING(number, significance)
    registerFunction("CEILING", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto sig = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(sig)) return sig;
        
        double num = Evaluator::asNumber(val);
        double s = Evaluator::asNumber(sig);
        if ((num > 0 && s < 0) || (num < 0 && s > 0)) return CellError{"#NUM!"};
        if (s == 0) return 0.0;
        return std::ceil(num / s) * s;
    });

    // FLOOR(number, significance)
    registerFunction("FLOOR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto sig = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(sig)) return sig;
        
        double num = Evaluator::asNumber(val);
        double s = Evaluator::asNumber(sig);
        if ((num > 0 && s < 0) || (num < 0 && s > 0)) return CellError{"#NUM!"};
        // Excel behavior: when significance is 0, return 0 (consistent with CEILING)
        if (s == 0) return 0.0;
        return std::floor(num / s) * s;
    });

    // PI()
    registerFunction("PI", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (!args.empty()) return CellError{"#VALUE!"};
        return M_PI;
    });

    // POWER(number, power)
    registerFunction("POWER", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto pwr = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(pwr)) return pwr;
        double n = Evaluator::asNumber(val);
        double p = Evaluator::asNumber(pwr);
        if (std::isnan(n) || std::isnan(p) || std::isinf(n) || std::isinf(p)) return CellError{"#NUM!"};
        if (n == 0 && p < 0) return CellError{"#DIV/0!"};
        if (n < 0 && std::floor(p) != p) return CellError{"#NUM!"};
        return std::pow(n, p);
    });

    // MOD(number, divisor)
    registerFunction("MOD", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto div = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(div)) return div;
        
        double num = Evaluator::asNumber(val);
        double d = Evaluator::asNumber(div);
        if (d == 0) return CellError{"#DIV/0!"};
        // Excel-compatible MOD: result has same sign as divisor
        // Formula: num - d * FLOOR(num/d)
        return num - d * std::floor(num / d);
    });

    // QUOTIENT(numerator, denominator)
    registerFunction("QUOTIENT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto div = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(div)) return div;
        
        double num = Evaluator::asNumber(val);
        double d = Evaluator::asNumber(div);
        if (d == 0) return CellError{"#DIV/0!"};
        return std::trunc(num / d);
    });

    // RANDBETWEEN(bottom, top)
    registerFunction("RANDBETWEEN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto bottomVal = EVAL_ARG(eval, args, 0);
        auto topVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(bottomVal)) return bottomVal;
        if (Evaluator::isError(topVal)) return topVal;
        
        int bottom = (int)Evaluator::asNumber(bottomVal);
        int top = (int)Evaluator::asNumber(topVal);
        if (bottom > top) return CellError{"#NUM!"};
        
        static std::random_device rd;
        thread_local std::mt19937 gen(rd());
        std::uniform_int_distribution<> dis(bottom, top);
        return (double)dis(gen);
    });

    // RAND()
    registerFunction("RAND", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (!args.empty()) return CellError{"#VALUE!"};
        static std::random_device rd;
        thread_local std::mt19937 gen(rd());
        std::uniform_real_distribution<> dis(0.0, 1.0);
        return dis(gen);
    });

    // Helper for criteria matching in COUNTIF, SUMIF, SUMIFS
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
        static thread_local std::string cachedPattern;
        static thread_local std::regex cachedRegex;
        static thread_local bool isValid = false;

        if (regexStr != cachedPattern) {
            cachedPattern = regexStr;
            try {
                cachedRegex = std::regex(regexStr, std::regex_constants::icase);
                isValid = true;
            } catch (...) {
                isValid = false;
            }
        }

        if (isValid) {
            try {
                bool matched = std::regex_match(cellStr, cachedRegex);
                if (op == "<>") return !matched;
                return matched;
            } catch (...) {
                // If matching throws, fallback
            }
        }

        if (op == "<>") return cellStr != valPart;
        return cellStr == valPart;
    };

    // COUNTIF(range, criteria)
    registerFunction("COUNTIF", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto rangeVal = EVAL_ARG(eval, args, 0);
        auto critVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(rangeVal)) return rangeVal;
        if (Evaluator::isError(critVal)) return critVal;

        std::vector<EvalResult> cells;
        if (std::holds_alternative<ArrayVal>(rangeVal)) {
            for (const auto& row : std::get<ArrayVal>(rangeVal).matrix) {
                for (const auto& cell : row) cells.push_back(cell);
            }
        } else {
            cells.push_back(rangeVal);
        }

        int count = 0;
        for (const auto& cell : cells) {
            if (matchCriteria(cell, critVal)) count++;
        }
        return (double)count;
    });

    // SUMIF(range, criteria, [sum_range])
    registerFunction("SUMIF", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto rangeVal = EVAL_ARG(eval, args, 0);
        auto critVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(rangeVal)) return rangeVal;
        if (Evaluator::isError(critVal)) return critVal;

        auto sumRangeVal = (args.size() == 3) ? EVAL_ARG(eval, args, 2) : rangeVal;
        if (Evaluator::isError(sumRangeVal)) return sumRangeVal;

        double sum = 0.0;
        if (std::holds_alternative<ArrayVal>(rangeVal)) {
            const auto& rMat = std::get<ArrayVal>(rangeVal).matrix;
            for (size_t r = 0; r < rMat.size(); r++) {
                for (size_t c = 0; c < rMat[r].size(); c++) {
                    if (matchCriteria(rMat[r][c], critVal)) {
                        if (std::holds_alternative<ArrayVal>(sumRangeVal)) {
                            const auto& sMat = std::get<ArrayVal>(sumRangeVal).matrix;
                            if (r < sMat.size() && c < sMat[r].size()) {
                                sum += Evaluator::asNumber(sMat[r][c]);
                            }
                        } else {
                            if (r == 0 && c == 0) sum += Evaluator::asNumber(sumRangeVal);
                        }
                    }
                }
            }
        } else {
            if (matchCriteria(rangeVal, critVal)) {
                if (std::holds_alternative<ArrayVal>(sumRangeVal)) {
                    const auto& sMat = std::get<ArrayVal>(sumRangeVal).matrix;
                    if (!sMat.empty() && !sMat[0].empty()) sum += Evaluator::asNumber(sMat[0][0]);
                } else {
                    sum += Evaluator::asNumber(sumRangeVal);
                }
            }
        }
        return sum;
    });

    // SUMIFS(sum_range, criteria_range1, criteria1, ...)
    registerFunction("SUMIFS", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() % 2 == 0) return CellError{"#VALUE!"};
        auto sumRangeVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(sumRangeVal)) return sumRangeVal;

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
        if (std::holds_alternative<ArrayVal>(sumRangeVal)) {
            const auto& sMat = std::get<ArrayVal>(sumRangeVal).matrix;
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
                    if (allMatch) sum += Evaluator::asNumber(sMat[r][c]);
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
            if (allMatch) sum += Evaluator::asNumber(sumRangeVal);
        }
        return sum;
    });

    // SQRT(number)
    registerFunction("SQRT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double num = Evaluator::asNumber(val);
        if (num < 0) return CellError{"#NUM!"};
        return std::sqrt(num);
    });

    // PRODUCT(number1, [number2], ...)
    registerFunction("PRODUCT", [extractNumbers](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        std::vector<double> numbers;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            auto err = extractNumbers(val, numbers);
            if (Evaluator::isError(err)) return err;
        }
        if (numbers.empty()) return 0.0;
        double prod = 1.0;
        for (double d : numbers) prod *= d;
        return prod;
    });

    // INT(number)
    registerFunction("INT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return std::floor(Evaluator::asNumber(val));
    });

    // TRUNC(number, [num_digits])
    registerFunction("TRUNC", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double digits = 0;
        if (args.size() == 2) {
            auto digVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(digVal)) return digVal;
            digits = std::floor(Evaluator::asNumber(digVal));
        }
        double num = Evaluator::asNumber(val);
        double factor = std::pow(10.0, digits);
        return std::trunc(num * factor) / factor;
    });

    // ROUNDUP(number, num_digits)
    registerFunction("ROUNDUP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto digits = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(digits)) return digits;
        double num = Evaluator::asNumber(val);
        double dec = std::floor(Evaluator::asNumber(digits));
        double factor = std::pow(10.0, dec);
        if (num > 0) return std::ceil(num * factor) / factor;
        return std::floor(num * factor) / factor;
    });

    // ROUNDDOWN(number, num_digits)
    registerFunction("ROUNDDOWN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto digits = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(digits)) return digits;
        double num = Evaluator::asNumber(val);
        double dec = std::floor(Evaluator::asNumber(digits));
        double factor = std::pow(10.0, dec);
        if (num > 0) return std::floor(num * factor) / factor;
        return std::ceil(num * factor) / factor;
    });

    // SUMPRODUCT(array1, [array2], ...)
    registerFunction("SUMPRODUCT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        std::vector<std::vector<double>> arrays;
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            std::vector<double> flatArr;
            if (std::holds_alternative<ArrayVal>(val)) {
                for (const auto& row : std::get<ArrayVal>(val).matrix) {
                    for (const auto& cell : row) {
                        try {
                            flatArr.push_back(Evaluator::asNumber(cell));
                        } catch (...) {
                            flatArr.push_back(0.0);
                        }
                    }
                }
            } else {
                try {
                    flatArr.push_back(Evaluator::asNumber(val));
                } catch (...) {
                    flatArr.push_back(0.0);
                }
            }
            arrays.push_back(std::move(flatArr));
        }
        size_t minSize = arrays[0].size();
        for (const auto& arr : arrays) {
            if (arr.size() != minSize) return CellError{"#VALUE!"};
        }
        double sum = 0.0;
        for (size_t i = 0; i < minSize; ++i) {
            double prod = 1.0;
            for (const auto& arr : arrays) {
                prod *= arr[i];
            }
            sum += prod;
        }
        return sum;
    });

    // EXP(number)
    registerFunction("EXP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return std::exp(Evaluator::asNumber(val));
    });

    // LN(number)
    registerFunction("LN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double num = Evaluator::asNumber(val);
        if (num <= 0) return CellError{"#NUM!"};
        return std::log(num);
    });

    // LOG(number, [base])
    registerFunction("LOG", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 1 || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double num = Evaluator::asNumber(val);
        if (num <= 0) return CellError{"#NUM!"};
        double base = 10.0;
        if (args.size() == 2) {
            auto bVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(bVal)) return bVal;
            base = Evaluator::asNumber(bVal);
            if (base <= 0 || base == 1) return CellError{"#NUM!"};
        }
        return std::log(num) / std::log(base);
    });

    // LOG10(number)
    registerFunction("LOG10", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double num = Evaluator::asNumber(val);
        if (num <= 0) return CellError{"#NUM!"};
        return std::log10(num);
    });

    // FACT(number)
    registerFunction("FACT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double num = std::floor(Evaluator::asNumber(val));
        if (num < 0) return CellError{"#NUM!"};
        double res = 1;
        for (double i = 2; i <= num; ++i) res *= i;
        return res;
    });

    // COMBIN(number, number_chosen)
    registerFunction("COMBIN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto nVal = EVAL_ARG(eval, args, 0);
        auto kVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(nVal)) return nVal;
        if (Evaluator::isError(kVal)) return kVal;
        double n = std::floor(Evaluator::asNumber(nVal));
        double k = std::floor(Evaluator::asNumber(kVal));
        if (n < 0 || k < 0 || n < k) return CellError{"#NUM!"};
        if (k == 0) return 1.0;
        if (k > n / 2) k = n - k;
        double res = 1;
        for (double i = 1; i <= k; ++i) {
            res = res * (n - i + 1) / i;
        }
        return std::floor(res + 0.5);
    });

    // PERMUT(number, number_chosen)
    registerFunction("PERMUT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto nVal = EVAL_ARG(eval, args, 0);
        auto kVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(nVal)) return nVal;
        if (Evaluator::isError(kVal)) return kVal;
        double n = std::floor(Evaluator::asNumber(nVal));
        double k = std::floor(Evaluator::asNumber(kVal));
        if (n < 0 || k < 0 || n < k) return CellError{"#NUM!"};
        double res = 1;
        for (double i = n - k + 1; i <= n; ++i) {
            res *= i;
        }
        return std::floor(res + 0.5);
    });

    // SIN(number)
    registerFunction("SIN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return std::sin(Evaluator::asNumber(val));
    });

    // COS(number)
    registerFunction("COS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return std::cos(Evaluator::asNumber(val));
    });

    // TAN(number)
    registerFunction("TAN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return std::tan(Evaluator::asNumber(val));
    });

    // ASIN(number)
    registerFunction("ASIN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double num = Evaluator::asNumber(val);
        if (num < -1.0 || num > 1.0) return CellError{"#NUM!"};
        return std::asin(num);
    });

    // ACOS(number)
    registerFunction("ACOS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        double num = Evaluator::asNumber(val);
        if (num < -1.0 || num > 1.0) return CellError{"#NUM!"};
        return std::acos(num);
    });

    // ATAN(number)
    registerFunction("ATAN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return std::atan(Evaluator::asNumber(val));
    });

    // ATAN2(x_num, y_num)
    registerFunction("ATAN2", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto xVal = EVAL_ARG(eval, args, 0);
        auto yVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(xVal)) return xVal;
        if (Evaluator::isError(yVal)) return yVal;
        double x = Evaluator::asNumber(xVal);
        double y = Evaluator::asNumber(yVal);
        if (x == 0 && y == 0) return CellError{"#DIV/0!"};
        return std::atan2(y, x);
    });

    // RADIANS(angle)
    registerFunction("RADIANS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return Evaluator::asNumber(val) * M_PI / 180.0;
    });

    // DEGREES(angle)
    registerFunction("DEGREES", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return Evaluator::asNumber(val) * 180.0 / M_PI;
    });

    auto processIsEvenOdd = [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args, bool isEven) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        
        std::function<EvalResult(const EvalResult&)> process = [&](const EvalResult& v) -> EvalResult {
            if (std::holds_alternative<ArrayVal>(v)) {
                ArrayVal res;
                for (const auto& row : std::get<ArrayVal>(v).matrix) {
                    std::vector<EvalResult> newRow;
                    for (const auto& cell : row) {
                        newRow.push_back(process(cell));
                    }
                    res.matrix.push_back(newRow);
                }
                return res;
            }
            if (std::holds_alternative<CellError>(v)) return v;
            if (std::holds_alternative<Blank>(v)) return isEven; 
            if (std::holds_alternative<bool>(v)) return CellError{"#VALUE!"}; 
            
            double num = Evaluator::asNumber(v);
            if (std::isnan(num) || std::isinf(num)) return CellError{"#VALUE!"};
            long long int_val = static_cast<long long>(std::trunc(num));
            return isEven ? ((int_val % 2) == 0) : ((int_val % 2) != 0);
        };
        return process(val);
    };

    // ISEVEN(number)
    registerFunction("ISEVEN", [processIsEvenOdd](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return processIsEvenOdd(eval, args, true);
    });

    // ISODD(number)
    registerFunction("ISODD", [processIsEvenOdd](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return processIsEvenOdd(eval, args, false);
    });
}
