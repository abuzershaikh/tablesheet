#include "../function_registry.h"
#include <string>
#include <cctype>





// Helper for parsing Cell References like A1 or B12
static bool parseCellCoord(const std::string& ref, int& row, int& col) {
    if (ref.empty()) return false;
    
    col = 0;
    int i = 0;
    while (i < ref.length() && std::isalpha(ref[i])) {
        col = col * 26 + (std::toupper(ref[i]) - 'A' + 1);
        i++;
    }
    col--; // 0-indexed

    if (i == ref.length()) return false;

    row = 0;
    while (i < ref.length() && std::isdigit(ref[i])) {
        row = row * 10 + (ref[i] - '0');
        i++;
    }
    row--; // 0-indexed
    return true;
}

void FunctionRegistry::registerReferenceFunctions() {
    
    // ROW([reference])
    registerFunction("ROW", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) {
            return (double)(eval.currentRow + 1); // Excel is 1-indexed
        }
        if (args.size() > 1) return CellError{"#N/A"};
        
        // Try to evaluate arg. If it's a string representing a cell, return its row.
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string ref = Evaluator::asString(val);
        int r, c;
        if (parseCellCoord(ref, r, c)) {
            return (double)(r + 1);
        }
        return CellError{"#REF!"};
    });

    // COLUMN([reference])
    registerFunction("COLUMN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) {
            return (double)(eval.currentCol + 1);
        }
        if (args.size() > 1) return CellError{"#N/A"};
        
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string ref = Evaluator::asString(val);
        int r, c;
        if (parseCellCoord(ref, r, c)) {
            return (double)(c + 1);
        }
        return CellError{"#REF!"};
    });

    // ROWS(array)
    registerFunction("ROWS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#N/A"};
        
        // If the arg is an ArrayVal, return matrix.size()
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        if (std::holds_alternative<ArrayVal>(val)) {
            return (double)std::get<ArrayVal>(val).matrix.size();
        }
        
        return 1.0; // single value
    });

    // COLUMNS(array)
    registerFunction("COLUMNS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#N/A"};
        
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        if (std::holds_alternative<ArrayVal>(val)) {
            const auto& mat = std::get<ArrayVal>(val).matrix;
            if (mat.empty()) return 0.0;
            return (double)mat[0].size();
        }
        
        return 1.0;
    });

    // OFFSET(reference, rows, cols, [height], [width])
    registerFunction("OFFSET", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 5) return CellError{"#VALUE!"};
        
        auto refVal = EVAL_ARG(eval, args, 0);
        auto rowsVal = EVAL_ARG(eval, args, 1);
        auto colsVal = EVAL_ARG(eval, args, 2);
        
        if (Evaluator::isError(refVal)) return refVal;
        if (Evaluator::isError(rowsVal)) return rowsVal;
        if (Evaluator::isError(colsVal)) return colsVal;
        
        std::string ref = Evaluator::asString(refVal);
        int r, c;
        if (!parseCellCoord(ref, r, c)) return CellError{"#VALUE!"};
        
        int rOffset = (int)Evaluator::asNumber(rowsVal);
        int cOffset = (int)Evaluator::asNumber(colsVal);
        
        int startRow = r + rOffset;
        int startCol = c + cOffset;
        if (startRow < 0 || startCol < 0) return CellError{"#REF!"};
        
        int height = 1;
        int width = 1;
        
        if (args.size() >= 4) {
            auto hVal = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(hVal)) return hVal;
            height = (int)Evaluator::asNumber(hVal);
        }
        if (args.size() == 5) {
            auto wVal = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(wVal)) return wVal;
            width = (int)Evaluator::asNumber(wVal);
        }
        
        if (height <= 0 || width <= 0) return CellError{"#REF!"};
        
        if (height == 1 && width == 1) {
            // Helper to generate col string
            auto colStr = [](int idx) {
                std::string res;
                int i = idx;
                while (i >= 0) {
                    res = (char)((i % 26) + 'A') + res;
                    i = (i / 26) - 1;
                }
                return res;
            };
            std::string targetCell = colStr(startCol) + std::to_string(startRow + 1);
            if (eval.getCell) return eval.getCell(targetCell);
            return 0.0;
        }
        
        // For array return, we would need getRange implementation here
        return CellError{"#VALUE!"}; // currently unsupported height/width array return
    });

    // INDIRECT(ref_text, [a1])
    registerFunction("INDIRECT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#REF!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string ref = Evaluator::asString(val);
        
        size_t colon = ref.find(':');
        if (colon != std::string::npos) {
            std::string topLeft = ref.substr(0, colon);
            std::string botRight = ref.substr(colon + 1);
            if (eval.getRange) return eval.getRange(topLeft, botRight, "");
            return CellError{"#REF!"};
        }
        
        if (eval.getCell) return eval.getCell(ref);
        return CellError{"#REF!"};
    });

    // ADDRESS(row_num, col_num, [abs_num], [a1], [sheet_text])
    registerFunction("ADDRESS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 5) return CellError{"#VALUE!"};
        
        auto r_val = EVAL_ARG(eval, args, 0);
        auto c_val = EVAL_ARG(eval, args, 1);
        
        if (Evaluator::isError(r_val)) return r_val;
        if (Evaluator::isError(c_val)) return c_val;
        
        int row = (int)Evaluator::asNumber(r_val);
        int col = (int)Evaluator::asNumber(c_val);
        
        if (row < 1 || col < 1) return CellError{"#VALUE!"};
        
        int abs_num = 1;
        if (args.size() >= 3) {
            auto abs_val = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(abs_val)) return abs_val;
            abs_num = (int)Evaluator::asNumber(abs_val);
            if (abs_num < 1 || abs_num > 4) return CellError{"#VALUE!"};
        }
        
        bool a1 = true;
        if (args.size() >= 4) {
            auto a1_val = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(a1_val)) return a1_val;
            a1 = Evaluator::asBool(a1_val);
        }
        
        std::string sheet_text = "";
        if (args.size() == 5) {
            auto sheet_val = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(sheet_val)) return sheet_val;
            if (!std::holds_alternative<Blank>(sheet_val)) {
                sheet_text = Evaluator::asString(sheet_val);
            }
        }
        
        std::string col_s = "";
        int temp_c = col;
        while (temp_c > 0) {
            int rem = (temp_c - 1) % 26;
            col_s = (char)('A' + rem) + col_s;
            temp_c = (temp_c - 1) / 26;
        }
        
        std::string row_s = std::to_string(row);
        
        std::string prefix = "";
        if (!sheet_text.empty()) {
            prefix = sheet_text + "!";
        }
        
        std::string result = prefix;
        if (!a1) {
            // R1C1 style
            result += "R" + row_s + "C" + std::to_string(col);
        } else {
            if (abs_num == 1) result += "$" + col_s + "$" + row_s;
            else if (abs_num == 2) result += col_s + "$" + row_s;
            else if (abs_num == 3) result += "$" + col_s + row_s;
            else result += col_s + row_s;
        }
        
        return result;
    });
}
