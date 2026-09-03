#include "evaluator.h"
#include "function_registry.h"

EvalResult Evaluator::evaluate(ASTNode* node) {
    if (!node) return CellError{"#VALUE!"};
    node->accept(*this);
    return currentResult;
}

EvalResult Evaluator::invokeLambda(const LambdaVal& lambda, const std::vector<EvalResult>& args) {
    if (args.size() != lambda.parameters.size()) {
        return CellError{"#VALUE!"};
    }
    
    struct BoundVar { std::string name; bool existed; std::shared_ptr<EvalResult> oldVal; };
    std::vector<BoundVar> pushedNames;
    pushedNames.reserve(lambda.closureEnv.size() + lambda.parameters.size());
    
    // Merge closure environment
    for (const auto& kv : lambda.closureEnv) {
        bool existed = localEnvironment.count(kv.first) > 0;
        std::shared_ptr<EvalResult> oldVal = existed ? localEnvironment[kv.first] : nullptr;
        pushedNames.push_back({kv.first, existed, oldVal});
        localEnvironment[kv.first] = kv.second;
    }
    // Bind arguments to parameters
    for (size_t i = 0; i < lambda.parameters.size(); ++i) {
        bool existed = localEnvironment.count(lambda.parameters[i]) > 0;
        std::shared_ptr<EvalResult> oldVal = existed ? localEnvironment[lambda.parameters[i]] : nullptr;
        pushedNames.push_back({lambda.parameters[i], existed, oldVal});
        localEnvironment[lambda.parameters[i]] = std::make_shared<EvalResult>(args[i]);
    }
    
    EvalResult result = evaluate(lambda.body.get());
    
    // Restore environment
    for (auto it = pushedNames.rbegin(); it != pushedNames.rend(); ++it) {
        if (it->existed) {
            localEnvironment[it->name] = std::move(it->oldVal);
        } else {
            // Optimization: Keep the map node to avoid allocation overhead, just clear the value
            localEnvironment.erase(it->name);
        }
    }
    
    return result;
}

void Evaluator::visit(NumberNode& node) { currentResult = node.value; }
void Evaluator::visit(StringNode& node) { currentResult = node.value; }
void Evaluator::visit(BooleanNode& node) { currentResult = node.value; }
void Evaluator::visit(ErrorNode& node) { currentResult = CellError{node.error}; }
void Evaluator::visit(BlankNode& node) { currentResult = Blank{}; }

void Evaluator::visit(CellReferenceNode& node) {
    // Check local environment first (for LET and LAMBDA bindings)
    auto it = localEnvironment.find(node.cellName);
    if (it != localEnvironment.end() && it->second != nullptr) {
        currentResult = *(it->second);
        return;
    }
    
    // Check global environment for Named Ranges
    if (globalEnvironment) {
        auto git = globalEnvironment->find(node.cellName);
        if (git != globalEnvironment->end()) {
            currentResult = git->second;
            return;
        }
    }
    
    std::string ref = node.sheetName.empty() ? node.cellName : node.sheetName + "!" + node.cellName;
    if (getCell) currentResult = getCell(ref);
    else currentResult = CellError{"#REF!"};
}

void Evaluator::visit(RangeReferenceNode& node) {
    if (getRange) currentResult = getRange(node.topLeft, node.bottomRight, node.sheetName);
    else currentResult = CellError{"#REF!"};
}

void Evaluator::visit(ArrayNode& node) {
    ArrayVal arr;
    for (const auto& row : node.rows) {
        std::vector<EvalResult> rowVals;
        for (const auto& expr : row) {
            rowVals.push_back(evaluate(expr.get()));
        }
        arr.matrix.push_back(rowVals);
    }
    currentResult = arr;
}

