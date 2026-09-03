#include "../function_registry.h"

// Defined in evaluator.cpp



void FunctionRegistry::registerLogicalFunctions() {
    
    // IF(condition, true_value, [false_value])
    registerFunction("IF", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto cond = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(cond)) return cond;
        
        if (Evaluator::asBool(cond)) {
            return EVAL_ARG(eval, args, 1);
        } else {
            if (args.size() == 3) return EVAL_ARG(eval, args, 2);
            return false;
        }
    });

    // AND(logical1, [logical2], ...)
    registerFunction("AND", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        std::vector<bool> bools;
        try {
            for (const auto& arg : args) {
                auto val = eval.evaluate(arg.get());
                Evaluator::flattenBooleans(val, bools);
            }
        } catch (const CellError& err) {
            return err;
        }
        if (bools.empty()) return CellError{"#VALUE!"};
        for (bool b : bools) {
            if (!b) return false;
        }
        return true;
    });

    // OR(logical1, [logical2], ...)
    registerFunction("OR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        std::vector<bool> bools;
        try {
            for (const auto& arg : args) {
                auto val = eval.evaluate(arg.get());
                Evaluator::flattenBooleans(val, bools);
            }
        } catch (const CellError& err) {
            return err;
        }
        if (bools.empty()) return CellError{"#VALUE!"};
        for (bool b : bools) {
            if (b) return true;
        }
        return false;
    });

    // NOT(logical)
    registerFunction("NOT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::vector<bool> bools;
        try { Evaluator::flattenBooleans(val, bools); }
        catch (const CellError& err) { return err; }
        
        if (bools.empty()) return CellError{"#VALUE!"};
        return !bools[0];
    });

    // XOR(logical1, [logical2], ...)
    registerFunction("XOR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        std::vector<bool> bools;
        try {
            for (const auto& arg : args) {
                auto val = eval.evaluate(arg.get());
                Evaluator::flattenBooleans(val, bools);
            }
        } catch (const CellError& err) {
            return err;
        }
        if (bools.empty()) return CellError{"#VALUE!"};
        int trueCount = 0;
        for (bool b : bools) {
            if (b) trueCount++;
        }
        return (trueCount % 2) != 0;
    });

    // IFERROR(value, value_if_error)
    registerFunction("IFERROR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) {
            return EVAL_ARG(eval, args, 1);
        }
        return val;
    });

    // IFNA(value, value_if_na)
    registerFunction("IFNA", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val) && std::get<CellError>(val).type == "#N/A") {
            return EVAL_ARG(eval, args, 1);
        }
        return val;
    });

    // IFS(logical1, value1, [logical2, value2], ...)
    registerFunction("IFS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() % 2 != 0 || args.empty()) return CellError{"#VALUE!"};
        for (size_t i = 0; i < args.size(); i += 2) {
            auto cond = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(cond)) return cond;
            if (Evaluator::asBool(cond)) {
                return EVAL_ARG(eval, args, i + 1);
            }
        }
        return CellError{"#N/A"};
    });

    // SWITCH(expression, val1, res1, [val2, res2], ..., [default])
    registerFunction("SWITCH", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3) return CellError{"#VALUE!"};
        auto expr = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(expr)) return expr;
        
        std::string exprStr = Evaluator::asString(expr);
        
        size_t i = 1;
        while (i + 1 < args.size()) {
            auto val = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(val)) return val;
            
            if (exprStr == Evaluator::asString(val)) {
                return EVAL_ARG(eval, args, i + 1);
            }
            i += 2;
        }
        
        if (i < args.size()) {
            return EVAL_ARG(eval, args, i);
        }
        
        return CellError{"#N/A"};
    });

    // LET(name1, name_value1, [name2, name_value2], ..., calculation)
    registerFunction("LET", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() % 2 == 0) return CellError{"#VALUE!"};
        
        // Save old env state for cleanup/restoring
        struct BoundVar { std::string name; bool existed; std::shared_ptr<EvalResult> oldVal; };
        std::vector<BoundVar> pushedNames;
        
        for (size_t i = 0; i < args.size() - 1; i += 2) {
            std::string name;
            if (auto nameNode = dynamic_cast<CellReferenceNode*>(args[i].get())) {
                name = nameNode->cellName;
            } else if (auto strNode = dynamic_cast<StringNode*>(args[i].get())) {
                name = strNode->value;
            } else {
                // If invalid name, rollback and error
                for (auto it = pushedNames.rbegin(); it != pushedNames.rend(); ++it) {
                    if (it->existed) eval.localEnvironment[it->name] = it->oldVal;
                    else eval.localEnvironment.erase(it->name);
                }
                return CellError{"#VALUE!"};
            }
            
            EvalResult val = EVAL_ARG(eval, args, i + 1);
            if (Evaluator::isError(val)) {
                for (auto it = pushedNames.rbegin(); it != pushedNames.rend(); ++it) {
                    if (it->existed) eval.localEnvironment[it->name] = it->oldVal;
                    else eval.localEnvironment.erase(it->name);
                }
                return val;
            }
            
            bool existed = false;
            std::shared_ptr<EvalResult> oldVal = nullptr;
            auto envIt = eval.localEnvironment.find(name);
            if (envIt != eval.localEnvironment.end()) {
                existed = true;
                oldVal = envIt->second;
            }
            pushedNames.push_back({name, existed, oldVal});
            
            eval.localEnvironment[name] = std::make_shared<EvalResult>(val);
        }
        
        EvalResult finalResult = EVAL_ARG(eval, args, args.size() - 1);
        
        for (auto it = pushedNames.rbegin(); it != pushedNames.rend(); ++it) {
            if (it->existed) eval.localEnvironment[it->name] = it->oldVal;
            else eval.localEnvironment.erase(it->name);
        }
        
        return finalResult;
    });

    // TRUE()
    registerFunction("TRUE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (!args.empty()) return CellError{"#VALUE!"};
        return true;
    });

    // FALSE()
    registerFunction("FALSE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (!args.empty()) return CellError{"#VALUE!"};
        return false;
    });
}
