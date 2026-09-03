#ifndef SPREADSHEET_FUNCTION_REGISTRY_H
#define SPREADSHEET_FUNCTION_REGISTRY_H

#include "evaluator.h"
#include <string>
#include <unordered_map>
#include <functional>

// Signature for a native C++ spreadsheet function
// It takes a reference to the Evaluator (so it can evaluate arguments lazily if needed)
// and a vector of ASTNode pointers.
using NativeFunction = std::function<EvalResult(Evaluator&, const std::vector<std::unique_ptr<ASTNode>>&)>;

class FunctionRegistry {
public:
    static FunctionRegistry& getInstance() {
        static FunctionRegistry instance;
        return instance;
    }

    void registerFunction(const std::string& name, NativeFunction func);
    bool hasFunction(const std::string& name) const;
    EvalResult callFunction(const std::string& name, Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) const;

private:
    FunctionRegistry();
    std::unordered_map<std::string, NativeFunction> registry;

    void registerMathFunctions();
    void registerLogicalFunctions();
    void registerStatisticalFunctions();
    void registerTextFunctions();
    void registerDateFunctions();
    void registerLookupFunctions();
    void registerReferenceFunctions();
    void registerArrayFunctions();
    void registerFinancialFunctions();
    void registerEngineeringFunctions();
    void registerInfoFunctions();
    void registerRegexFunctions();
    void registerDatabaseFunctions();
    void registerLambdaFunctions();
};

// Helper macro to easily evaluate arguments inside native functions
#define EVAL_ARG(eval, args, index) (eval).evaluate((args)[index].get())

#endif // SPREADSHEET_FUNCTION_REGISTRY_H
