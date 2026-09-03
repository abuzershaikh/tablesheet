#ifndef SPREADSHEET_GRID_MANAGER_H
#define SPREADSHEET_GRID_MANAGER_H

#include <string>
#include <unordered_map>
#include <vector>
#include <mutex>
#include <functional>
#include <map>
#include "evaluator.h"
#include "ast.h"

class GridManager {
public:
    enum class CellState {
        UNVISITED,
        VISITING,
        EVALUATED
    };

    struct CellNode {
        std::string formula;
        EvalResult result;
        CellState state = CellState::UNVISITED;
        bool isConstant = false;
        double constantNum = 0.0;
        std::string constantStr = "";
    };

    void setCellFormula(const std::string& cellRef, const std::string& formula);
    void setCellConstant(const std::string& cellRef, double value);
    void setCellConstantString(const std::string& cellRef, const std::string& value);
    void clearGrid();
    std::string pasteDataBlock(int startRow, int startCol, const std::string& csvText);
    std::string copyDataBlock(int startRow, int startCol, int endRow, int endCol);
    void setProgressCallback(std::function<void(int, int)> callback);
    std::string shiftFormula(const std::string& formula, int rOffset, int cOffset);

    // Re-evaluates all cells and returns a JSON string mapping cellRef -> value
    std::string calculateAll();

    // Returns a JSON string mapping cellRef -> raw text (formula or constant)
    std::string getRawGrid();

    // Callback used by the Evaluator when it hits a cell reference
    EvalResult evaluateCell(const std::string& cellRef);

    // PowerScript helper methods
    int getLastRow();      // returns 1-indexed last row with data (0 if empty)
    int getLastColumn();   // returns 1-indexed last column with data (0 if empty)
    void clearCell(const std::string& cellRef);
    std::string getCellFormula(const std::string& cellRef);
    bool isCellEmpty(const std::string& cellRef);
    
    // Layout and Structuring
    void mergeCells(const std::string& rangeStr);
    void breakApartCells(const std::string& rangeStr);
    void setColumnWidth(int col, int width);
    void setRowHeight(int row, int height);

    // Advanced Data Tools
    void removeDuplicates(const std::string& rangeStr);
    void findAndReplace(const std::string& rangeStr, const std::string& pattern, const std::string& replacement, bool isRegex);
    void setDataValidation(const std::string& rangeStr, const std::vector<std::string>& listValues);
    void flashFill(const std::string& sourceRangeStr, const std::string& targetRangeStr);

    std::map<std::string, std::vector<std::string>> dataValidations;
    std::vector<std::string> mergedRanges;
    std::map<int, int> columnWidths;
    std::map<int, int> rowHeights;

    std::recursive_mutex gridMutex;

    // Global instance
    static GridManager& getInstance() {
        static GridManager instance;
        return instance;
    }

private:
    std::unordered_map<std::string, CellNode> grid;
    std::unordered_map<std::string, EvalResult> spillGrid;
    bool inIterativeCycle = false;
    std::vector<std::string> cyclePath;
    std::function<void(int, int)> progressCallback;
    
    EvalResult dfsEvaluate(const std::string& cellRef, int iterationDepth = 0);
    std::string formatEvalResult(const EvalResult& result, const std::string& cellRef);

    int copySourceRow = -1;
    int copySourceCol = -1;
    std::string copySourceText = "";
};

#endif // SPREADSHEET_GRID_MANAGER_H
