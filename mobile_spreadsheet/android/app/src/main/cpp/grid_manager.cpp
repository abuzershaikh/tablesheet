#include "grid_manager.h"
#include "parser.h"
#include "evaluator.h"
#include <cmath>
#include <cctype>
#include <iostream>
#include <regex>
#include <unordered_set>
#include <sstream>

extern std::unordered_map<std::string, EvalResult> g_namedRanges;

void GridManager::setCellFormula(const std::string& cellRef, const std::string& formula) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    std::string cleanFormula = formula;
    while (!cleanFormula.empty() && cleanFormula[0] == '=') {
        cleanFormula.erase(0, 1);
    }
    grid[cellRef] = CellNode{cleanFormula, Blank{}, CellState::UNVISITED, false, 0.0, ""};
}

void GridManager::setCellConstant(const std::string& cellRef, double value) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    grid[cellRef] = CellNode{"", value, CellState::EVALUATED, true, value, ""};
}

void GridManager::setCellConstantString(const std::string& cellRef, const std::string& value) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    std::string trimmed = value;
    while (!trimmed.empty() && std::isspace((unsigned char)trimmed.front())) trimmed.erase(0, 1);
    while (!trimmed.empty() && std::isspace((unsigned char)trimmed.back())) trimmed.pop_back();

    if (trimmed.empty()) {
        grid.erase(cellRef);
        return;
    }

    if (!trimmed.empty() && trimmed[0] == '=') {
        setCellFormula(cellRef, trimmed);
        return;
    }
    grid[cellRef] = CellNode{"", value, CellState::EVALUATED, true, 0.0, value};
}

void GridManager::clearGrid() {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    grid.clear();
    spillGrid.clear();
}

void GridManager::setProgressCallback(std::function<void(int, int)> callback) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    progressCallback = std::move(callback);
}

static std::string coordToCellRef(int r, int c) {
    std::string res = "";
    int i = c;
    while (i >= 0) {
        res = (char)((i % 26) + 'A') + res;
        i = (i / 26) - 1;
    }
    res += std::to_string(r + 1);
    return res;
}

std::string escapeJson(const std::string& str) {
    std::string result;
    for (char c : str) {
        if (c == '"') result += "\\\"";
        else if (c == '\\') result += "\\\\";
        else if (c == '\n') result += "\\n";
        else if (c == '\r') result += "\\r";
        else if (c == '\t') result += "\\t";
        else result += c;
    }
    return result;
}

std::string GridManager::shiftFormula(const std::string& formula, int rOffset, int cOffset) {
    if (formula.empty() || formula[0] != '=') return formula;
    
    Tokenizer tokenizer(formula);
    auto tokens = tokenizer.tokenize();
    
    std::string result = "=";
    for (size_t i = 0; i < tokens.size(); i++) {
        const auto& t = tokens[i];
        if (t.type == TokenType::END_OF_FILE) break;
        if (t.type == TokenType::IDENTIFIER) {
            // Skip shifting if this identifier is a function name (followed by '(')
            if (i + 1 < tokens.size() && tokens[i+1].type == TokenType::LPAREN) {
                result += t.lexeme;
                continue;
            }
            int r = 0, c = 0;
            bool isWholeRow = false, isWholeCol = false;
            if (Evaluator::parseCellCoordinates(t.lexeme, r, c, &isWholeRow, &isWholeCol)) {
                bool colAbs = false;
                bool rowAbs = false;
                
                size_t firstDollar = t.lexeme.find('$');
                if (firstDollar != std::string::npos) {
                    if (firstDollar == 0) colAbs = true;
                    size_t secondDollar = t.lexeme.find('$', firstDollar + 1);
                    if (secondDollar != std::string::npos) {
                        rowAbs = true;
                    } else if (firstDollar > 0) {
                        rowAbs = true;
                    }
                }
                
                std::string newRef = "";
                if (isWholeCol) {
                    int newC = colAbs ? c : c + cOffset;
                    if (newC < 0) newC = 0;
                    if (colAbs) newRef += "$";
                    newRef += Evaluator::indexToColumn(newC);
                } else if (isWholeRow) {
                    int newR = rowAbs ? r : r + rOffset;
                    if (newR < 0) newR = 0;
                    if (rowAbs) newRef += "$";
                    newRef += std::to_string(newR + 1);
                } else {
                    int newR = rowAbs ? r : r + rOffset;
                    int newC = colAbs ? c : c + cOffset;
                    if (newR < 0) newR = 0;
                    if (newC < 0) newC = 0;
                    
                    if (colAbs) newRef += "$";
                    newRef += Evaluator::indexToColumn(newC);
                    if (rowAbs) newRef += "$";
                    newRef += std::to_string(newR + 1);
                }
                
                result += newRef;
                continue;
            }
        }
        if (t.type != TokenType::EQUAL || result != "=") {
            result += t.lexeme;
        }
    }
    return result;
}