bool Evaluator::parseCellCoordinates(std::string ref, int& row, int& col, bool* isWholeRow, bool* isWholeCol) {
    if (isWholeRow) *isWholeRow = false;
    if (isWholeCol) *isWholeCol = false;
    ref.erase(std::remove(ref.begin(), ref.end(), '$'), ref.end());
    if (ref.empty()) return false;
    col = 0;
    row = 0;
    size_t i = 0;
    int letterCount = 0;
    while (i < ref.length() && std::isalpha(ref[i])) {
        col = col * 26 + (std::toupper(ref[i]) - 'A' + 1);
        i++;
        letterCount++;
    }
    if (letterCount > 3) return false;
    col--;
    if (col < 0 || col >= 16384) return false;
    if (i < ref.length()) {
        try {
            long long rVal = std::stoll(ref.substr(i)) - 1;
            if (rVal < 0 || rVal >= 1048576) return false;
            row = (int)rVal;
            return true;
        } catch (...) {
            return false;
        }
    } else if (i > 0) {
        // Whole column reference like "A"
        row = 0;
        if (isWholeCol) *isWholeCol = true;
        return true;
    } else {
        // Whole row reference like "1"
        try {
            row = std::stoi(ref) - 1;
            if (row < 0 || row >= 1048576) return false;
            col = 0;
            if (isWholeRow) *isWholeRow = true;
            return true;
        } catch(...) {
            return false;
        }
    }
    return false;
}

std::string Evaluator::indexToColumn(int col) {
    std::string res = "";
    while (col >= 0) {
        res = (char)('A' + (col % 26)) + res;
        col = col / 26 - 1;
    }
    return res;
}

void Evaluator::visit(UnaryOpNode& node) {
    auto opnd = evaluate(node.operand.get());
    if (isError(opnd)) { currentResult = opnd; return; }
    
    if (node.op == TokenType::MINUS) {
        currentResult = -asNumber(opnd);
    } else if (node.op == TokenType::PLUS) {
        currentResult = asNumber(opnd);
    } else if (node.op == TokenType::PERCENT) {
        currentResult = asNumber(opnd) / 100.0;
    } else if (node.op == TokenType::AT_SIGN) {
        if (std::holds_alternative<ArrayVal>(opnd)) {
            const auto& mat = std::get<ArrayVal>(opnd).matrix;
            if (mat.empty() || mat[0].empty()) {
                currentResult = CellError{"#VALUE!"};
                return;
            }

            int startRow = currentRow;
            int startCol = currentCol;
            
            if (auto* rangeNode = dynamic_cast<RangeReferenceNode*>(node.operand.get())) {
                int r = 0, c = 0;
                if (parseCellCoordinates(rangeNode->topLeft, r, c)) {
                    startRow = r;
                    startCol = c;
                }
            }

            int targetRow = currentRow - startRow;
            int targetCol = currentCol - startCol;
            
            if (mat.size() > 1 && mat[0].size() == 1) { // Column array
                if (targetRow >= 0 && targetRow < (int)mat.size()) {
                    currentResult = mat[targetRow][0];
                } else {
                    currentResult = CellError{"#VALUE!"};
                }
            } else if (mat.size() == 1 && mat[0].size() > 1) { // Row array
                if (targetCol >= 0 && targetCol < (int)mat[0].size()) {
                    currentResult = mat[0][targetCol];
                } else {
                    currentResult = CellError{"#VALUE!"};
                }
            } else if (mat.size() > 1 && mat[0].size() > 1) { // 2D array
                if (targetRow >= 0 && targetRow < (int)mat.size() && targetCol >= 0 && targetCol < (int)mat[0].size()) {
                    currentResult = mat[targetRow][targetCol];
                } else {
                    currentResult = CellError{"#VALUE!"};
                }
            } else { // 1x1 array
                currentResult = mat[0][0];
            }
        } else {
            // If operand is not an array, @ has no effect
            currentResult = opnd;
        }
    } else if (node.op == TokenType::HASH) {
        // # Operator: returns the evaluated operand exactly as is (usually an ArrayVal from a spilled cell)
        currentResult = opnd;
    } else {
        currentResult = CellError{"#VALUE!"};
    }
}

