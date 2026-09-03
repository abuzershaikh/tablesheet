#include "../function_registry.h"
#include <cmath>
#include <vector>

void FunctionRegistry::registerFinancialFunctions() {

    // PMT(rate, nper, pv, [fv], [type])
    registerFunction("PMT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 5) return CellError{"#VALUE!"};
        auto rateVal = EVAL_ARG(eval, args, 0);
        auto nperVal = EVAL_ARG(eval, args, 1);
        auto pvVal = EVAL_ARG(eval, args, 2);
        
        EvalResult fvVal = (double)0.0;
        if (args.size() >= 4) {
            fvVal = EVAL_ARG(eval, args, 3);
        }
        
        EvalResult typeVal = (double)0.0;
        if (args.size() == 5) {
            typeVal = EVAL_ARG(eval, args, 4);
        }
        
        auto computePmt = [](const EvalResult& rV, const EvalResult& nV, const EvalResult& pV, const EvalResult& fV, const EvalResult& tV) -> EvalResult {
            if (Evaluator::isError(rV)) return rV;
            if (Evaluator::isError(nV)) return nV;
            if (Evaluator::isError(pV)) return pV;
            if (Evaluator::isError(fV)) return fV;
            if (Evaluator::isError(tV)) return tV;
            
            double rate = Evaluator::asNumber(rV);
            double nper = Evaluator::asNumber(nV);
            double pv = Evaluator::asNumber(pV);
            double fv = std::holds_alternative<Blank>(fV) ? 0.0 : Evaluator::asNumber(fV);
            int type = std::holds_alternative<Blank>(tV) ? 0 : (int)Evaluator::asNumber(tV);
            
            if (rate == 0) {
                if (nper == 0) return CellError{"#NUM!"};
                return -(pv + fv) / nper;
            }
            
            double pvif = std::pow(1.0 + rate, nper);
            if (pvif == 1.0) return CellError{"#DIV/0!"};
            double pmt = (rate * (pv * pvif + fv)) / (pvif - 1.0);
            if (type == 1) pmt /= (1.0 + rate);
            return -pmt;
        };
        
        // Since we only have vectorizeTernary, we'll manually extract if they are 1x1 arrays.
        // We know asNumber handles 1x1 Arrays now, but fully vectorizing 5 args is hard without vectorizeN.
        // We will just evaluate it.
        return computePmt(rateVal, nperVal, pvVal, fvVal, typeVal);
    });

    // NPV(rate, val1, [val2], ...)
    registerFunction("NPV", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2) return CellError{"#VALUE!"};
        auto rateVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(rateVal)) return rateVal;
        double rate = Evaluator::asNumber(rateVal);

        std::vector<double> flows;
        for (size_t i = 1; i < args.size(); i++) {
            auto val = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(val)) return val;
            Evaluator::flattenNumbers(val, flows);
        }

        if (rate == -1.0) return CellError{"#DIV/0!"};
        double npv = 0.0;
        for (size_t i = 0; i < flows.size(); i++) {
            npv += flows[i] / std::pow(1.0 + rate, i + 1);
        }
        return npv;
    });

    // IRR(values, [guess])
    registerFunction("IRR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto valVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(valVal)) return valVal;

        std::vector<double> flows;
        Evaluator::flattenNumbers(valVal, flows);
        if (flows.size() < 2) return CellError{"#NUM!"};

        double rate = 0.1;
        if (args.size() == 2) {
            auto gVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(gVal)) return gVal;
            if (!std::holds_alternative<Blank>(gVal)) rate = Evaluator::asNumber(gVal);
        }

        for (int iter = 0; iter < 100; iter++) {
            double npv = 0.0;
            double dnpv = 0.0;
            for (size_t i = 0; i < flows.size(); i++) {
                npv += flows[i] / std::pow(1.0 + rate, (double)i);
                if (i > 0) {
                    dnpv -= i * flows[i] / std::pow(1.0 + rate, (double)(i + 1));
                }
            }
            if (std::abs(npv) < 1e-7) return rate;
            if (dnpv == 0) break;
            double nextRate = rate - npv / dnpv;
            if (std::isnan(nextRate) || std::isinf(nextRate)) break;
            if (std::abs(nextRate - rate) < 1e-7) return nextRate;
            rate = nextRate;
        }
        return CellError{"#NUM!"};
    });

    // FV(rate, nper, pmt, [pv], [type])
    registerFunction("FV", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 5) return CellError{"#VALUE!"};
        auto rVal = EVAL_ARG(eval, args, 0);
        auto nVal = EVAL_ARG(eval, args, 1);
        auto pVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(rVal)) return rVal;
        if (Evaluator::isError(nVal)) return nVal;
        if (Evaluator::isError(pVal)) return pVal;

        double rate = Evaluator::asNumber(rVal);
        double nper = Evaluator::asNumber(nVal);
        double pmt = Evaluator::asNumber(pVal);
        double pv = 0.0;
        if (args.size() >= 4) {
            auto pvVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(pvVal)) return pvVal;
            if (!std::holds_alternative<Blank>(pvVal)) pv = Evaluator::asNumber(pvVal);
        }
        int type = 0;
        if (args.size() == 5) {
            auto tVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(tVal)) return tVal;
            if (!std::holds_alternative<Blank>(tVal)) type = (int)Evaluator::asNumber(tVal);
        }

        if (rate == 0) return -(pv + pmt * nper);

        double temp = std::pow(1.0 + rate, nper);
        double fv = -pv * temp - pmt * (1.0 + rate * type) * (temp - 1.0) / rate;
        return fv;
    });

    // PV(rate, nper, pmt, [fv], [type])
    registerFunction("PV", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 5) return CellError{"#VALUE!"};
        auto rVal = EVAL_ARG(eval, args, 0);
        auto nVal = EVAL_ARG(eval, args, 1);
        auto pVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(rVal)) return rVal;
        if (Evaluator::isError(nVal)) return nVal;
        if (Evaluator::isError(pVal)) return pVal;

        double rate = Evaluator::asNumber(rVal);
        double nper = Evaluator::asNumber(nVal);
        double pmt = Evaluator::asNumber(pVal);
        double fv = 0.0;
        if (args.size() >= 4) {
            auto fvVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(fvVal)) return fvVal;
            if (!std::holds_alternative<Blank>(fvVal)) fv = Evaluator::asNumber(fvVal);
        }
        int type = 0;
        if (args.size() == 5) {
            auto tVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(tVal)) return tVal;
            if (!std::holds_alternative<Blank>(tVal)) type = (int)Evaluator::asNumber(tVal);
        }

        if (rate == 0) {
            if (nper == 0) return CellError{"#NUM!"};
            return -(fv + pmt * nper);
        }

        double temp = std::pow(1.0 + rate, nper);
        if (temp == 0) return CellError{"#DIV/0!"};
        return -(fv + pmt * (1.0 + rate * type) * (temp - 1.0) / rate) / temp;
    });

    // RATE(nper, pmt, pv, [fv], [type], [guess])
    registerFunction("RATE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 6) return CellError{"#VALUE!"};
        auto nperVal = EVAL_ARG(eval, args, 0);
        auto pmtVal = EVAL_ARG(eval, args, 1);
        auto pvVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(nperVal)) return nperVal;
        if (Evaluator::isError(pmtVal)) return pmtVal;
        if (Evaluator::isError(pvVal)) return pvVal;
        
        double nper = Evaluator::asNumber(nperVal);
        double pmt = Evaluator::asNumber(pmtVal);
        double pv = Evaluator::asNumber(pvVal);
        
        double fv = 0.0;
        if (args.size() >= 4) {
            auto fvVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(fvVal)) return fvVal;
            if (!std::holds_alternative<Blank>(fvVal)) fv = Evaluator::asNumber(fvVal);
        }
        
        int type = 0;
        if (args.size() >= 5) {
            auto typeVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(typeVal)) return typeVal;
            if (!std::holds_alternative<Blank>(typeVal)) type = (int)Evaluator::asNumber(typeVal);
        }
        
        double guess = 0.1;
        if (args.size() == 6) {
            auto guessVal = EVAL_ARG(eval, args, 5);
            if (Evaluator::isError(guessVal)) return guessVal;
            if (!std::holds_alternative<Blank>(guessVal)) guess = Evaluator::asNumber(guessVal);
        }
        
        double rate = guess;
        for (int i = 0; i < 100; ++i) {
            double f, df;
            if (std::abs(rate) < 1e-8) {
                f = pv + pmt * nper + fv;
                return CellError{"#NUM!"}; 
            } else {
                double temp1 = std::pow(1 + rate, nper);
                f = pv * temp1 + pmt * (1 + rate * type) * (temp1 - 1) / rate + fv;
                
                double eps = 1e-6;
                double r2 = rate + eps;
                double temp2 = std::pow(1 + r2, nper);
                double f2 = pv * temp2 + pmt * (1 + r2 * type) * (temp2 - 1) / r2 + fv;
                
                df = (f2 - f) / eps;
            }
            if (std::abs(f) < 1e-7) return rate;
            if (df == 0) break;
            double nextRate = rate - f / df;
            if (std::isnan(nextRate) || std::isinf(nextRate)) break;
            if (std::abs(nextRate - rate) < 1e-7) return nextRate;
            rate = nextRate;
        }
        return CellError{"#NUM!"};
    });

    // NPER(rate, pmt, pv, [fv], [type])
    registerFunction("NPER", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 5) return CellError{"#VALUE!"};
        auto rVal = EVAL_ARG(eval, args, 0);
        auto pVal = EVAL_ARG(eval, args, 1);
        auto pvVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(rVal)) return rVal;
        if (Evaluator::isError(pVal)) return pVal;
        if (Evaluator::isError(pvVal)) return pvVal;

        double rate = Evaluator::asNumber(rVal);
        double pmt = Evaluator::asNumber(pVal);
        double pv = Evaluator::asNumber(pvVal);
        double fv = 0.0;
        if (args.size() >= 4) {
            auto fvVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(fvVal)) return fvVal;
            if (!std::holds_alternative<Blank>(fvVal)) fv = Evaluator::asNumber(fvVal);
        }
        int type = 0;
        if (args.size() == 5) {
            auto tVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(tVal)) return tVal;
            if (!std::holds_alternative<Blank>(tVal)) type = (int)Evaluator::asNumber(tVal);
        }

        if (rate == 0) {
            if (pmt == 0) return CellError{"#NUM!"};
            return -(pv + fv) / pmt;
        }

        double temp = pmt * (1.0 + rate * type) / rate;
        double a = temp - fv;
        double b = pv + temp;
        if (a * b < 0) return CellError{"#NUM!"};
        if (b == 0) return CellError{"#NUM!"};
        
        return std::log(a / b) / std::log(1.0 + rate);
    });

    // IPMT(rate, per, nper, pv, [fv], [type])
    registerFunction("IPMT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 4 || args.size() > 6) return CellError{"#VALUE!"};
        auto rVal = EVAL_ARG(eval, args, 0);
        auto perVal = EVAL_ARG(eval, args, 1);
        auto nVal = EVAL_ARG(eval, args, 2);
        auto pvVal = EVAL_ARG(eval, args, 3);
        if (Evaluator::isError(rVal)) return rVal;
        if (Evaluator::isError(perVal)) return perVal;
        if (Evaluator::isError(nVal)) return nVal;
        if (Evaluator::isError(pvVal)) return pvVal;

        double rate = Evaluator::asNumber(rVal);
        double per = Evaluator::asNumber(perVal);
        double nper = Evaluator::asNumber(nVal);
        double pv = Evaluator::asNumber(pvVal);

        double fv = 0.0;
        if (args.size() >= 5) {
            auto fvVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(fvVal)) return fvVal;
            if (!std::holds_alternative<Blank>(fvVal)) fv = Evaluator::asNumber(fvVal);
        }
        int type = 0;
        if (args.size() == 6) {
            auto tVal = EVAL_ARG(eval, args, 5);
            if (Evaluator::isError(tVal)) return tVal;
            if (!std::holds_alternative<Blank>(tVal)) type = (int)Evaluator::asNumber(tVal);
        }
        
        if (per < 1 || per > nper) return CellError{"#NUM!"};
        
        double pmt = 0;
        if (rate == 0) {
            pmt = -(pv + fv) / nper;
        } else {
            double temp = std::pow(1.0 + rate, nper);
            if (temp == 1.0) return CellError{"#DIV/0!"};
            pmt = - (rate * (pv * temp + fv)) / ((temp - 1.0) * (1.0 + rate * type));
        }

        double ipmt = 0;
        if (rate != 0) {
            double fv_prev = 0;
            if (per > 1) {
                double temp = std::pow(1.0 + rate, per - 1);
                fv_prev = -pv * temp - pmt * (1.0 + rate * type) * (temp - 1.0) / rate;
            } else {
                fv_prev = -pv;
            }
            double balance = -fv_prev;
            if (type == 1) balance += pmt;
            ipmt = -balance * rate;
        }
        return ipmt;
    });

    // PPMT(rate, per, nper, pv, [fv], [type])
    registerFunction("PPMT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 4 || args.size() > 6) return CellError{"#VALUE!"};
        auto rVal = EVAL_ARG(eval, args, 0);
        auto perVal = EVAL_ARG(eval, args, 1);
        auto nVal = EVAL_ARG(eval, args, 2);
        auto pvVal = EVAL_ARG(eval, args, 3);
        if (Evaluator::isError(rVal)) return rVal;
        if (Evaluator::isError(perVal)) return perVal;
        if (Evaluator::isError(nVal)) return nVal;
        if (Evaluator::isError(pvVal)) return pvVal;

        double rate = Evaluator::asNumber(rVal);
        double per = Evaluator::asNumber(perVal);
        double nper = Evaluator::asNumber(nVal);
        double pv = Evaluator::asNumber(pvVal);

        double fv = 0.0;
        if (args.size() >= 5) {
            auto fvVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(fvVal)) return fvVal;
            if (!std::holds_alternative<Blank>(fvVal)) fv = Evaluator::asNumber(fvVal);
        }
        int type = 0;
        if (args.size() == 6) {
            auto tVal = EVAL_ARG(eval, args, 5);
            if (Evaluator::isError(tVal)) return tVal;
            if (!std::holds_alternative<Blank>(tVal)) type = (int)Evaluator::asNumber(tVal);
        }
        
        if (per < 1 || per > nper) return CellError{"#NUM!"};
        
        double pmt = 0;
        if (rate == 0) {
            pmt = -(pv + fv) / nper;
        } else {
            double temp = std::pow(1.0 + rate, nper);
            if (temp == 1.0) return CellError{"#DIV/0!"};
            pmt = - (rate * (pv * temp + fv)) / ((temp - 1.0) * (1.0 + rate * type));
        }

        double ipmt = 0;
        if (rate != 0) {
            double fv_prev = 0;
            if (per > 1) {
                double temp = std::pow(1.0 + rate, per - 1);
                fv_prev = -pv * temp - pmt * (1.0 + rate * type) * (temp - 1.0) / rate;
            } else {
                fv_prev = -pv;
            }
            double balance = -fv_prev;
            if (type == 1) balance += pmt;
            ipmt = -balance * rate;
        }
        return pmt - ipmt;
    });

    // XNPV(rate, values, dates)
    registerFunction("XNPV", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto rVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(rVal)) return rVal;
        double rate = Evaluator::asNumber(rVal);

        auto valVal = EVAL_ARG(eval, args, 1);
        auto dateVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(valVal)) return valVal;
        if (Evaluator::isError(dateVal)) return dateVal;

        std::vector<double> values;
        Evaluator::flattenNumbers(valVal, values);
        
        std::vector<double> dates;
        Evaluator::flattenNumbers(dateVal, dates);

        if (values.size() != dates.size() || values.empty()) return CellError{"#NUM!"};

        double xnpv = 0.0;
        double d0 = dates[0];
        for (size_t i = 0; i < values.size(); i++) {
            double diff = dates[i] - d0;
            if (diff < 0) return CellError{"#NUM!"};
            xnpv += values[i] / std::pow(1.0 + rate, diff / 365.0);
        }
        return xnpv;
    });

    // XIRR(values, dates, [guess])
    registerFunction("XIRR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto valVal = EVAL_ARG(eval, args, 0);
        auto dateVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(valVal)) return valVal;
        if (Evaluator::isError(dateVal)) return dateVal;

        std::vector<double> values;
        Evaluator::flattenNumbers(valVal, values);
        
        std::vector<double> dates;
        Evaluator::flattenNumbers(dateVal, dates);

        if (values.size() != dates.size() || values.size() < 2) return CellError{"#NUM!"};

        double guess = 0.1;
        if (args.size() == 3) {
            auto gVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(gVal)) return gVal;
            if (!std::holds_alternative<Blank>(gVal)) guess = Evaluator::asNumber(gVal);
        }

        double rate = guess;
        double d0 = dates[0];
        for (size_t i = 0; i < dates.size(); i++) {
            if (dates[i] < d0) return CellError{"#NUM!"};
        }

        for (int iter = 0; iter < 100; iter++) {
            double xnpv = 0.0;
            double dxnpv = 0.0;
            for (size_t i = 0; i < values.size(); i++) {
                double diff = (dates[i] - d0) / 365.0;
                xnpv += values[i] / std::pow(1.0 + rate, diff);
                if (diff > 0) {
                    dxnpv -= diff * values[i] / std::pow(1.0 + rate, diff + 1.0);
                }
            }
            if (std::abs(xnpv) < 1e-7) return rate;
            if (dxnpv == 0) break;
            double nextRate = rate - xnpv / dxnpv;
            if (std::isnan(nextRate) || std::isinf(nextRate)) break;
            if (std::abs(nextRate - rate) < 1e-7) return nextRate;
            rate = nextRate;
        }
        return CellError{"#NUM!"};
    });

    // SLN(cost, salvage, life)
    registerFunction("SLN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto cVal = EVAL_ARG(eval, args, 0);
        auto sVal = EVAL_ARG(eval, args, 1);
        auto lVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(cVal)) return cVal;
        if (Evaluator::isError(sVal)) return sVal;
        if (Evaluator::isError(lVal)) return lVal;

        double cost = Evaluator::asNumber(cVal);
        double salvage = Evaluator::asNumber(sVal);
        double life = Evaluator::asNumber(lVal);

        if (life == 0) return CellError{"#DIV/0!"};
        return (cost - salvage) / life;
    });

    // SYD(cost, salvage, life, per)
    registerFunction("SYD", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 4) return CellError{"#VALUE!"};
        auto cVal = EVAL_ARG(eval, args, 0);
        auto sVal = EVAL_ARG(eval, args, 1);
        auto lVal = EVAL_ARG(eval, args, 2);
        auto pVal = EVAL_ARG(eval, args, 3);
        if (Evaluator::isError(cVal)) return cVal;
        if (Evaluator::isError(sVal)) return sVal;
        if (Evaluator::isError(lVal)) return lVal;
        if (Evaluator::isError(pVal)) return pVal;

        double cost = Evaluator::asNumber(cVal);
        double salvage = Evaluator::asNumber(sVal);
        double life = Evaluator::asNumber(lVal);
        double per = Evaluator::asNumber(pVal);

        if (life == 0) return CellError{"#DIV/0!"};
        if (per < 1 || per > life) return CellError{"#NUM!"};
        return (cost - salvage) * (life - per + 1.0) * 2.0 / (life * (life + 1.0));
    });

    // DB(cost, salvage, life, period, [month])
    registerFunction("DB", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 4 || args.size() > 5) return CellError{"#VALUE!"};
        auto cVal = EVAL_ARG(eval, args, 0);
        auto sVal = EVAL_ARG(eval, args, 1);
        auto lVal = EVAL_ARG(eval, args, 2);
        auto pVal = EVAL_ARG(eval, args, 3);
        if (Evaluator::isError(cVal)) return cVal;
        if (Evaluator::isError(sVal)) return sVal;
        if (Evaluator::isError(lVal)) return lVal;
        if (Evaluator::isError(pVal)) return pVal;

        double cost = Evaluator::asNumber(cVal);
        double salvage = Evaluator::asNumber(sVal);
        double life = Evaluator::asNumber(lVal);
        double period = Evaluator::asNumber(pVal);
        
        double month = 12.0;
        if (args.size() == 5) {
            auto mVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(mVal)) return mVal;
            if (!std::holds_alternative<Blank>(mVal)) month = Evaluator::asNumber(mVal);
        }

        if (cost < 0 || salvage < 0 || life <= 0 || period <= 0 || month <= 0 || month > 12) return CellError{"#NUM!"};
        if (period > life + 1) return CellError{"#NUM!"};
        if (period == life + 1 && month == 12.0) return CellError{"#NUM!"};

        double rate = 1.0 - std::pow(salvage / cost, 1.0 / life);
        rate = std::round(rate * 1000.0) / 1000.0;

        double totalDepreciation = 0.0;
        double currentDepreciation = 0.0;

        for (int i = 1; i <= period; ++i) {
            if (i == 1) {
                currentDepreciation = cost * rate * month / 12.0;
            } else if (i == std::floor(life) + 1) {
                currentDepreciation = (cost - totalDepreciation) * rate * (12.0 - month) / 12.0;
            } else {
                currentDepreciation = (cost - totalDepreciation) * rate;
            }
            if (i < period) {
                totalDepreciation += currentDepreciation;
            }
        }
        return currentDepreciation;
    });
}