std::string GridManager::pasteDataBlock(int startRow, int startCol, const std::string& csvText) {
    bool internalPaste = (csvText == copySourceText);
    int rOffset = startRow - copySourceRow;
    int cOffset = startCol - copySourceCol;
    
    std::string resultJson = "{";
    bool firstEntry = true;
    
    int row = startRow;
    size_t i = 0;
    while (i < csvText.length()) {
        size_t nextLine = csvText.find('\n', i);
        std::string line = (nextLine == std::string::npos) ? csvText.substr(i) : csvText.substr(i, nextLine - i);
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        
        if (line.empty() && nextLine == std::string::npos) {
            break;
        }

        int col = startCol;
        size_t j = 0;
        while (j <= line.length()) {
            size_t nextTab = line.find('\t', j);
            std::string cellVal = (nextTab == std::string::npos) ? line.substr(j) : line.substr(j, nextTab - j);
            
            size_t first = cellVal.find_first_not_of(" \t\r\n");
            if (first == std::string::npos) {
                cellVal = "";
            } else {
                size_t last = cellVal.find_last_not_of(" \t\r\n");
                cellVal = cellVal.substr(first, last - first + 1);
            }
            
            if (internalPaste && !cellVal.empty() && cellVal[0] == '=') {
                cellVal = shiftFormula(cellVal, rOffset, cOffset);
            }

            std::string cellRef = std::to_string(row) + ":" + std::to_string(col); // Dart uses row:col keys for _cellData
            if (!firstEntry) resultJson += ",";
            resultJson += "\"" + cellRef + "\":\"" + escapeJson(cellVal) + "\"";
            firstEntry = false;
            
            if (nextTab == std::string::npos) break;
            j = nextTab + 1;
            col++;
        }
        
        if (nextLine == std::string::npos) break;
        i = nextLine + 1;
        row++;
    }
    resultJson += "}";
    return resultJson;
}

std::string GridManager::copyDataBlock(int startRow, int startCol, int endRow, int endCol) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    std::string result = "";
    
    for (int r = startRow; r <= endRow; r++) {
        for (int c = startCol; c <= endCol; c++) {
            std::string cellRef = coordToCellRef(r, c);
            auto it = grid.find(cellRef);
            if (it != grid.end()) {
                if (!it->second.formula.empty()) {
                    result += it->second.formula;
                } else if (it->second.isConstant) {
                    if (it->second.constantStr.empty()) {
                        std::string numStr = std::to_string(it->second.constantNum);
                        numStr.erase(numStr.find_last_not_of('0') + 1, std::string::npos);
                        if (numStr.back() == '.') numStr.pop_back();
                        result += numStr;
                    } else {
                        result += it->second.constantStr;
                    }
                } else if (std::holds_alternative<std::string>(it->second.result)) {
                    result += std::get<std::string>(it->second.result);
                } else if (std::holds_alternative<double>(it->second.result)) {
                    double num = std::get<double>(it->second.result);
                    std::string numStr = std::to_string(num);
                    numStr.erase(numStr.find_last_not_of('0') + 1, std::string::npos);
                    if (numStr.back() == '.') numStr.pop_back();
                    result += numStr;
                }
            }
            if (c < endCol) result += "\t";
        }
        if (r < endRow) result += "\n";
    }
    
    copySourceRow = startRow;
    copySourceCol = startCol;
    copySourceText = result;
    
    return result;
}