static int getTypeRank(const EvalResult& val) {
    if (std::holds_alternative<Blank>(val)) return 0;
    if (std::holds_alternative<double>(val)) return 1;
    if (std::holds_alternative<std::string>(val)) return 2;
    if (std::holds_alternative<bool>(val)) return 3;
    return 4; // Arrays, Errors, etc.
}

static int compareEvalResult(const EvalResult& left, const EvalResult& right) {
    int rankL = getTypeRank(left);
    int rankR = getTypeRank(right);
    
    // Coerce Blank based on the other operand
    if (rankL == 0 && rankR == 1) { double r = std::get<double>(right); return (0.0 == r) ? 0 : (0.0 < r ? -1 : 1); }
    if (rankL == 1 && rankR == 0) { double l = std::get<double>(left); return (l == 0.0) ? 0 : (l < 0.0 ? -1 : 1); }
    
    if (rankL == 0 && rankR == 2) { std::string r = std::get<std::string>(right); return ("" == r) ? 0 : ("" < r ? -1 : 1); }
    if (rankL == 2 && rankR == 0) { std::string l = std::get<std::string>(left); return (l == "") ? 0 : (l < "" ? -1 : 1); }

    if (rankL == 0 && rankR == 3) { bool r = std::get<bool>(right); return (false == r) ? 0 : -1; }
    if (rankL == 3 && rankR == 0) { bool l = std::get<bool>(left); return (l == false) ? 0 : 1; }
    
    if (rankL == 0 && rankR == 0) return 0;

    if (rankL != rankR) {
        if (rankL == 2 && rankR == 1) {
            try {
                double lNum = std::stod(std::get<std::string>(left));
                double r = std::get<double>(right);
                if (lNum == r) return 0;
                return lNum < r ? -1 : 1;
            } catch (...) {}
        }
        if (rankL == 1 && rankR == 2) {
            try {
                double l = std::get<double>(left);
                double rNum = std::stod(std::get<std::string>(right));
                if (l == rNum) return 0;
                return l < rNum ? -1 : 1;
            } catch (...) {}
        }
        return rankL < rankR ? -1 : 1;
    }

    if (rankL == 1) {
        double l = std::get<double>(left);
        double r = std::get<double>(right);
        if (l == r) return 0;
        return l < r ? -1 : 1;
    } else if (rankL == 2) {
        std::string lUpper = std::get<std::string>(left);
        std::string rUpper = std::get<std::string>(right);
        std::transform(lUpper.begin(), lUpper.end(), lUpper.begin(), [](unsigned char c) { return std::toupper(c); });
        std::transform(rUpper.begin(), rUpper.end(), rUpper.begin(), [](unsigned char c) { return std::toupper(c); });
        if (lUpper == rUpper) return 0;
        return lUpper < rUpper ? -1 : 1;
    } else if (rankL == 3) {
        bool l = std::get<bool>(left);
        bool r = std::get<bool>(right);
        if (l == r) return 0;
        return !l && r ? -1 : 1;
    }
    return 0; 
}

static EvalResult evalScalarBinaryOp(const EvalResult& left, TokenType op, const EvalResult& right) {
    if (Evaluator::isError(left)) return left;
    if (Evaluator::isError(right)) return right;

    if (op == TokenType::CONCAT) {
        return Evaluator::asString(left) + Evaluator::asString(right);
    }
    
    if (op == TokenType::EQUAL || op == TokenType::NOT_EQUAL || 
        op == TokenType::LESS_THAN || op == TokenType::LESS_THAN_OR_EQUAL ||
        op == TokenType::GREATER_THAN || op == TokenType::GREATER_THAN_OR_EQUAL) {
        
        int cmp = compareEvalResult(left, right);
        switch (op) {
            case TokenType::EQUAL: return cmp == 0;
            case TokenType::NOT_EQUAL: return cmp != 0;
            case TokenType::LESS_THAN: return cmp < 0;
            case TokenType::LESS_THAN_OR_EQUAL: return cmp <= 0;
            case TokenType::GREATER_THAN: return cmp > 0;
            case TokenType::GREATER_THAN_OR_EQUAL: return cmp >= 0;
            default: return CellError{"#VALUE!"};
        }
    }

    double lNum = Evaluator::asNumber(left);
    double rNum = Evaluator::asNumber(right);

    switch (op) {
        case TokenType::PLUS: return lNum + rNum;
        case TokenType::MINUS: return lNum - rNum;
        case TokenType::MULTIPLY: return lNum * rNum;
        case TokenType::DIVIDE:
            if (rNum == 0) return CellError{"#DIV/0!"};
            return lNum / rNum;
        case TokenType::POWER: return std::pow(lNum, rNum);
        default: return CellError{"#VALUE!"};
    }
}

