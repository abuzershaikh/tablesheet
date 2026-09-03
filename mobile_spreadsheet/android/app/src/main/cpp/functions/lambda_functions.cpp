#include "../function_registry.h"
#include <vector>
#include <string>
#include <optional>
#include <cmath>

void FunctionRegistry::registerLambdaFunctions() {

    // LAMBDA(param1, param2, ..., body)
    registerFunction("LAMBDA", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#N/A"};

        LambdaVal lam;
        for (size_t i = 0; i < args.size() - 1; ++i) {
            auto* cellRef = dynamic_cast<CellReferenceNode*>(args[i].get());
            if (cellRef) {
                lam.parameters.push_back(cellRef->cellName);
            } else {
                return CellError{"#VALUE!"}; 
            }
        }

        lam.body = args.back()->clone();
        lam.closureEnv = eval.localEnvironment;
        
        return lam;
    });

    // MAP(array, lambda)
    registerFunction("MAP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        auto lamVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrVal)) return arrVal;
        if (Evaluator::isError(lamVal)) return lamVal;

        const LambdaVal* lambda = std::get_if<LambdaVal>(&lamVal);
        if (!lambda) return CellError{"#VALUE!"};

        if (!std::holds_alternative<ArrayVal>(arrVal)) {
            return eval.invokeLambda(*lambda, {arrVal});
        }
        const auto& mat = std::get<ArrayVal>(arrVal).matrix;

        ArrayVal res;
        res.matrix.reserve(mat.size()); // Pre-allocate for better performance
        long long totalCells = 0;
        for (const auto& row : mat) {
            totalCells += static_cast<long long>(row.size());
        }
        long long processedCells = 0;
        if (totalCells > 10000) {
            eval.notifyProgress(0, static_cast<int>(totalCells));
        }
        
        for (const auto& row : mat) {
            std::vector<EvalResult> newRow;
            newRow.reserve(row.size()); // Pre-allocate for each row
            
            for (const auto& cell : row) {
                EvalResult cellResult = eval.invokeLambda(*lambda, {cell});
                // Early exit on error
                if (Evaluator::isError(cellResult)) {
                    return cellResult;
                }
                newRow.push_back(std::move(cellResult));
                processedCells++;
                if (totalCells > 10000 && (processedCells % 1000 == 0 || processedCells == totalCells)) {
                    eval.notifyProgress(static_cast<int>(processedCells), static_cast<int>(totalCells));
                }
            }
            res.matrix.push_back(std::move(newRow));
        }
        return res;
    });

    // REDUCE(initial_value, array, lambda)
    registerFunction("REDUCE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto initVal = EVAL_ARG(eval, args, 0);
        auto arrVal = EVAL_ARG(eval, args, 1);
        auto lamVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(initVal)) return initVal;
        if (Evaluator::isError(arrVal)) return arrVal;
        if (Evaluator::isError(lamVal)) return lamVal;

        const LambdaVal* lambda = std::get_if<LambdaVal>(&lamVal);
        if (!lambda) return CellError{"#VALUE!"};

        EvalResult accum = initVal;
        long long totalCells = 0;
        if (std::holds_alternative<ArrayVal>(arrVal)) {
            for (const auto& row : std::get<ArrayVal>(arrVal).matrix) {
                totalCells += static_cast<long long>(row.size());
            }
            long long processedCells = 0;
            if (totalCells > 10000) {
                eval.notifyProgress(0, static_cast<int>(totalCells));
            }
            for (const auto& row : std::get<ArrayVal>(arrVal).matrix) {
                for (const auto& cell : row) {
                    accum = eval.invokeLambda(*lambda, {accum, cell});
                    if (Evaluator::isError(accum)) return accum;
                    processedCells++;
                    if (totalCells > 10000 && (processedCells % 1000 == 0 || processedCells == totalCells)) {
                        eval.notifyProgress(static_cast<int>(processedCells), static_cast<int>(totalCells));
                    }
                }
            }
        } else {
            accum = eval.invokeLambda(*lambda, {accum, arrVal});
        }
        return accum;
    });

    // SCAN(initial_value, array, lambda)
    registerFunction("SCAN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto initVal = EVAL_ARG(eval, args, 0);
        auto arrVal = EVAL_ARG(eval, args, 1);
        auto lamVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(initVal)) return initVal;
        if (Evaluator::isError(arrVal)) return arrVal;
        if (Evaluator::isError(lamVal)) return lamVal;

        const LambdaVal* lambda = std::get_if<LambdaVal>(&lamVal);
        if (!lambda) return CellError{"#VALUE!"};

        if (!std::holds_alternative<ArrayVal>(arrVal)) {
            return eval.invokeLambda(*lambda, {initVal, arrVal});
        }
        const auto& mat = std::get<ArrayVal>(arrVal).matrix;

        ArrayVal res;
        res.matrix.reserve(mat.size()); // ADD THIS
        EvalResult accum = initVal;
        long long totalCells = 0;
        for (const auto& row : mat) {
            totalCells += static_cast<long long>(row.size());
        }
        long long processedCells = 0;
        if (totalCells > 10000) {
            eval.notifyProgress(0, static_cast<int>(totalCells));
        }
        for (const auto& row : mat) {
            std::vector<EvalResult> newRow;
            newRow.reserve(row.size()); // ADD THIS
            for (const auto& cell : row) {
                accum = eval.invokeLambda(*lambda, {accum, cell});
                newRow.push_back(accum);
                processedCells++;
                if (totalCells > 10000 && (processedCells % 1000 == 0 || processedCells == totalCells)) {
                    eval.notifyProgress(static_cast<int>(processedCells), static_cast<int>(totalCells));
                }
            }
            res.matrix.push_back(std::move(newRow)); // CHANGE: use std::move
        }
        return res;
    });

    // MAKEARRAY(rows, cols, lambda)
    registerFunction("MAKEARRAY", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto rowsRes = EVAL_ARG(eval, args, 0);
        auto colsRes = EVAL_ARG(eval, args, 1);
        auto lamVal = EVAL_ARG(eval, args, 2);
        
        if (Evaluator::isError(rowsRes)) return rowsRes;
        if (Evaluator::isError(colsRes)) return colsRes;
        if (Evaluator::isError(lamVal)) return lamVal;

        const LambdaVal* lambda = std::get_if<LambdaVal>(&lamVal);
        if (!lambda) return CellError{"#VALUE!"};

        double rows = Evaluator::asNumber(rowsRes);
        double cols = Evaluator::asNumber(colsRes);
        if (std::isnan(rows) || std::isnan(cols) || rows <= 0 || cols <= 0) return CellError{"#VALUE!"};
        
        // Excel supports up to 1,048,576 rows × 16,384 columns
        // Setting limit to 1M cells (previous limit was 100K causing user formula to fail)
        if (rows * cols > 1048576) return CellError{"#NUM!"}; // PREVENT OOM

        int r = static_cast<int>(rows);
        int c = static_cast<int>(cols);
        int totalCells = r * c;

        ArrayVal res;
        res.matrix.reserve(r); // Pre-allocate memory for rows
        
        // Notify progress start for large arrays
        if (totalCells > 10000) {
            eval.notifyProgress(0, totalCells);
        }
        
        int processedCells = 0;
        for (int i = 1; i <= r; ++i) {
            std::vector<EvalResult> newRow;
            newRow.reserve(c); // Pre-allocate memory for columns
            
            for (int j = 1; j <= c; ++j) {
                EvalResult cellResult = eval.invokeLambda(*lambda, {double(i), double(j)});
                // Early exit on error to avoid unnecessary computation
                if (Evaluator::isError(cellResult)) {
                    return cellResult;
                }
                newRow.push_back(std::move(cellResult));
                
                // Update progress every 1000 cells for large arrays
                processedCells++;
                if (totalCells > 10000 && processedCells % 1000 == 0) {
                    eval.notifyProgress(processedCells, totalCells);
                }
            }
            res.matrix.push_back(std::move(newRow)); // Move instead of copy
        }
        
        // Final progress notification
        if (totalCells > 10000) {
            eval.notifyProgress(totalCells, totalCells);
        }
        
        return res;
    });

    // BYROW(array, lambda)
    registerFunction("BYROW", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        auto lamVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrVal)) return arrVal;
        if (Evaluator::isError(lamVal)) return lamVal;

        const LambdaVal* lambda = std::get_if<LambdaVal>(&lamVal);
        if (!lambda) return CellError{"#VALUE!"};

        if (!std::holds_alternative<ArrayVal>(arrVal)) {
            return eval.invokeLambda(*lambda, {arrVal});
        }
        const auto& mat = std::get<ArrayVal>(arrVal).matrix;
        if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};

        ArrayVal res;
        res.matrix.reserve(mat.size()); // Pre-allocate for result rows
        long long totalRows = static_cast<long long>(mat.size());
        if (totalRows > 1000) {
            eval.notifyProgress(0, static_cast<int>(totalRows));
        }
        long long processedRows = 0;
        
        for (const auto& row : mat) {
            ArrayVal rowArr;
            rowArr.matrix.push_back(row); // This is one copy - acceptable
            
            EvalResult rowResult = eval.invokeLambda(*lambda, {std::move(rowArr)});
            // Early exit on error
            if (Evaluator::isError(rowResult)) {
                return rowResult;
            }
            
            std::vector<EvalResult> newRow;
            newRow.push_back(std::move(rowResult));
            res.matrix.push_back(std::move(newRow));
            processedRows++;
            if (totalRows > 1000 && (processedRows % 50 == 0 || processedRows == totalRows)) {
                eval.notifyProgress(static_cast<int>(processedRows), static_cast<int>(totalRows));
            }
        }
        return res;
    });

    // BYCOL(array, lambda)
    registerFunction("BYCOL", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        auto lamVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(arrVal)) return arrVal;
        if (Evaluator::isError(lamVal)) return lamVal;

        const LambdaVal* lambda = std::get_if<LambdaVal>(&lamVal);
        if (!lambda) return CellError{"#VALUE!"};

        if (!std::holds_alternative<ArrayVal>(arrVal)) {
            return eval.invokeLambda(*lambda, {arrVal});
        }
        const auto& mat = std::get<ArrayVal>(arrVal).matrix;
        if (mat.empty() || mat[0].empty()) return CellError{"#VALUE!"};

        size_t cols = mat[0].size();
        ArrayVal res;
        std::vector<EvalResult> resRow;
        resRow.reserve(cols);
        long long totalCols = static_cast<long long>(cols);
        if (totalCols > 1000) {
            eval.notifyProgress(0, static_cast<int>(totalCols));
        }
        
        long long processedCols = 0;
        for (size_t c = 0; c < cols; ++c) {
            ArrayVal colArr;
            colArr.matrix.reserve(mat.size());
            for (size_t r = 0; r < mat.size(); ++r) {
                std::vector<EvalResult> singleCellRow;
                singleCellRow.reserve(1);
                if (c < mat[r].size()) {
                    singleCellRow.push_back(mat[r][c]);
                } else {
                    singleCellRow.push_back(Blank{});
                }
                colArr.matrix.push_back(std::move(singleCellRow));
            }
            resRow.push_back(eval.invokeLambda(*lambda, {std::move(colArr)}));
            processedCols++;
            if (totalCols > 1000 && (processedCols % 50 == 0 || processedCols == totalCols)) {
                eval.notifyProgress(static_cast<int>(processedCols), static_cast<int>(totalCols));
            }
        }
        res.matrix.push_back(std::move(resRow));
        return res;
    });

}