std::string GridManager::getRawGrid() {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    std::string json = "{";
    bool first = true;
    for (const auto& pair : grid) {
        if (!first) json += ",";
        json += "\"" + pair.first + "\":";
        
        std::string rawVal;
        if (pair.second.isConstant) {
            if (pair.second.constantStr.empty()) {
                double val = pair.second.constantNum;
                if (std::floor(val) == val && !std::isinf(val) && !std::isnan(val) && std::abs(val) < 1e16) {
                    char buf[64];
                    snprintf(buf, sizeof(buf), "%.0f", val);
                    rawVal = buf;
                } else {
                    std::string s = std::to_string(val);
                    s.erase(s.find_last_not_of('0') + 1, std::string::npos);
                    if (!s.empty() && s.back() == '.') s.pop_back();
                    rawVal = s;
                }
            } else {
                rawVal = pair.second.constantStr;
            }
        } else {
            std::string f = pair.second.formula;
            while (!f.empty() && f[0] == '=') {
                f.erase(0, 1);
            }
            rawVal = "=" + f;
        }
        
        std::string escaped = escapeJson(rawVal);
        json += "\"" + escaped + "\"";
        first = false;
    }
    json += "}";
    return json;
}


// Helper: parse cell ref like "A1" into 0-indexed (row, col)
static bool parseCellRefHelper(const std::string& ref, int& row, int& col) {
    size_t i = 0;
    std::string colPart;
    while (i < ref.size() && std::isalpha(ref[i])) {
        colPart += std::toupper(ref[i]);
        i++;
    }
    if (colPart.empty() || i >= ref.size()) return false;
    std::string rowPart = ref.substr(i);
    int rowNum = 0;
    try { rowNum = std::stoi(rowPart); } catch (...) { return false; }
    row = rowNum - 1;
    col = 0;
    for (char ch : colPart) col = col * 26 + (ch - 'A' + 1);
    col -= 1;
    return true;
}

int GridManager::getLastRow() {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    int maxRow = 0;
    for (const auto& pair : grid) {
        if (pair.second.isConstant) {
            if (pair.second.constantStr.empty() && pair.second.constantNum == 0.0) continue;
            std::string strVal = pair.second.constantStr;
            while (!strVal.empty() && std::isspace((unsigned char)strVal.front())) strVal.erase(0, 1);
            while (!strVal.empty() && std::isspace((unsigned char)strVal.back())) strVal.pop_back();
            if (strVal.empty() && pair.second.constantNum == 0.0) continue;
        }
        int r, c;
        if (parseCellRefHelper(pair.first, r, c)) {
            if (r + 1 > maxRow) maxRow = r + 1;
        }
    }
    return maxRow;
}

int GridManager::getLastColumn() {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    int maxCol = 0;
    for (const auto& pair : grid) {
        if (pair.second.isConstant) {
            if (pair.second.constantStr.empty() && pair.second.constantNum == 0.0) continue;
            std::string strVal = pair.second.constantStr;
            while (!strVal.empty() && std::isspace((unsigned char)strVal.front())) strVal.erase(0, 1);
            while (!strVal.empty() && std::isspace((unsigned char)strVal.back())) strVal.pop_back();
            if (strVal.empty() && pair.second.constantNum == 0.0) continue;
        }
        int r, c;
        if (parseCellRefHelper(pair.first, r, c)) {
            if (c + 1 > maxCol) maxCol = c + 1;
        }
    }
    return maxCol;
}


void GridManager::clearCell(const std::string& cellRef) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    grid.erase(cellRef);
}

