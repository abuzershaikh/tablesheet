#ifndef SPREADSHEET_EVALUATOR_H
#define SPREADSHEET_EVALUATOR_H

#include "ast.h"
#include <variant>
#include <string>
#include <vector>
#include <functional>
#include <cmath>
#include <unordered_map>
#include <memory>

struct CellError { std::string type; };
struct Blank {};
struct CallableVal { 
    std::shared_ptr<ASTNode> body; 
    std::vector<std::string> params; 
};

struct LambdaVal;
struct ArrayVal { std::vector<std::vector<std::variant<double, std::string, bool, CellError, Blank, ArrayVal, CallableVal, LambdaVal>>> matrix; };

using EvalResult = std::variant<double, std::string, bool, CellError, Blank, ArrayVal, CallableVal, LambdaVal>;

struct LambdaVal {
    std::vector<std::string> parameters;
    std::shared_ptr<ASTNode> body; 
    std::unordered_map<std::string, std::shared_ptr<EvalResult>> closureEnv;
};

class Evaluator : public ASTVisitor {
public:
    using CellProvider = std::function<EvalResult(const std::string&)>;
    using RangeProvider = std::function<ArrayVal(const std::string&, const std::string&, const std::string&)>;
    using ProgressCallback = std::function<void(int current, int total)>;

    Evaluator(CellProvider cp = nullptr, RangeProvider rp = nullptr, int row = 0, int col = 0) 
        : getCell(std::move(cp)), getRange(std::move(rp)), currentRow(row), currentCol(col) {}

    EvalResult evaluate(ASTNode* node);
    EvalResult invokeLambda(const LambdaVal& lambda, const std::vector<EvalResult>& args);

    // Context for ROW(), COLUMN()
    int currentRow;
    int currentCol;

    // Environment for LET variables
    std::unordered_map<std::string, std::shared_ptr<EvalResult>> localEnvironment;
    
    // Global environment for Named Ranges
    std::unordered_map<std::string, EvalResult>* globalEnvironment = nullptr;
    
    // Progress callback for large operations
    ProgressCallback progressCallback;
    
    void notifyProgress(int current, int total) {
        if (progressCallback) {
            progressCallback(current, total);
        }
    }

    void visit(NumberNode& node) override;
    void visit(StringNode& node) override;
    void visit(BooleanNode& node) override;
    void visit(ErrorNode& node) override;
    void visit(CellReferenceNode& node) override;
    void visit(RangeReferenceNode& node) override;
    void visit(BinaryOpNode& node) override;
    void visit(UnaryOpNode& node) override;
    void visit(FunctionNode& node) override;
    void visit(ArrayNode& node) override;
    void visit(BlankNode& node) override;

    // Helpers exposed for Function Registry
    static double asNumber(const EvalResult& val);
    static std::string asString(const EvalResult& val);
    static bool asBool(const EvalResult& val);
    static bool isError(const EvalResult& val);
    static void flattenNumbers(const EvalResult& val, std::vector<double>& out);
    static void flattenBooleans(const EvalResult& val, std::vector<bool>& out);
    static EvalResult extractNumbers(const EvalResult& val, std::vector<double>& out);

    static bool parseCellCoordinates(std::string ref, int& row, int& col, bool* isWholeRow = nullptr, bool* isWholeCol = nullptr);
    static std::string indexToColumn(int col);

    CellProvider getCell;
    RangeProvider getRange;

private:
    EvalResult currentResult;
};

#endif // SPREADSHEET_EVALUATOR_H