void Evaluator::visit(BinaryOpNode& node) {
    bool leftIsFunc = (dynamic_cast<FunctionNode*>(node.left.get()) != nullptr);
    bool rightIsFunc = (dynamic_cast<FunctionNode*>(node.right.get()) != nullptr);

    auto left = evaluate(node.left.get());
    if (isError(left)) { currentResult = left; return; }
    
    auto right = evaluate(node.right.get());
    if (isError(right)) { currentResult = right; return; }

    bool leftIsArray = std::holds_alternative<ArrayVal>(left);
    bool rightIsArray = std::holds_alternative<ArrayVal>(right);

    if (!leftIsArray && !rightIsArray) {
        currentResult = evalScalarBinaryOp(left, node.op, right);
        return;
    }

    if (leftIsArray && !rightIsArray) {
        const auto& mat = std::get<ArrayVal>(left).matrix;
        ArrayVal res;
        for (const auto& row : mat) {
            std::vector<EvalResult> newRow;
            for (const auto& cell : row) {
                EvalResult curRight = rightIsFunc ? evaluate(node.right.get()) : right;
                newRow.push_back(evalScalarBinaryOp(cell, node.op, curRight));
            }
            res.matrix.push_back(newRow);
        }
        currentResult = res;
        return;
    }

    if (!leftIsArray && rightIsArray) {
        const auto& mat = std::get<ArrayVal>(right).matrix;
        ArrayVal res;
        for (const auto& row : mat) {
            std::vector<EvalResult> newRow;
            for (const auto& cell : row) {
                EvalResult curLeft = leftIsFunc ? evaluate(node.left.get()) : left;
                newRow.push_back(evalScalarBinaryOp(curLeft, node.op, cell));
            }
            res.matrix.push_back(newRow);
        }
        currentResult = res;
        return;
    }

    if (leftIsArray && rightIsArray) {
        const auto& matL = std::get<ArrayVal>(left).matrix;
        const auto& matR = std::get<ArrayVal>(right).matrix;
        size_t rows = std::max(matL.size(), matR.size());
        ArrayVal res;
        for (size_t r = 0; r < rows; r++) {
            std::vector<EvalResult> newRow;
            size_t colsL = (r < matL.size()) ? matL[r].size() : 0;
            size_t colsR = (r < matR.size()) ? matR[r].size() : 0;
            size_t cols = std::max(colsL, colsR);
            for (size_t c = 0; c < cols; c++) {
                EvalResult cellL = (r < matL.size() && c < matL[r].size()) ? matL[r][c] : CellError{"#N/A"};
                EvalResult cellR = (r < matR.size() && c < matR[r].size()) ? matR[r][c] : CellError{"#N/A"};
                newRow.push_back(evalScalarBinaryOp(cellL, node.op, cellR));
            }
            res.matrix.push_back(newRow);
        }
        currentResult = res;
        return;
    }
}

