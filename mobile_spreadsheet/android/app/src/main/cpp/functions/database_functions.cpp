#include "../function_registry.h"
#include <vector>
#include <string>
#include <cmath>
#include <limits>

void FunctionRegistry::registerDatabaseFunctions() {

    auto matchCriteria = [](const std::vector<std::vector<EvalResult>>& dbMat, const std::vector<std::vector<EvalResult>>& critMat, size_t rowIdx) {
        if (critMat.size() < 2) return true;
        bool anyMatch = false;
        for (size_t cr = 1; cr < critMat.size(); cr++) {
            bool allMatch = true;
            for (size_t cc = 0; cc < critMat[0].size(); cc++) {
                std::string header = Evaluator::asString(critMat[0][cc]);
                std::string critVal = Evaluator::asString(critMat[cr][cc]);
                if (critVal.empty()) continue;
                
                int dbCol = -1;
                for (size_t c = 0; c < dbMat[0].size(); c++) {
                    if (Evaluator::asString(dbMat[0][c]) == header) {
                        dbCol = (int)c;
                        break;
                    }
                }
                if (dbCol >= 0 && dbCol < (int)dbMat[rowIdx].size()) {
                    std::string cellVal = Evaluator::asString(dbMat[rowIdx][dbCol]);
                    if (cellVal != critVal) {
                        allMatch = false;
                        break;
                    }
                } else {
                    allMatch = false;
                    break;
                }
            }
            if (allMatch) {
                anyMatch = true;
                break;
            }
        }
        return anyMatch;
    };

    // DSUM(database, field, criteria)
    registerFunction("DSUM", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return 0.0;

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        double sum = 0.0;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                sum += Evaluator::asNumber(mat[r][fieldIdx]);
            }
        }
        return sum;
    });

    // DAVERAGE(database, field, criteria)
    registerFunction("DAVERAGE", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return CellError{"#DIV/0!"};

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        double sum = 0.0;
        int count = 0;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                sum += Evaluator::asNumber(mat[r][fieldIdx]);
                count++;
            }
        }
        if (count == 0) return CellError{"#DIV/0!"};
        return sum / count;
    });

    // DCOUNT(database, field, criteria)
    registerFunction("DCOUNT", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return 0.0;

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        int count = 0;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r) && std::holds_alternative<double>(mat[r][fieldIdx])) {
                count++;
            }
        }
        return (double)count;
    });

    // DGET(database, field, criteria)
    registerFunction("DGET", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return CellError{"#VALUE!"};

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        int count = 0;
        EvalResult result = CellError{"#VALUE!"};
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                count++;
                if (count > 1) return CellError{"#NUM!"};
                result = mat[r][fieldIdx];
            }
        }
        return result;
    });

    // DMAX(database, field, criteria)
    registerFunction("DMAX", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return 0.0;

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        double maxVal = -std::numeric_limits<double>::infinity();
        bool found = false;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                if (std::holds_alternative<double>(mat[r][fieldIdx])) {
                    double val = std::get<double>(mat[r][fieldIdx]);
                    if (!found || val > maxVal) { maxVal = val; found = true; }
                }
            }
        }
        return found ? maxVal : 0.0;
    });

    // DMIN(database, field, criteria)
    registerFunction("DMIN", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return 0.0;

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        double minVal = std::numeric_limits<double>::infinity();
        bool found = false;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                if (std::holds_alternative<double>(mat[r][fieldIdx])) {
                    double val = std::get<double>(mat[r][fieldIdx]);
                    if (!found || val < minVal) { minVal = val; found = true; }
                }
            }
        }
        return found ? minVal : 0.0;
    });

    // DPRODUCT(database, field, criteria)
    registerFunction("DPRODUCT", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return 0.0;

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        double prod = 1.0;
        bool found = false;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                if (std::holds_alternative<double>(mat[r][fieldIdx])) {
                    prod *= std::get<double>(mat[r][fieldIdx]);
                    found = true;
                }
            }
        }
        return found ? prod : 0.0;
    });

    // DCOUNTA(database, field, criteria)
    registerFunction("DCOUNTA", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return 0.0;

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        int count = 0;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                if (!std::holds_alternative<std::string>(mat[r][fieldIdx]) || !std::get<std::string>(mat[r][fieldIdx]).empty()) {
                    count++;
                }
            }
        }
        return (double)count;
    });

    // DSTDEV(database, field, criteria)
    registerFunction("DSTDEV", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return CellError{"#DIV/0!"};

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        std::vector<double> vals;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                if (std::holds_alternative<double>(mat[r][fieldIdx])) {
                    vals.push_back(std::get<double>(mat[r][fieldIdx]));
                }
            }
        }
        if (vals.size() <= 1) return CellError{"#DIV/0!"};
        double sum = 0.0;
        for (double v : vals) sum += v;
        double mean = sum / vals.size();
        double sqSum = 0.0;
        for (double v : vals) sqSum += (v - mean) * (v - mean);
        return std::sqrt(sqSum / (vals.size() - 1));
    });

    // DVAR(database, field, criteria)
    registerFunction("DVAR", [matchCriteria](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto dbVal = EVAL_ARG(eval, args, 0);
        auto fVal = EVAL_ARG(eval, args, 1);
        auto cVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(dbVal)) return dbVal;
        if (Evaluator::isError(fVal)) return fVal;
        if (Evaluator::isError(cVal)) return cVal;

        if (!std::holds_alternative<ArrayVal>(dbVal)) return CellError{"#VALUE!"};
        if (!std::holds_alternative<ArrayVal>(cVal)) return CellError{"#VALUE!"};
        const auto& mat = std::get<ArrayVal>(dbVal).matrix;
        const auto& critMat = std::get<ArrayVal>(cVal).matrix;
        if (mat.size() < 2) return CellError{"#DIV/0!"};

        int fieldIdx = -1;
        if (std::holds_alternative<double>(fVal)) {
            fieldIdx = (int)std::get<double>(fVal) - 1;
        } else if (std::holds_alternative<std::string>(fVal)) {
            std::string headerName = std::get<std::string>(fVal);
            for (size_t c = 0; c < mat[0].size(); c++) {
                if (Evaluator::asString(mat[0][c]) == headerName) {
                    fieldIdx = (int)c;
                    break;
                }
            }
        }
        if (fieldIdx < 0 || fieldIdx >= (int)mat[0].size()) return CellError{"#VALUE!"};

        std::vector<double> vals;
        for (size_t r = 1; r < mat.size(); r++) {
            if (fieldIdx < (int)mat[r].size() && matchCriteria(mat, critMat, r)) {
                if (std::holds_alternative<double>(mat[r][fieldIdx])) {
                    vals.push_back(std::get<double>(mat[r][fieldIdx]));
                }
            }
        }
        if (vals.size() <= 1) return CellError{"#DIV/0!"};
        double sum = 0.0;
        for (double v : vals) sum += v;
        double mean = sum / vals.size();
        double sqSum = 0.0;
        for (double v : vals) sqSum += (v - mean) * (v - mean);
        return sqSum / (vals.size() - 1);
    });
}
