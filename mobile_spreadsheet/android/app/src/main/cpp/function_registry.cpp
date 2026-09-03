#include "function_registry.h"

FunctionRegistry::FunctionRegistry() {
    registerMathFunctions();
    registerLogicalFunctions();
    registerStatisticalFunctions();
    registerLookupFunctions();
    registerTextFunctions();
    registerDateFunctions();
    registerReferenceFunctions();
    registerArrayFunctions();
    registerFinancialFunctions();
    registerEngineeringFunctions();
    registerInfoFunctions();
    registerRegexFunctions();
    registerDatabaseFunctions();
    registerLambdaFunctions();
}

void FunctionRegistry::registerFunction(const std::string& name, NativeFunction func) {
    std::string upperName = name;
    for (char &c : upperName) c = toupper(c);
    registry[upperName] = std::move(func);
}

bool FunctionRegistry::hasFunction(const std::string& name) const {
    return registry.find(name) != registry.end();
}

#include <algorithm>

EvalResult FunctionRegistry::callFunction(const std::string& name, Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) const {
    auto it = registry.find(name);
    if (it != registry.end()) {
        return it->second(eval, args);
    }
    
    // Fallback: strip dots (e.g. TEXT.JOIN -> TEXTJOIN, COUNT.IF -> COUNTIF)
    std::string stripped = name;
    stripped.erase(std::remove(stripped.begin(), stripped.end(), '.'), stripped.end());
    it = registry.find(stripped);
    if (it != registry.end()) {
        return it->second(eval, args);
    }

    return CellError{"#NAME?"};
}