void Evaluator::visit(FunctionNode& node) {
    auto it = localEnvironment.find(node.name);
    if (it != localEnvironment.end() && it->second != nullptr && std::holds_alternative<LambdaVal>(*(it->second))) {
        const LambdaVal* lambda = std::get_if<LambdaVal>(&*(it->second));
        
        std::vector<EvalResult> evalArgs;
        for (const auto& arg : node.arguments) {
            evalArgs.push_back(evaluate(arg.get()));
        }
        
        if (evalArgs.size() != lambda->parameters.size()) {
            currentResult = CellError{"#VALUE!"};
            return;
        }

        struct BoundVar { std::string name; bool existed; std::shared_ptr<EvalResult> oldVal; };
        std::vector<BoundVar> pushedNames;
        
        for (const auto& kv : lambda->closureEnv) {
            bool existed = localEnvironment.count(kv.first) > 0;
            std::shared_ptr<EvalResult> oldVal = existed ? localEnvironment[kv.first] : nullptr;
            pushedNames.push_back({kv.first, existed, oldVal});
            localEnvironment[kv.first] = kv.second;
        }
        for (size_t i = 0; i < lambda->parameters.size(); ++i) {
            bool existed = localEnvironment.count(lambda->parameters[i]) > 0;
            std::shared_ptr<EvalResult> oldVal = existed ? localEnvironment[lambda->parameters[i]] : nullptr;
            pushedNames.push_back({lambda->parameters[i], existed, oldVal});
            localEnvironment[lambda->parameters[i]] = std::make_shared<EvalResult>(evalArgs[i]);
        }
        
        currentResult = evaluate(lambda->body.get());
        
        for (auto itPushed = pushedNames.rbegin(); itPushed != pushedNames.rend(); ++itPushed) {
            if (itPushed->existed) {
                localEnvironment[itPushed->name] = itPushed->oldVal;
            } else {
                localEnvironment.erase(itPushed->name);
            }
        }
        return;
    }

    std::string upperName = node.name;
    for(char &c : upperName) c = toupper(c);
    
    auto& registry = FunctionRegistry::getInstance();
    currentResult = registry.callFunction(upperName, *this, node.arguments);
}

// ----------------- HELPERS -----------------
bool Evaluator::isError(const EvalResult& val) {
    return std::holds_alternative<CellError>(val);
}

double Evaluator::asNumber(const EvalResult& val) {
    if (std::holds_alternative<ArrayVal>(val)) {
        const auto& mat = std::get<ArrayVal>(val).matrix;
        if (!mat.empty() && !mat[0].empty()) {
            return asNumber(mat[0][0]);
        }
        return 0.0;
    }
    if (std::holds_alternative<double>(val)) return std::get<double>(val);
    if (std::holds_alternative<bool>(val)) return std::get<bool>(val) ? 1.0 : 0.0;
    if (std::holds_alternative<Blank>(val)) return 0.0;
    if (std::holds_alternative<std::string>(val)) {
        try {
            std::string s = std::get<std::string>(val);
            size_t first = s.find_first_not_of(" \t\r\n");
            if (first != std::string::npos) {
                size_t last = s.find_last_not_of(" \t\r\n");
                s = s.substr(first, last - first + 1);

                // Check if string contains only digits/signs/dot and symbols (no other letters)
                bool isNumericFormatted = false;
                int digitCount = 0;
                int letterCount = 0;
                for (char ch : s) {
                    if (std::isdigit(ch)) digitCount++;
                    else if (std::isalpha(ch)) {
                        char lowerCh = std::tolower(ch);
                        if (lowerCh != 'e') {
                            letterCount++;
                        }
                    }
                }
                if (digitCount > 0 && letterCount == 0) {
                    isNumericFormatted = true;
                }

                if (isNumericFormatted) {
                    std::string clean = "";
                    bool hasDot = false;
                    for (char ch : s) {
                        if (std::isdigit(ch) || ch == '-' || ch == '+' || ch == 'e' || ch == 'E') {
                            clean += ch;
                        } else if (ch == '.' && !hasDot) {
                            clean += ch;
                            hasDot = true;
                        }
                    }
                    if (!clean.empty()) {
                        return std::stod(clean);
                    }
                }
                return std::stod(s);
            }
        } catch(...) { return 0.0; }
    }
    return 0.0;
}

