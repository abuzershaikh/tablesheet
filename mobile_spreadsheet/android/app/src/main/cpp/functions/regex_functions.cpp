#include "../function_registry.h"
#include <regex>
#include <string>

void FunctionRegistry::registerRegexFunctions() {

    // REGEXMATCH(text, regular_expression)
    registerFunction("REGEXMATCH", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto textVal = EVAL_ARG(eval, args, 0);
        auto regexVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(textVal)) return textVal;
        if (Evaluator::isError(regexVal)) return regexVal;

        std::string text = Evaluator::asString(textVal);
        std::string pat = Evaluator::asString(regexVal);
        if (pat.length() > 500 || text.length() > 50000) return CellError{"#VALUE!"};
        try {
            std::regex re(pat, std::regex_constants::ECMAScript | std::regex_constants::optimize);
            return std::regex_search(text, re);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
    });

    // REGEXEXTRACT(text, regular_expression)
    registerFunction("REGEXEXTRACT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto textVal = EVAL_ARG(eval, args, 0);
        auto regexVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(textVal)) return textVal;
        if (Evaluator::isError(regexVal)) return regexVal;

        std::string text = Evaluator::asString(textVal);
        std::string pat = Evaluator::asString(regexVal);
        if (pat.length() > 500 || text.length() > 50000) return CellError{"#VALUE!"};
        try {
            std::regex re(pat, std::regex_constants::ECMAScript | std::regex_constants::optimize);
            std::smatch match;
            if (std::regex_search(text, match, re)) {
                if (match.size() > 2) {
                    ArrayVal res;
                    std::vector<EvalResult> row;
                    for (size_t i = 1; i < match.size(); ++i) {
                        if (match[i].matched) {
                            row.push_back(match[i].str());
                        } else {
                            row.push_back(Blank{});
                        }
                    }
                    res.matrix.push_back(row);
                    return res;
                } else if (match.size() == 2) {
                    if (match[1].matched) return match[1].str();
                    return Blank{};
                }
                return match[0].str();
            }
            return CellError{"#N/A"};
        } catch (...) {
            return CellError{"#VALUE!"};
        }
    });

    // REGEXREPLACE(text, regular_expression, replacement)
    registerFunction("REGEXREPLACE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto textVal = EVAL_ARG(eval, args, 0);
        auto regexVal = EVAL_ARG(eval, args, 1);
        auto repVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(textVal)) return textVal;
        if (Evaluator::isError(regexVal)) return regexVal;
        if (Evaluator::isError(repVal)) return repVal;

        std::string text = Evaluator::asString(textVal);
        std::string pat = Evaluator::asString(regexVal);
        std::string rep = Evaluator::asString(repVal);
        if (pat.length() > 500 || text.length() > 50000) return CellError{"#VALUE!"};
        try {
            std::regex re(pat, std::regex_constants::ECMAScript | std::regex_constants::optimize);
            return std::regex_replace(text, re, rep);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
    });
}