std::string GridManager::getCellFormula(const std::string& cellRef) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    auto it = grid.find(cellRef);
    if (it == grid.end()) return "";
    if (it->second.isConstant || it->second.formula.empty()) return "";
    std::string f = it->second.formula;
    while (!f.empty() && f[0] == '=') {
        f.erase(0, 1);
    }
    return "=" + f;
}

bool GridManager::isCellEmpty(const std::string& cellRef) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    return grid.find(cellRef) == grid.end();
}

void GridManager::mergeCells(const std::string& rangeStr) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    mergedRanges.push_back(rangeStr);
}

void GridManager::breakApartCells(const std::string& rangeStr) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    auto it = std::find(mergedRanges.begin(), mergedRanges.end(), rangeStr);
    if (it != mergedRanges.end()) {
        mergedRanges.erase(it);
    }
}

void GridManager::setColumnWidth(int col, int width) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    columnWidths[col] = width;
}

void GridManager::setRowHeight(int row, int height) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    rowHeights[row] = height;
}

// Helper for parseBounds (simplified)
static bool parseBnds(const std::string& s, int& r1, int& c1, int& r2, int& c2) {
    auto parseR = [](const std::string& ref, int& row, int& col) -> bool {
        size_t i = 0; std::string cp;
        while (i < ref.size() && std::isalpha(ref[i])) { cp += std::toupper(ref[i]); i++; }
        if (cp.empty() || i >= ref.size()) return false;
        try { row = std::stoi(ref.substr(i)) - 1; } catch (...) { return false; }
        col = 0; for (char ch : cp) col = col * 26 + (ch - 'A' + 1);
        col -= 1; return true;
    };
    size_t p = s.find(':');
    if (p == std::string::npos) {
        if (!parseR(s, r1, c1)) return false;
        r2 = r1; c2 = c1; return true;
    }
    return parseR(s.substr(0, p), r1, c1) && parseR(s.substr(p + 1), r2, c2);
}

static std::string mkRef(int row, int col) {
    std::string r; int c = col;
    while (c >= 0) { r = char('A' + (c % 26)) + r; c = c / 26 - 1; }
    return r + std::to_string(row + 1);
}

void GridManager::removeDuplicates(const std::string& rangeStr) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    int r1, c1, r2, c2;
    if (!parseBnds(rangeStr, r1, c1, r2, c2)) return;

    std::unordered_set<std::string> seen;
    int writeRow = r1;
    
    for (int r = r1; r <= r2; r++) {
        std::string rowHash = "";
        bool hasData = false;
        for (int c = c1; c <= c2; c++) {
            auto it = grid.find(mkRef(r, c));
            std::string val = "";
            if (it != grid.end()) {
                val = it->second.isConstant ? (it->second.constantStr.empty() ? std::to_string(it->second.constantNum) : it->second.constantStr) : it->second.formula;
                hasData = true;
            }
            rowHash += val + "|";
        }
        
        if (!hasData) continue;
        
        if (seen.find(rowHash) == seen.end()) {
            seen.insert(rowHash);
            if (writeRow != r) {
                for (int c = c1; c <= c2; c++) {
                    std::string refR = mkRef(r, c);
                    std::string refW = mkRef(writeRow, c);
                    auto it = grid.find(refR);
                    if (it != grid.end()) { grid[refW] = it->second; grid.erase(refR); }
                    else { grid.erase(refW); }
                }
            }
            writeRow++;
        } else {
            for (int c = c1; c <= c2; c++) grid.erase(mkRef(r, c));
        }
    }
}

