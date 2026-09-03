#include "../function_registry.h"
#include <cmath>
#include <string>
#include <vector>
#include <sstream>
#include <iomanip>

void FunctionRegistry::registerEngineeringFunctions() {

    // BIN2DEC(number)
    registerFunction("BIN2DEC", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        std::string str = Evaluator::asString(val);
        if (str.length() > 10) return CellError{"#NUM!"};
        try {
            long long dec = std::stoll(str, nullptr, 2);
            if (str.length() == 10 && str[0] == '1') dec -= 1024;
            return (double)dec;
        } catch (...) {
            return CellError{"#NUM!"};
        }
    });

    // DEC2BIN(number, [places])
    registerFunction("DEC2BIN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        long long num = (long long)Evaluator::asNumber(val);
        if (num < -512 || num > 511) return CellError{"#NUM!"};

        std::string res = "";
        if (num >= 0) {
            if (num == 0) res = "0";
            while (num > 0) {
                res = (num % 2 == 0 ? "0" : "1") + res;
                num /= 2;
            }
        } else {
            // 10-bit two's complement
            num = 1024 + num;
            for (int i = 9; i >= 0; i--) {
                res += ((num >> i) & 1) ? "1" : "0";
            }
        }

        if (args.size() == 2) {
            auto pVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(pVal)) return pVal;
            int places = (int)Evaluator::asNumber(pVal);
            while ((int)res.length() < places) res = "0" + res;
        }
        return res;
    });

    // HEX2DEC(number)
    registerFunction("HEX2DEC", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        std::string str = Evaluator::asString(val);
        if (str.length() > 10) return CellError{"#NUM!"};
        try {
            long long dec = std::stoll(str, nullptr, 16);
            if (str.length() == 10 && str[0] >= '8') dec -= 1099511627776LL;
            return (double)dec;
        } catch (...) {
            return CellError{"#NUM!"};
        }
    });

    // DEC2HEX(number, [places])
    registerFunction("DEC2HEX", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        long long num = (long long)Evaluator::asNumber(val);

        std::stringstream ss;
        ss << std::hex << std::uppercase << num;
        std::string res = ss.str();

        if (args.size() == 2) {
            auto pVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(pVal)) return pVal;
            int places = (int)Evaluator::asNumber(pVal);
            while ((int)res.length() < places) res = "0" + res;
        }
        return res;
    });

    // OCT2DEC(number)
    registerFunction("OCT2DEC", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        std::string str = Evaluator::asString(val);
        if (str.length() > 10) return CellError{"#NUM!"};
        try {
            long long dec = std::stoll(str, nullptr, 8);
            if (str.length() == 10 && str[0] >= '4') dec -= 1073741824LL;
            return (double)dec;
        } catch (...) {
            return CellError{"#NUM!"};
        }
    });

    // DEC2OCT(number, [places])
    registerFunction("DEC2OCT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        long long num = (long long)Evaluator::asNumber(val);

        std::stringstream ss;
        ss << std::oct << num;
        std::string res = ss.str();

        if (args.size() == 2) {
            auto pVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(pVal)) return pVal;
            int places = (int)Evaluator::asNumber(pVal);
            while ((int)res.length() < places) res = "0" + res;
        }
        return res;
    });

    // BITAND(number1, number2)
    registerFunction("BITAND", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto n1 = EVAL_ARG(eval, args, 0);
        auto n2 = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(n1)) return n1;
        if (Evaluator::isError(n2)) return n2;
        long long a = (long long)Evaluator::asNumber(n1);
        long long b = (long long)Evaluator::asNumber(n2);
        return (double)(a & b);
    });

    // BITOR(number1, number2)
    registerFunction("BITOR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto n1 = EVAL_ARG(eval, args, 0);
        auto n2 = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(n1)) return n1;
        if (Evaluator::isError(n2)) return n2;
        long long a = (long long)Evaluator::asNumber(n1);
        long long b = (long long)Evaluator::asNumber(n2);
        return (double)(a | b);
    });

    // BITXOR(number1, number2)
    registerFunction("BITXOR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto n1 = EVAL_ARG(eval, args, 0);
        auto n2 = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(n1)) return n1;
        if (Evaluator::isError(n2)) return n2;
        long long a = (long long)Evaluator::asNumber(n1);
        long long b = (long long)Evaluator::asNumber(n2);
        return (double)(a ^ b);
    });

    // BITLSHIFT(number, shift_amount)
    registerFunction("BITLSHIFT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto n1 = EVAL_ARG(eval, args, 0);
        auto n2 = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(n1)) return n1;
        if (Evaluator::isError(n2)) return n2;
        long long a = (long long)Evaluator::asNumber(n1);
        int shift = (int)Evaluator::asNumber(n2);
        if (shift < 0) return CellError{"#NUM!"};
        return (double)(a << shift);
    });

    // BITRSHIFT(number, shift_amount)
    registerFunction("BITRSHIFT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto n1 = EVAL_ARG(eval, args, 0);
        auto n2 = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(n1)) return n1;
        if (Evaluator::isError(n2)) return n2;
        long long a = (long long)Evaluator::asNumber(n1);
        int shift = (int)Evaluator::asNumber(n2);
        if (shift < 0) return CellError{"#NUM!"};
        return (double)(a >> shift);
    });

    // COMPLEX(real_num, i_num, [suffix])
    registerFunction("COMPLEX", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto rVal = EVAL_ARG(eval, args, 0);
        auto iVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(rVal)) return rVal;
        if (Evaluator::isError(iVal)) return iVal;

        double r = Evaluator::asNumber(rVal);
        double i = Evaluator::asNumber(iVal);
        std::string suffix = "i";
        if (args.size() == 3) {
            auto sVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(sVal)) return sVal;
            suffix = Evaluator::asString(sVal);
        }

        char buf[64];
        if (i >= 0) {
            snprintf(buf, sizeof(buf), "%.0f+%.0f%s", r, i, suffix.c_str());
        } else {
            snprintf(buf, sizeof(buf), "%.0f%.0f%s", r, i, suffix.c_str());
        }
        return std::string(buf);
    });

    // CONVERT(number, from_unit, to_unit)
    registerFunction("CONVERT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto nVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto tVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(nVal)) return nVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(tVal)) return tVal;

        double val = Evaluator::asNumber(nVal);
        std::string from = Evaluator::asString(fVal);
        std::string to = Evaluator::asString(tVal);

        // Distance conversions to meters
        auto toMeters = [](double v, const std::string& u) -> double {
            if (u == "m") return v;
            if (u == "cm") return v / 100.0;
            if (u == "mm") return v / 1000.0;
            if (u == "in") return v * 0.0254;
            if (u == "ft") return v * 0.3048;
            if (u == "yd") return v * 0.9144;
            if (u == "km") return v * 1000.0;
            return v;
        };

        auto fromMeters = [](double m, const std::string& u) -> double {
            if (u == "m") return m;
            if (u == "cm") return m * 100.0;
            if (u == "mm") return m * 1000.0;
            if (u == "in") return m / 0.0254;
            if (u == "ft") return m / 0.3048;
            if (u == "yd") return m / 0.9144;
            if (u == "km") return m / 1000.0;
            return m;
        };

        // Temperature conversions
        if (from == "C" && to == "F") return (val * 9.0 / 5.0) + 32.0;
        if (from == "F" && to == "C") return (val - 32.0) * 5.0 / 9.0;
        if (from == "C" && to == "K") return val + 273.15;
        if (from == "K" && to == "C") return val - 273.15;

        double meters = toMeters(val, from);
        return fromMeters(meters, to);
    });
}
