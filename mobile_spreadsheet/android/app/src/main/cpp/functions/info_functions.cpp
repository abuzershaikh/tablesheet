#include "../function_registry.h"
#include <string>

void FunctionRegistry::registerInfoFunctions() {

    auto mapIsFunction = [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args, bool (*func)(const EvalResult&)) -> EvalResult {
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
            return func(v);
        };
        return process(val);
    };

    // ISBLANK(value)
    registerFunction("ISBLANK", [mapIsFunction](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return mapIsFunction(eval, args, [](const EvalResult& v) { return std::holds_alternative<Blank>(v); });
    });

    // ISNUMBER(value)
    registerFunction("ISNUMBER", [mapIsFunction](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return mapIsFunction(eval, args, [](const EvalResult& v) { return std::holds_alternative<double>(v); });
    });

    // ISTEXT(value)
    registerFunction("ISTEXT", [mapIsFunction](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return mapIsFunction(eval, args, [](const EvalResult& v) { return std::holds_alternative<std::string>(v); });
    });

    // ISLOGICAL(value)
    registerFunction("ISLOGICAL", [mapIsFunction](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return mapIsFunction(eval, args, [](const EvalResult& v) { return std::holds_alternative<bool>(v); });
    });

    // ISERROR(value)
    registerFunction("ISERROR", [mapIsFunction](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return mapIsFunction(eval, args, [](const EvalResult& v) { return Evaluator::isError(v); });
    });

    // ISERR(value) - Is error except #N/A
    registerFunction("ISERR", [mapIsFunction](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return mapIsFunction(eval, args, [](const EvalResult& v) {
            if (!Evaluator::isError(v)) return false;
            if (std::holds_alternative<CellError>(v)) return std::get<CellError>(v).type != "#N/A";
            return true;
        });
    });

    // ISNA(value)
    registerFunction("ISNA", [mapIsFunction](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return mapIsFunction(eval, args, [](const EvalResult& v) {
            if (std::holds_alternative<CellError>(v)) return std::get<CellError>(v).type == "#N/A";
            return false;
        });
    });

    // TYPE(value) -> 1: Number, 2: Text, 4: Logical, 16: Error, 64: Array
    registerFunction("TYPE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (std::holds_alternative<double>(val)) return 1.0;
        if (std::holds_alternative<std::string>(val)) return 2.0;
        if (std::holds_alternative<bool>(val)) return 4.0;
        if (Evaluator::isError(val)) return 16.0;
        if (std::holds_alternative<ArrayVal>(val)) return 64.0;
        return 1.0;
    });

    // N(value)
    registerFunction("N", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        if (std::holds_alternative<double>(val)) return std::get<double>(val);
        if (std::holds_alternative<bool>(val)) return std::get<bool>(val) ? 1.0 : 0.0;
        return 0.0;
    });

    // NA()
    registerFunction("NA", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (!args.empty()) return CellError{"#VALUE!"};
        return CellError{"#N/A"};
    });

    // ISREF(value)
    registerFunction("ISREF", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return CellError{"#NYI"};
    });

    // ISFORMULA(value)
    registerFunction("ISFORMULA", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return CellError{"#NYI"};
    });

    // ERROR.TYPE(error_val)
    registerFunction("ERROR.TYPE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (!Evaluator::isError(val)) return CellError{"#N/A"};
        if (std::holds_alternative<CellError>(val)) {
            std::string err = std::get<CellError>(val).type;
            if (err == "#NULL!") return 1.0;
            if (err == "#DIV/0!") return 2.0;
            if (err == "#VALUE!") return 3.0;
            if (err == "#REF!") return 4.0;
            if (err == "#NAME?") return 5.0;
            if (err == "#NUM!") return 6.0;
            if (err == "#N/A") return 7.0;
        }
        return CellError{"#N/A"};
    });

    // INFO(type_text)
    registerFunction("INFO", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        return CellError{"#NYI"};
    });
}