void GridManager::findAndReplace(const std::string& rangeStr, const std::string& pattern, const std::string& replacement, bool isRegex) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    int r1, c1, r2, c2;
    if (!parseBnds(rangeStr, r1, c1, r2, c2)) return;

    std::regex re;
    if (isRegex) {
        try { re = std::regex(pattern); } catch (...) { return; }
    }

    for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
            std::string ref = mkRef(r, c);
            auto it = grid.find(ref);
            if (it != grid.end() && it->second.isConstant && !it->second.constantStr.empty()) {
                if (isRegex) {
                    it->second.constantStr = std::regex_replace(it->second.constantStr, re, replacement);
                } else {
                    std::string& str = it->second.constantStr;
                    size_t pos = 0;
                    while ((pos = str.find(pattern, pos)) != std::string::npos) {
                        str.replace(pos, pattern.length(), replacement);
                        pos += replacement.length();
                    }
                }
            }
        }
    }
}

void GridManager::setDataValidation(const std::string& rangeStr, const std::vector<std::string>& listValues) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    int r1, c1, r2, c2;
    if (!parseBnds(rangeStr, r1, c1, r2, c2)) return;
    
    for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
            dataValidations[mkRef(r, c)] = listValues;
        }
    }
}

void GridManager::flashFill(const std::string& sourceRangeStr, const std::string& targetRangeStr) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    int sr1, sc1, sr2, sc2, tr1, tc1, tr2, tc2;
    if (!parseBnds(sourceRangeStr, sr1, sc1, sr2, sc2)) return;
    if (!parseBnds(targetRangeStr, tr1, tc1, tr2, tc2)) return;
    if (sr2 - sr1 != tr2 - tr1) return;
    
    std::string src0 = ""; auto itS = grid.find(mkRef(sr1, sc1));
    if (itS != grid.end()) src0 = itS->second.constantStr;
    
    std::string tgt0 = ""; auto itT = grid.find(mkRef(tr1, tc1));
    if (itT != grid.end()) tgt0 = itT->second.constantStr;

    if (src0.empty() || tgt0.empty()) return;

    bool isPrefix = (src0.find(tgt0) == 0);
    bool isSuffix = (src0.length() >= tgt0.length() && src0.compare(src0.length() - tgt0.length(), tgt0.length(), tgt0) == 0);

    for (int r = 1; r <= sr2 - sr1; r++) {
        std::string src = "";
        auto it = grid.find(mkRef(sr1 + r, sc1));
        if (it != grid.end()) src = it->second.constantStr;
        
        std::string res = "";
        if (isPrefix) res = src.substr(0, tgt0.length());
        else if (isSuffix) res = src.substr(src.length() > tgt0.length() ? src.length() - tgt0.length() : 0);
        else res = src;
        setCellConstantString(mkRef(tr1 + r, tc1), res);
    }
}

EvalResult GridManager::evaluateCell(const std::string& cellRef) {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    return dfsEvaluate(cellRef, 0);
}