std::string Evaluator::asString(const EvalResult& val) {
    if (std::holds_alternative<ArrayVal>(val)) {
        const auto& mat = std::get<ArrayVal>(val).matrix;
        if (!mat.empty() && !mat[0].empty()) {
            return asString(mat[0][0]);
        }
    }
    if (std::holds_alternative<std::string>(val)) return std::get<std::string>(val);
    if (std::holds_alternative<double>(val)) {
        double d = std::get<double>(val);
        if (d == (int64_t)d && std::abs(d) < 9007199254740992.0) {
            return std::to_string((int64_t)d);
        }
        std::string s = std::to_string(d);
        s.erase(s.find_last_not_of('0') + 1, std::string::npos);
        if (s.back() == '.') s.pop_back();
        return s;
    }
    if (std::holds_alternative<bool>(val)) return std::get<bool>(val) ? "TRUE" : "FALSE";
    if (std::holds_alternative<CellError>(val)) return std::get<CellError>(val).type;
    return "";
}

bool Evaluator::asBool(const EvalResult& val) {
    if (std::holds_alternative<ArrayVal>(val)) {
        const auto& mat = std::get<ArrayVal>(val).matrix;
        if (!mat.empty() && !mat[0].empty()) {
            return asBool(mat[0][0]);
        }
    }
    if (std::holds_alternative<bool>(val)) return std::get<bool>(val);
    if (std::holds_alternative<double>(val)) return std::get<double>(val) != 0;
    if (std::holds_alternative<std::string>(val)) {
        std::string s = std::get<std::string>(val);
        for(char &c : s) c = toupper(c);
        return s == "TRUE";
    }
    return false;
}

void Evaluator::flattenNumbers(const EvalResult& val, std::vector<double>& out) {
    if (std::holds_alternative<ArrayVal>(val)) {
        for (const auto& row : std::get<ArrayVal>(val).matrix) {
            for (const auto& v : row) {
                flattenNumbers(v, out);
            }
        }
    } else if (!isError(val) && !std::holds_alternative<Blank>(val)) {
        out.push_back(asNumber(val));
    }
}

void Evaluator::flattenBooleans(const EvalResult& val, std::vector<bool>& out) {
    if (std::holds_alternative<ArrayVal>(val)) {
        for (const auto& row : std::get<ArrayVal>(val).matrix) {
            for (const auto& v : row) {
                if (isError(v)) throw std::get<CellError>(v);
                if (std::holds_alternative<bool>(v)) {
                    out.push_back(std::get<bool>(v));
                } else if (std::holds_alternative<double>(v)) {
                    out.push_back(std::get<double>(v) != 0);
                }
            }
        }
    } else {
        if (isError(val)) throw std::get<CellError>(val);
        if (!std::holds_alternative<Blank>(val)) {
            if (std::holds_alternative<std::string>(val)) {
                std::string s = std::get<std::string>(val);
                for(char &c : s) c = toupper(c);
                if (s == "TRUE") out.push_back(true);
                else if (s == "FALSE") out.push_back(false);
                else throw CellError{"#VALUE!"};
            } else {
                out.push_back(asBool(val));
            }
        }
    }
}

EvalResult Evaluator::extractNumbers(const EvalResult& val, std::vector<double>& out) {
    if (std::holds_alternative<ArrayVal>(val)) {
        for (const auto& row : std::get<ArrayVal>(val).matrix) {
            for (const auto& v : row) {
                if (isError(v)) return v;
                if (std::holds_alternative<double>(v)) {
                    out.push_back(std::get<double>(v));
                }
            }
        }
    } else {
        if (isError(val)) return val;
        if (!std::holds_alternative<Blank>(val)) {
            if (std::holds_alternative<std::string>(val)) {
                try {
                    out.push_back(std::stod(std::get<std::string>(val)));
                } catch(...) {
                    return CellError{"#VALUE!"};
                }
            } else {
                out.push_back(asNumber(val));
            }
        }
    }
    return Blank{};
}