EvalResult GridManager::dfsEvaluate(const std::string& cellRef, int iterationDepth) {
    // Prevent stack overflow on deep cell chains
    if (iterationDepth > 500) {
        return CellError{"#CALC!"};
    }
    std::string cleanRef = cellRef;
    int normR = 0, normC = 0;
    if (Evaluator::parseCellCoordinates(cellRef, normR, normC)) {
        cleanRef = coordToCellRef(normR, normC);
    }
    auto it = grid.find(cleanRef);
    if (it == grid.end()) {
        auto sIt = spillGrid.find(cleanRef);
        if (sIt != spillGrid.end()) {
            return sIt->second;
        }
        return 0.0; // Empty cells evaluate to 0 by default in Excel math context
    }
    
    CellNode& node = it->second;
    
    if (node.isConstant) {
        return node.result;
    }
    
    if (node.state == CellState::EVALUATED) {
        return node.result;
    }
    
    if (node.state == CellState::VISITING) {
        // Circular reference detected!
        if (iterationDepth > 100) {
            // Max iterations reached, break the loop and return Circular Reference error
            return CellError{"#CIRC!"};
        }
        inIterativeCycle = true;
        // Don't mark as EVALUATED yet, allow it to compute again
    } else {
        node.state = CellState::VISITING;
    }
    
    // Evaluate formula
    try {
        std::string formulaToParse = node.formula;
        while (!formulaToParse.empty() && formulaToParse[0] == '=') {
            formulaToParse.erase(0, 1);
        }
        Tokenizer tokenizer(formulaToParse);
        auto tokens = tokenizer.tokenize();
        
        Parser parser(tokens);
        auto ast = parser.parse();
        
        // Extract row, col from cellRef if possible (e.g. "A1" -> r=0, c=0)
        int r = 0, c = 0;
        Evaluator::parseCellCoordinates(cellRef, r, c);
        
        Evaluator evaluator;
        evaluator.currentRow = r;
        evaluator.currentCol = c;
        evaluator.globalEnvironment = &g_namedRanges;
        evaluator.progressCallback = progressCallback;
        
        // Bind the callback so Evaluator can resolve internal cell references recursively
        evaluator.getCell = [this, iterationDepth](const std::string& ref) {
            return this->dfsEvaluate(ref, iterationDepth + 1);
        };
        
        evaluator.getRange = [this, iterationDepth](const std::string& topLeft, const std::string& bottomRight, const std::string& sheetName) -> ArrayVal {
            int r1 = 0, c1 = 0, r2 = 0, c2 = 0;
            bool topIsRow = false, topIsCol = false;
            bool botIsRow = false, botIsCol = false;
            
            if (!Evaluator::parseCellCoordinates(topLeft, r1, c1, &topIsRow, &topIsCol) || 
                !Evaluator::parseCellCoordinates(bottomRight, r2, c2, &botIsRow, &botIsCol)) {
                return ArrayVal{{{CellError{"#REF!"}}}};
            }
            
            // Safely expand whole column/row ranges like A:A or 1:1, or mixed like A1:A
            if (topIsCol || botIsCol) { 
                r1 = std::min(r1, r2); 
                r2 = 9999; 
            }
            if (topIsRow || botIsRow) { 
                c1 = std::min(c1, c2); 
                c2 = 255; 
            }

            int minR = std::min(r1, r2);
            int maxR = std::max(r1, r2);
            int minC = std::min(c1, c2);
            int maxC = std::max(c1, c2);
            
            // PREVENT OOM CRASHES: Cap range size to 100,000 cells max
            long long totalCells = (long long)(maxR - minR + 1) * (maxC - minC + 1);
            if (totalCells > 1048576) {
                return ArrayVal{{{CellError{"#NUM!"}}}};
            }
            
            ArrayVal res;
            for (int currR = minR; currR <= maxR; currR++) {
                std::vector<EvalResult> rowVals;
                for (int currC = minC; currC <= maxC; currC++) {
                    std::string ref = Evaluator::indexToColumn(currC) + std::to_string(currR + 1);
                    rowVals.push_back(this->dfsEvaluate(ref, iterationDepth + 1));
                }
                res.matrix.push_back(rowVals);
            }
            return res;
        };
        
        EvalResult newResult = evaluator.evaluate(ast.get());
        
        // Convergence Check for Iterative Calculation
        if (inIterativeCycle && std::holds_alternative<double>(node.result) && std::holds_alternative<double>(newResult)) {
            double oldVal = std::get<double>(node.result);
            double newVal = std::get<double>(newResult);
            if (std::abs(newVal - oldVal) < 0.001) {
                // Converged
                node.result = newResult;
                node.state = CellState::EVALUATED;
                inIterativeCycle = false;
                return node.result;
            }
        }
        
        node.result = newResult;
    } catch (...) {
        node.result = CellError{"#ERROR!"};
    }
    
    // Only mark as EVALUATED if we aren't stuck in a deep iterative cycle that is still converging
    // For simplicity, we just mark evaluated.
    if (!inIterativeCycle || iterationDepth == 0) {
        node.state = CellState::EVALUATED;
    }
    
    if (iterationDepth == 0) {
        inIterativeCycle = false;
    }
    
    return node.result;
}

std::string GridManager::formatEvalResult(const EvalResult& result, const std::string& cellRef) {
    std::string resStr;
    if (std::holds_alternative<double>(result)) {
        double val = std::get<double>(result);
        std::string s = std::to_string(val);
        s.erase(s.find_last_not_of('0') + 1, std::string::npos);
        if (s.back() == '.') s.pop_back();
        resStr = "\"" + s + "\""; // Store as string representation of number in JSON
    } else if (std::holds_alternative<std::string>(result)) {
        resStr = "\"" + escapeJson(std::get<std::string>(result)) + "\"";
    } else if (std::holds_alternative<bool>(result)) {
        resStr = std::get<bool>(result) ? "\"TRUE\"" : "\"FALSE\"";
    } else if (std::holds_alternative<CellError>(result)) {
        resStr = "\"" + std::get<CellError>(result).type + "\"";
    } else if (std::holds_alternative<Blank>(result)) {
        resStr = "\"\"";
    } else if (std::holds_alternative<ArrayVal>(result)) {
        const auto& mat = std::get<ArrayVal>(result).matrix;
        std::ostringstream ss;
        ss << "{\"type\":\"spill\",\"data\":[";
        for (size_t r = 0; r < mat.size(); r++) {
            ss << "[";
            for (size_t c = 0; c < mat[r].size(); c++) {
                ss << formatEvalResult(mat[r][c], "");
                if (c < mat[r].size() - 1) ss << ",";
            }
            ss << "]";
            if (r < mat.size() - 1) ss << ",";
        }
        ss << "]}";
        return ss.str();
    } else {
        resStr = "\"#VALUE!\"";
    }
    return resStr;
}

std::string GridManager::calculateAll() {
    std::lock_guard<std::recursive_mutex> lock(gridMutex);
    spillGrid.clear();

    // Reset states
    for (auto& pair : grid) {
        if (!pair.second.isConstant) {
            pair.second.state = CellState::UNVISITED;
        }
    }
    
    // Evaluate all cells
    std::ostringstream json;
    json << "{";
    bool first = true;
    
    for (auto& pair : grid) {
        // Evaluate all cells so Dart gets JS updates
        EvalResult res = dfsEvaluate(pair.first, 0);
        
        if (std::holds_alternative<ArrayVal>(res)) {
            const auto& mat = std::get<ArrayVal>(res).matrix;
            int r0 = 0, c0 = 0;
            Evaluator::parseCellCoordinates(pair.first, r0, c0);
            
            bool collision = false;
            for (size_t r = 0; r < mat.size(); r++) {
                for (size_t c = 0; c < mat[r].size(); c++) {
                    if (r == 0 && c == 0) continue; // Origin cell is fine
                    std::string spilledRef = coordToCellRef(r0 + (int)r, c0 + (int)c);
                    
                    if (spillGrid.find(spilledRef) != spillGrid.end()) {
                        collision = true; break;
                    }
                    auto itGrid = grid.find(spilledRef);
                    if (itGrid != grid.end()) {
                        if (!itGrid->second.formula.empty()) { collision = true; break; }
                        if (itGrid->second.isConstant) {
                            if (std::holds_alternative<std::string>(itGrid->second.result)) {
                                if (!std::get<std::string>(itGrid->second.result).empty()) { collision = true; break; }
                            } else if (!std::holds_alternative<Blank>(itGrid->second.result)) {
                                collision = true; break;
                            }
                        }
                    }
                }
                if (collision) break;
            }
            
            if (collision) {
                res = CellError{"#SPILL!"};
                pair.second.result = res;
            } else {
                for (size_t r = 0; r < mat.size(); r++) {
                    for (size_t c = 0; c < mat[r].size(); c++) {
                        std::string spilledRef = coordToCellRef(r0 + (int)r, c0 + (int)c);
                        spillGrid[spilledRef] = mat[r][c];
                    }
                }
            }
        }
        
        if (!first) json << ",";
        json << "\"" << pair.first << "\":" << formatEvalResult(res, pair.first);
        first = false;
    }
    
    json << "}";
    return json.str();
}
