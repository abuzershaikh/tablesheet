#include "../function_registry.h"
#include <string>
#include <cctype>
#include <algorithm>

/**
 * Case-insensitive equality check supporting numeric and string values.
 */
static bool isEquals(const EvalResult& val1, const EvalResult& val2) {
    if (std::holds_alternative<double>(val1) && std::holds_alternative<double>(val2)) {
        return std::get<double>(val1) == std::get<double>(val2);
    }
    std::string s1 = Evaluator::asString(val1);
    std::string s2 = Evaluator::asString(val2);
    if (s1.length() != s2.length()) return false;
    return std::equal(s1.begin(), s1.end(), s2.begin(), [](char a, char b) {
        return std::tolower((unsigned char)a) == std::tolower((unsigned char)b);
    });
}

/**
 * Excel Wildcard pattern matching (*, ?, ~) - Case Insensitive
 */
static bool wildcardMatch(const std::string& pat, const std::string& txt) {
    size_t p = 0, t = 0;
    size_t starP = std::string::npos, starT = std::string::npos;
    
    while (t < txt.length()) {
        if (p < pat.length() && pat[p] == '~' && p + 1 < pat.length()) {
            char escaped = std::tolower((unsigned char)pat[p + 1]);
            char c = std::tolower((unsigned char)txt[t]);
            if (escaped == c) {
                p += 2;
                t++;
            } else if (starP != std::string::npos) {
                p = starP + 1;
                starT++;
                t = starT;
            } else {
                return false;
            }
        } else if (p < pat.length() && (pat[p] == '?' || std::tolower((unsigned char)pat[p]) == std::tolower((unsigned char)txt[t]))) {
            p++;
            t++;
        } else if (p < pat.length() && pat[p] == '*') {
            starP = p;
            starT = t;
            p++;
        } else if (starP != std::string::npos) {
            p = starP + 1;
            starT++;
            t = starT;
        } else {
            return false;
        }
    }
    
    while (p < pat.length() && pat[p] == '*') {
        p++;
    }
    
    return p == pat.length();
}

/**
 * Core VLOOKUP single item lookup handler
 */
static EvalResult vlookupSingle(Evaluator& eval, const EvalResult& lookup_val, const EvalResult& table, int col, bool exactMatch) {
    if (Evaluator::isError(lookup_val)) return lookup_val;
    if (!std::holds_alternative<ArrayVal>(table)) return CellError{"#VALUE!"};
    
    const auto& matrix = std::get<ArrayVal>(table).matrix;
    if (matrix.empty() || matrix[0].empty()) return CellError{"#N/A"};
    if (col > (int)matrix[0].size()) return CellError{"#REF!"};
    
    bool is_num_search = std::holds_alternative<double>(lookup_val);
    double search_num = is_num_search ? std::get<double>(lookup_val) : 0.0;
    std::string search_str = Evaluator::asString(lookup_val);
    
    bool hasWildcard = exactMatch && !is_num_search && 
                       (search_str.find('*') != std::string::npos || search_str.find('?') != std::string::npos);

    if (exactMatch) {
        for (const auto& row : matrix) {
            if (row.empty()) continue;
            if (Evaluator::isError(row[0])) continue;
            
            bool match = false;
            if (hasWildcard) {
                match = wildcardMatch(search_str, Evaluator::asString(row[0]));
            } else {
                match = isEquals(row[0], lookup_val);
            }
            
            if (match) {
                if (col > (int)row.size()) return CellError{"#REF!"};
                return row[col - 1];
            }
        }
        return CellError{"#N/A"};
    } else {
        EvalResult best_match = CellError{"#N/A"};
        
        // Fast Binary Search for large matrices (> 64 rows)
        if (matrix.size() > 64) {
            int low = 0, high = (int)matrix.size() - 1;
            int foundIdx = -1;
            while (low <= high) {
                int mid = low + (high - low) / 2;
                const auto& cell = matrix[mid][0];
                if (Evaluator::isError(cell)) {
                    high = mid - 1;
                    continue;
                }
                
                bool is_less_equal = false;
                if (is_num_search) {
                    if (std::holds_alternative<double>(cell)) {
                        is_less_equal = std::get<double>(cell) <= search_num;
                    } else {
                        is_less_equal = false;
                    }
                } else {
                    if (std::holds_alternative<double>(cell)) {
                        is_less_equal = true;
                    } else {
                        std::string cellStr = Evaluator::asString(cell);
                        std::string sLower = search_str, cLower = cellStr;
                        for (char& c : sLower) c = std::tolower((unsigned char)c);
                        for (char& c : cLower) c = std::tolower((unsigned char)c);
                        is_less_equal = cLower <= sLower;
                    }
                }
                
                if (is_less_equal) {
                    foundIdx = mid;
                    low = mid + 1;
                } else {
                    high = mid - 1;
                }
            }
            if (foundIdx != -1) {
                if (col > (int)matrix[foundIdx].size()) return CellError{"#REF!"};
                return matrix[foundIdx][col - 1];
            }
            return CellError{"#N/A"};
        }

        for (const auto& row : matrix) {
            if (row.empty()) continue;
            if (Evaluator::isError(row[0])) continue;
            
            bool is_less_equal = false;
            if (is_num_search) {
                if (std::holds_alternative<double>(row[0])) {
                    is_less_equal = std::get<double>(row[0]) <= search_num;
                } else {
                    is_less_equal = false;
                }
            } else {
                if (std::holds_alternative<double>(row[0])) {
                    is_less_equal = true;
                } else {
                    std::string rowStr = Evaluator::asString(row[0]);
                    std::string sLower = search_str, rLower = rowStr;
                    for (char& c : sLower) c = std::tolower((unsigned char)c);
                    for (char& c : rLower) c = std::tolower((unsigned char)c);
                    is_less_equal = rLower <= sLower;
                }
            }
            
            if (is_less_equal) {
                if (col > (int)row.size()) best_match = CellError{"#REF!"};
                else best_match = row[col - 1];
            } else {
                break;
            }
        }
        return best_match;
    }
}

/**
 * Core HLOOKUP single item lookup handler
 */
static EvalResult hlookupSingle(Evaluator& eval, const EvalResult& lookup_val, const EvalResult& table, int rowIdx, bool exactMatch) {
    if (Evaluator::isError(lookup_val)) return lookup_val;
    if (!std::holds_alternative<ArrayVal>(table)) return CellError{"#VALUE!"};
    
    const auto& matrix = std::get<ArrayVal>(table).matrix;
    if (matrix.empty() || matrix[0].empty()) return CellError{"#N/A"};
    if (rowIdx < 1 || rowIdx > (int)matrix.size()) return CellError{"#REF!"};
    
    bool is_num_search = std::holds_alternative<double>(lookup_val);
    double search_num = is_num_search ? std::get<double>(lookup_val) : 0.0;
    std::string search_str = Evaluator::asString(lookup_val);
    
    bool hasWildcard = exactMatch && !is_num_search && 
                       (search_str.find('*') != std::string::npos || search_str.find('?') != std::string::npos);

    if (exactMatch) {
        for (size_t c = 0; c < matrix[0].size(); c++) {
            const auto& cell = matrix[0][c];
            if (Evaluator::isError(cell)) continue;
            
            bool match = false;
            if (hasWildcard) {
                match = wildcardMatch(search_str, Evaluator::asString(cell));
            } else {
                match = isEquals(cell, lookup_val);
            }
            
            if (match) {
                if (c >= matrix[rowIdx - 1].size()) return CellError{"#REF!"};
                return matrix[rowIdx - 1][c];
            }
        }
        return CellError{"#N/A"};
    } else {
        EvalResult best_match = CellError{"#N/A"};
        for (size_t c = 0; c < matrix[0].size(); c++) {
            const auto& cell = matrix[0][c];
            if (Evaluator::isError(cell)) continue;
            
            bool is_less_equal = false;
            if (is_num_search) {
                if (std::holds_alternative<double>(cell)) {
                    is_less_equal = std::get<double>(cell) <= search_num;
                } else {
                    is_less_equal = false;
                }
            } else {
                if (std::holds_alternative<double>(cell)) {
                    is_less_equal = true;
                } else {
                    std::string cellStr = Evaluator::asString(cell);
                    std::string sLower = search_str, cLower = cellStr;
                    for (char& ch : sLower) ch = std::tolower((unsigned char)ch);
                    for (char& ch : cLower) ch = std::tolower((unsigned char)ch);
                    is_less_equal = cLower <= sLower;
                }
            }
            
            if (is_less_equal) {
                if (c >= matrix[rowIdx - 1].size()) best_match = CellError{"#REF!"};
                else best_match = matrix[rowIdx - 1][c];
            } else {
                break;
            }
        }
        return best_match;
    }
}

void FunctionRegistry::registerLookupFunctions() {
    
    /**
     * VLOOKUP - Vertical lookup function
     */
    registerFunction("VLOOKUP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 4) return CellError{"#VALUE!"};
        
        auto lookup_val = eval.evaluate(args[0].get());
        if (Evaluator::isError(lookup_val)) return lookup_val;
        
        auto table = eval.evaluate(args[1].get());
        if (Evaluator::isError(table)) return table;
        
        auto col_index = eval.evaluate(args[2].get());
        if (Evaluator::isError(col_index)) return col_index;
        
        int col = (int)Evaluator::asNumber(col_index);
        if (col < 1) return CellError{"#VALUE!"};
        
        bool exactMatch = false;
        if (args.size() == 4) {
            auto range_lookup = eval.evaluate(args[3].get());
            if (Evaluator::isError(range_lookup)) return range_lookup;
            exactMatch = !Evaluator::asBool(range_lookup);
        }

        if (std::holds_alternative<ArrayVal>(lookup_val)) {
            const auto& inputMatrix = std::get<ArrayVal>(lookup_val).matrix;
            ArrayVal resMatrix;
            for (const auto& inputRow : inputMatrix) {
                std::vector<EvalResult> outRow;
                for (const auto& item : inputRow) {
                    outRow.push_back(vlookupSingle(eval, item, table, col, exactMatch));
                }
                resMatrix.matrix.push_back(outRow);
            }
            return resMatrix;
        }

        return vlookupSingle(eval, lookup_val, table, col, exactMatch);
    });

    /**
     * HLOOKUP - Horizontal lookup function
     */
    registerFunction("HLOOKUP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 4) return CellError{"#VALUE!"};
        
        auto lookup_val = eval.evaluate(args[0].get());
        if (Evaluator::isError(lookup_val)) return lookup_val;
        
        auto table = eval.evaluate(args[1].get());
        if (Evaluator::isError(table)) return table;
        
        auto row_index = eval.evaluate(args[2].get());
        if (Evaluator::isError(row_index)) return row_index;
        
        int rowIdx = (int)Evaluator::asNumber(row_index);
        if (rowIdx < 1) return CellError{"#VALUE!"};
        
        bool exactMatch = false;
        if (args.size() == 4) {
            auto range_lookup = eval.evaluate(args[3].get());
            if (Evaluator::isError(range_lookup)) return range_lookup;
            exactMatch = !Evaluator::asBool(range_lookup);
        }

        if (std::holds_alternative<ArrayVal>(lookup_val)) {
            const auto& inputMatrix = std::get<ArrayVal>(lookup_val).matrix;
            ArrayVal resMatrix;
            for (const auto& inputRow : inputMatrix) {
                std::vector<EvalResult> outRow;
                for (const auto& item : inputRow) {
                    outRow.push_back(hlookupSingle(eval, item, table, rowIdx, exactMatch));
                }
                resMatrix.matrix.push_back(outRow);
            }
            return resMatrix;
        }

        return hlookupSingle(eval, lookup_val, table, rowIdx, exactMatch);
    });

    // INDEX(array, row_num, [column_num])
    registerFunction("INDEX", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        
        auto table = eval.evaluate(args[0].get());
        if (Evaluator::isError(table)) return table;
        if (!std::holds_alternative<ArrayVal>(table)) return CellError{"#VALUE!"};
        
        auto row_num = eval.evaluate(args[1].get());
        if (Evaluator::isError(row_num)) return row_num;
        
        int r = (int)Evaluator::asNumber(row_num);
        int c = 1;
        const auto& matrix = std::get<ArrayVal>(table).matrix;
        
        if (args.size() == 2) {
            if (matrix.size() == 1) {
                c = r;
                r = 1;
            } else if (matrix.size() > 1 && matrix[0].size() > 1) {
                return CellError{"#REF!"};
            }
        } else {
            auto col_num = eval.evaluate(args[2].get());
            if (Evaluator::isError(col_num)) return col_num;
            c = (int)Evaluator::asNumber(col_num);
        }
        
        if (r == 0 && c == 0) return table;
        
        if (r == 0) {
            if (c < 1 || matrix.empty()) return CellError{"#REF!"};
            std::vector<std::vector<EvalResult>> new_mat;
            for (const auto& row : matrix) {
                if (c <= (int)row.size()) {
                    new_mat.push_back({row[c - 1]});
                } else {
                    new_mat.push_back({CellError{"#REF!"}});
                }
            }
            return ArrayVal{new_mat};
        }
        
        if (c == 0) {
            if (r < 1 || r > (int)matrix.size()) return CellError{"#REF!"};
            return ArrayVal{{matrix[r - 1]}};
        }
        
        if (r < 1 || r > (int)matrix.size()) return CellError{"#REF!"};
        const auto& row = matrix[r - 1];
        if (c < 1 || c > (int)row.size()) return CellError{"#REF!"};
        
        return row[c - 1];
    });

    // MATCH(lookup_value, lookup_array, [match_type])
    registerFunction("MATCH", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        
        auto lookup_val = eval.evaluate(args[0].get());
        if (Evaluator::isError(lookup_val)) return lookup_val;
        
        if (std::holds_alternative<ArrayVal>(lookup_val)) {
            const auto& mat = std::get<ArrayVal>(lookup_val).matrix;
            if (!mat.empty() && !mat[0].empty()) {
                lookup_val = mat[0][0];
            }
        }
        
        auto table = eval.evaluate(args[1].get());
        if (Evaluator::isError(table)) return table;
        if (!std::holds_alternative<ArrayVal>(table)) return CellError{"#VALUE!"};
        
        int match_type = 1;
        if (args.size() == 3) {
            auto mt = eval.evaluate(args[2].get());
            if (Evaluator::isError(mt)) return mt;
            match_type = (int)Evaluator::asNumber(mt);
        }
        
        bool is_num_search = std::holds_alternative<double>(lookup_val);
        double search_num = is_num_search ? std::get<double>(lookup_val) : 0.0;
        std::string search_str = Evaluator::asString(lookup_val);
        bool hasWildcard = (match_type == 0) && !is_num_search &&
                           (search_str.find('*') != std::string::npos || search_str.find('?') != std::string::npos);
        
        const auto& matrix = std::get<ArrayVal>(table).matrix;
        if (matrix.empty()) return CellError{"#N/A"};
        
        bool isRow = matrix.size() == 1;
        bool isCol = matrix.size() > 1 && matrix[0].size() == 1;
        if (!isRow && !isCol) return CellError{"#N/A"};
        
        int best_idx = -1;
        int count = isRow ? (int)matrix[0].size() : (int)matrix.size();
        
        if (match_type != 0 && count > 64) {
            int low = 0, high = count - 1;
            while (low <= high) {
                int mid = low + (high - low) / 2;
                EvalResult cell = isRow ? matrix[0][mid] : matrix[mid][0];
                if (Evaluator::isError(cell)) {
                    if (match_type == 1) high = mid - 1; // Ascending sort, errors at end -> go left
                    else low = mid + 1;                  // Descending sort, errors at start -> go right
                    continue;
                }
                
                if (match_type == 1) {
                    bool is_less_equal = false;
                    if (is_num_search) {
                        if (std::holds_alternative<double>(cell)) is_less_equal = std::get<double>(cell) <= search_num;
                        else is_less_equal = false;
                    } else {
                        if (std::holds_alternative<double>(cell)) is_less_equal = true;
                        else {
                            std::string cval = Evaluator::asString(cell);
                            std::string sLower = search_str, cLower = cval;
                            for (char& c : sLower) c = std::tolower((unsigned char)c);
                            for (char& c : cLower) c = std::tolower((unsigned char)c);
                            is_less_equal = cLower <= sLower;
                        }
                    }
                    if (is_less_equal) {
                        best_idx = mid;
                        low = mid + 1;
                    } else {
                        high = mid - 1;
                    }
                } else if (match_type == -1) {
                    bool is_greater_equal = false;
                    if (is_num_search) {
                        if (std::holds_alternative<double>(cell)) is_greater_equal = std::get<double>(cell) >= search_num;
                        else is_greater_equal = true; // num < string, so string is greater
                    } else {
                        if (std::holds_alternative<double>(cell)) is_greater_equal = false;
                        else {
                            std::string cval = Evaluator::asString(cell);
                            std::string sLower = search_str, cLower = cval;
                            for (char& c : sLower) c = std::tolower((unsigned char)c);
                            for (char& c : cLower) c = std::tolower((unsigned char)c);
                            is_greater_equal = cLower >= sLower;
                        }
                    }
                    if (is_greater_equal) {
                        best_idx = mid;
                        low = mid + 1; // descending -> right is smaller
                    } else {
                        high = mid - 1;
                    }
                }
            }
        } else {
            for (int i = 0; i < count; i++) {
                if (isCol && matrix[i].empty()) continue;
                EvalResult cell = isRow ? matrix[0][i] : matrix[i][0];
                if (Evaluator::isError(cell)) continue;
                
                if (match_type == 0) {
                    bool match = hasWildcard ? wildcardMatch(search_str, Evaluator::asString(cell)) : isEquals(cell, lookup_val);
                    if (match) return (double)(i + 1);
                } else if (match_type == 1) {
                    bool is_less_equal = false;
                    if (is_num_search) {
                        if (std::holds_alternative<double>(cell)) is_less_equal = std::get<double>(cell) <= search_num;
                        else is_less_equal = false;
                    } else {
                        if (std::holds_alternative<double>(cell)) is_less_equal = true;
                        else {
                            std::string cval = Evaluator::asString(cell);
                            std::string sLower = search_str, cLower = cval;
                            for (char& c : sLower) c = std::tolower((unsigned char)c);
                            for (char& c : cLower) c = std::tolower((unsigned char)c);
                            is_less_equal = cLower <= sLower;
                        }
                    }
                    if (is_less_equal) best_idx = i;
                    else break;
                } else if (match_type == -1) {
                    bool is_greater_equal = false;
                    if (is_num_search) {
                        if (std::holds_alternative<double>(cell)) is_greater_equal = std::get<double>(cell) >= search_num;
                        else is_greater_equal = true;
                    } else {
                        if (std::holds_alternative<double>(cell)) is_greater_equal = false;
                        else {
                            std::string cval = Evaluator::asString(cell);
                            std::string sLower = search_str, cLower = cval;
                            for (char& c : sLower) c = std::tolower((unsigned char)c);
                            for (char& c : cLower) c = std::tolower((unsigned char)c);
                            is_greater_equal = cLower >= sLower;
                        }
                    }
                    if (is_greater_equal) best_idx = i;
                    else break;
                }
            }
        }
        
        if (match_type != 0 && best_idx != -1) return (double)(best_idx + 1);
        return CellError{"#N/A"};
    });

    // XLOOKUP(lookup_value, lookup_array, return_array, [if_not_found], [match_mode], [search_mode])
    registerFunction("XLOOKUP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 6) return CellError{"#VALUE!"};

        auto lookup_val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(lookup_val)) return lookup_val;

        auto lookup_arr = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(lookup_arr)) return lookup_arr;

        auto return_arr = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(return_arr)) return return_arr;

        EvalResult if_not_found = CellError{"#N/A"};
        if (args.size() >= 4) {
            auto inf = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(inf)) return inf;
            if (!std::holds_alternative<Blank>(inf)) if_not_found = inf;
        }
        
        int match_mode = 0;
        if (args.size() >= 5) {
            auto mm = EVAL_ARG(eval, args, 4);
            if (Evaluator::isError(mm)) return mm;
            match_mode = (int)Evaluator::asNumber(mm);
        }
        
        int search_mode = 1;
        if (args.size() == 6) {
            auto sm = EVAL_ARG(eval, args, 5);
            if (Evaluator::isError(sm)) return sm;
            search_mode = (int)Evaluator::asNumber(sm);
        }

        std::vector<EvalResult> lCells, rCells;
        if (std::holds_alternative<ArrayVal>(lookup_arr)) {
            for (const auto& row : std::get<ArrayVal>(lookup_arr).matrix) {
                for (const auto& cell : row) lCells.push_back(cell);
            }
        } else {
            lCells.push_back(lookup_arr);
        }

        if (std::holds_alternative<ArrayVal>(return_arr)) {
            for (const auto& row : std::get<ArrayVal>(return_arr).matrix) {
                for (const auto& cell : row) rCells.push_back(cell);
            }
        } else {
            rCells.push_back(return_arr);
        }

        if (lCells.size() != rCells.size()) return CellError{"#VALUE!"};

        bool is_num_search = std::holds_alternative<double>(lookup_val);
        double search_num = is_num_search ? std::get<double>(lookup_val) : 0.0;
        std::string target = Evaluator::asString(lookup_val);
        
        int best_idx = -1;
        int start_idx = (search_mode == -1) ? (int)lCells.size() - 1 : 0;
        int end_idx = (search_mode == -1) ? -1 : (int)lCells.size();
        int step = (search_mode == -1) ? -1 : 1;
        
        for (int i = start_idx; i != end_idx; i += step) {
            if (Evaluator::isError(lCells[i])) continue;
            
            if (match_mode == 0) {
                if (isEquals(lCells[i], lookup_val)) {
                    best_idx = i;
                    break;
                }
            } else if (match_mode == 2) {
                // Wildcard match mode in XLOOKUP
                if (!is_num_search && wildcardMatch(target, Evaluator::asString(lCells[i]))) {
                    best_idx = i;
                    break;
                }
            } else if (match_mode == -1) {
                bool is_less_equal = false;
                if (is_num_search && std::holds_alternative<double>(lCells[i])) {
                    if (std::get<double>(lCells[i]) <= search_num) is_less_equal = true;
                } else {
                    if (Evaluator::asString(lCells[i]) <= target) is_less_equal = true;
                }
                
                if (is_less_equal) {
                    if (best_idx == -1) {
                        best_idx = i;
                    } else {
                        bool current_greater = false;
                        if (is_num_search && std::holds_alternative<double>(lCells[i]) && std::holds_alternative<double>(lCells[best_idx])) {
                            if (std::get<double>(lCells[i]) > std::get<double>(lCells[best_idx])) current_greater = true;
                        } else {
                            if (Evaluator::asString(lCells[i]) > Evaluator::asString(lCells[best_idx])) current_greater = true;
                        }
                        if (current_greater) best_idx = i;
                    }
                    if (isEquals(lCells[i], lookup_val)) break;
                }
            } else if (match_mode == 1) {
                bool is_greater_equal = false;
                if (is_num_search && std::holds_alternative<double>(lCells[i])) {
                    if (std::get<double>(lCells[i]) >= search_num) is_greater_equal = true;
                } else {
                    if (Evaluator::asString(lCells[i]) >= target) is_greater_equal = true;
                }
                
                if (is_greater_equal) {
                    if (best_idx == -1) {
                        best_idx = i;
                    } else {
                        bool current_smaller = false;
                        if (is_num_search && std::holds_alternative<double>(lCells[i]) && std::holds_alternative<double>(lCells[best_idx])) {
                            if (std::get<double>(lCells[i]) < std::get<double>(lCells[best_idx])) current_smaller = true;
                        } else {
                            if (Evaluator::asString(lCells[i]) < Evaluator::asString(lCells[best_idx])) current_smaller = true;
                        }
                        if (current_smaller) best_idx = i;
                    }
                    if (isEquals(lCells[i], lookup_val)) break;
                }
            }
        }
        
        if (best_idx != -1) {
            if (best_idx < rCells.size()) return rCells[best_idx];
            return CellError{"#N/A"};
        }
        
        return if_not_found;
    });

    // ------------------------------------------------------------------------
    // NEWLY ADDED P0/P1/P2/P3 CRITICAL LOOKUP FUNCTIONS
    // ------------------------------------------------------------------------

    // OFFSET(reference, rows, cols, [height], [width])
    registerFunction("OFFSET", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 5) return CellError{"#VALUE!"};
        
        auto cellRef = dynamic_cast<CellReferenceNode*>(args[0].get());
        auto rangeRef = dynamic_cast<RangeReferenceNode*>(args[0].get());
        
        std::string sheet = "";
        int startRow = -1, startCol = -1;
        int endRow = -1, endCol = -1;
        
        if (cellRef) {
            sheet = cellRef->sheetName;
            Evaluator::parseCellCoordinates(cellRef->cellName, startRow, startCol);
            endRow = startRow;
            endCol = startCol;
        } else if (rangeRef) {
            sheet = rangeRef->sheetName;
            Evaluator::parseCellCoordinates(rangeRef->topLeft, startRow, startCol);
            Evaluator::parseCellCoordinates(rangeRef->bottomRight, endRow, endCol);
        } else {
            return CellError{"#VALUE!"};
        }
        
        auto rowOffset = eval.evaluate(args[1].get());
        if (Evaluator::isError(rowOffset)) return rowOffset;
        auto colOffset = eval.evaluate(args[2].get());
        if (Evaluator::isError(colOffset)) return colOffset;
        
        int rOff = (int)Evaluator::asNumber(rowOffset);
        int cOff = (int)Evaluator::asNumber(colOffset);
        
        int h = (endRow - startRow) + 1;
        int w = (endCol - startCol) + 1;
        
        if (args.size() >= 4) {
            auto height = eval.evaluate(args[3].get());
            if (Evaluator::isError(height)) return height;
            if (!std::holds_alternative<Blank>(height)) {
                h = (int)Evaluator::asNumber(height);
                if (h == 0) return CellError{"#REF!"};
            }
        }
        if (args.size() == 5) {
            auto width = eval.evaluate(args[4].get());
            if (Evaluator::isError(width)) return width;
            if (!std::holds_alternative<Blank>(width)) {
                w = (int)Evaluator::asNumber(width);
                if (w == 0) return CellError{"#REF!"};
            }
        }
        
        int finalStartRow = startRow + rOff;
        int finalStartCol = startCol + cOff;
        if (finalStartRow < 0 || finalStartRow >= 1048576) return CellError{"#REF!"};
        if (finalStartCol < 0 || finalStartCol >= 16384) return CellError{"#REF!"};
        
        int finalEndRow = finalStartRow + std::abs(h) - 1;
        int finalEndCol = finalStartCol + std::abs(w) - 1;
        if (h < 0) {
            finalEndRow = finalStartRow;
            finalStartRow = finalStartRow + h + 1;
        }
        if (w < 0) {
            finalEndCol = finalStartCol;
            finalStartCol = finalStartCol + w + 1;
        }
        
        if (finalStartRow < 0 || finalEndRow >= 1048576) return CellError{"#REF!"};
        if (finalStartCol < 0 || finalEndCol >= 16384) return CellError{"#REF!"};
        
        std::string startStr = Evaluator::indexToColumn(finalStartCol) + std::to_string(finalStartRow + 1);
        std::string endStr = Evaluator::indexToColumn(finalEndCol) + std::to_string(finalEndRow + 1);
        
        if (finalStartRow == finalEndRow && finalStartCol == finalEndCol) {
            if (eval.getCell) {
                std::string fullRef = sheet.empty() ? startStr : sheet + "!" + startStr;
                return eval.getCell(fullRef);
            }
            return CellError{"#REF!"};
        } else {
            if (eval.getRange) {
                return eval.getRange(startStr, endStr, sheet);
            }
            return CellError{"#REF!"};
        }
    });

    // INDIRECT(ref_text, [a1])
    registerFunction("INDIRECT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto ref = eval.evaluate(args[0].get());
        if (Evaluator::isError(ref)) return ref;
        
        std::string refStr = Evaluator::asString(ref);
        
        std::string sheet = "";
        size_t bang = refStr.find('!');
        if (bang != std::string::npos) {
            sheet = refStr.substr(0, bang);
            refStr = refStr.substr(bang + 1);
            if (!sheet.empty() && sheet.front() == '\'' && sheet.back() == '\'') {
                sheet = sheet.substr(1, sheet.length() - 2);
            }
        }
        
        size_t colon = refStr.find(':');
        if (colon != std::string::npos) {
            std::string startStr = refStr.substr(0, colon);
            std::string endStr = refStr.substr(colon + 1);
            if (eval.getRange) {
                return eval.getRange(startStr, endStr, sheet);
            }
            return CellError{"#REF!"};
        } else {
            if (eval.getCell) {
                std::string fullRef = sheet.empty() ? refStr : sheet + "!" + refStr;
                return eval.getCell(fullRef);
            }
            return CellError{"#REF!"};
        }
    });

    // CHOOSE(index_num, value1, [value2], ...)
    registerFunction("CHOOSE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2) return CellError{"#VALUE!"};
        auto index_res = eval.evaluate(args[0].get());
        if (Evaluator::isError(index_res)) return index_res;
        
        int index = (int)Evaluator::asNumber(index_res);
        if (index < 1 || index > (int)args.size() - 1) return CellError{"#VALUE!"};
        
        return eval.evaluate(args[index].get());
    });

    // ADDRESS(row_num, col_num, [abs_num], [a1], [sheet_text])
    registerFunction("ADDRESS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 5) return CellError{"#VALUE!"};
        auto r_res = eval.evaluate(args[0].get());
        if (Evaluator::isError(r_res)) return r_res;
        auto c_res = eval.evaluate(args[1].get());
        if (Evaluator::isError(c_res)) return c_res;
        
        int r = (int)Evaluator::asNumber(r_res);
        int c = (int)Evaluator::asNumber(c_res);
        if (r < 1 || r > 1048576 || c < 1 || c > 16384) return CellError{"#VALUE!"};
        
        int abs_num = 1; // 1 = $A$1, 2 = A$1, 3 = $A1, 4 = A1
        if (args.size() >= 3) {
            auto a_res = eval.evaluate(args[2].get());
            if (Evaluator::isError(a_res)) return a_res;
            if (!std::holds_alternative<Blank>(a_res)) {
                abs_num = (int)Evaluator::asNumber(a_res);
                if (abs_num < 1 || abs_num > 4) return CellError{"#VALUE!"};
            }
        }
        
        std::string sheet = "";
        if (args.size() == 5) {
            auto s_res = eval.evaluate(args[4].get());
            if (Evaluator::isError(s_res)) return s_res;
            sheet = Evaluator::asString(s_res);
        }
        
        std::string colStr = Evaluator::indexToColumn(c - 1);
        std::string rowStr = std::to_string(r);
        
        std::string res = "";
        if (abs_num == 1 || abs_num == 3) res += "$";
        res += colStr;
        if (abs_num == 1 || abs_num == 2) res += "$";
        res += rowStr;
        
        if (!sheet.empty()) {
            if (sheet.find(' ') != std::string::npos || sheet.find('-') != std::string::npos) {
                res = "'" + sheet + "'!" + res;
            } else {
                res = sheet + "!" + res;
            }
        }
        return res;
    });

    // LOOKUP(lookup_value, lookup_vector, [result_vector])
    registerFunction("LOOKUP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        
        auto lookup_val = eval.evaluate(args[0].get());
        if (Evaluator::isError(lookup_val)) return lookup_val;
        
        auto lookup_vec = eval.evaluate(args[1].get());
        if (Evaluator::isError(lookup_vec)) return lookup_vec;
        if (!std::holds_alternative<ArrayVal>(lookup_vec)) return CellError{"#VALUE!"};
        
        const auto& lMat = std::get<ArrayVal>(lookup_vec).matrix;
        if (lMat.empty() || lMat[0].empty()) return CellError{"#N/A"};
        
        bool isRowVec = lMat.size() == 1;
        bool isColVec = lMat[0].size() == 1;
        
        if (!isRowVec && !isColVec) {
            bool searchCol = lMat.size() >= lMat[0].size();
            if (searchCol) {
                return vlookupSingle(eval, lookup_val, lookup_vec, (int)lMat[0].size(), false);
            } else {
                return hlookupSingle(eval, lookup_val, lookup_vec, (int)lMat.size(), false);
            }
        }
        
        EvalResult res_vec = lookup_vec;
        if (args.size() == 3) {
            res_vec = eval.evaluate(args[2].get());
            if (Evaluator::isError(res_vec)) return res_vec;
        }
        if (!std::holds_alternative<ArrayVal>(res_vec)) return CellError{"#VALUE!"};
        const auto& rMat = std::get<ArrayVal>(res_vec).matrix;
        bool rIsRow = rMat.size() == 1;
        
        int best_idx = -1;
        int count = isRowVec ? (int)lMat[0].size() : (int)lMat.size();
        
        bool is_num_search = std::holds_alternative<double>(lookup_val);
        double search_num = is_num_search ? std::get<double>(lookup_val) : 0.0;
        std::string search_str = Evaluator::asString(lookup_val);
        
        for (int i = 0; i < count; i++) {
            EvalResult cell = isRowVec ? lMat[0][i] : lMat[i][0];
            if (Evaluator::isError(cell)) continue;
            
            bool is_less_equal = false;
            if (is_num_search) {
                if (std::holds_alternative<double>(cell)) is_less_equal = std::get<double>(cell) <= search_num;
                else is_less_equal = false;
            } else {
                if (std::holds_alternative<double>(cell)) is_less_equal = true;
                else {
                    std::string cval = Evaluator::asString(cell);
                    std::string sLower = search_str, cLower = cval;
                    for (char& c : sLower) c = std::tolower((unsigned char)c);
                    for (char& c : cLower) c = std::tolower((unsigned char)c);
                    is_less_equal = cLower <= sLower;
                }
            }
            if (is_less_equal) best_idx = i;
        }
        
        if (best_idx != -1) {
            if (rIsRow) {
                if (best_idx < rMat[0].size()) return rMat[0][best_idx];
            } else {
                if (best_idx < rMat.size()) return rMat[best_idx][0];
            }
            return CellError{"#REF!"};
        }
        return CellError{"#N/A"};
    });

    // XLOOKUP(lookup_value, lookup_array, return_array, [if_not_found], [match_mode], [search_mode])
    registerFunction("XLOOKUP", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 6) return CellError{"#VALUE!"};
        
        auto lookupVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(lookupVal)) return lookupVal;
        
        auto lookupArr = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(lookupArr)) return lookupArr;
        
        auto returnArr = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(returnArr)) return returnArr;
        
        EvalResult ifNotFound = CellError{"#N/A"};
        if (args.size() >= 4) {
            auto inf = EVAL_ARG(eval, args, 3);
            if (!std::holds_alternative<Blank>(inf)) ifNotFound = inf;
        }
        
        int matchMode = 0; // 0=exact, -1=exact or next smaller, 1=exact or next larger, 2=wildcard
        if (args.size() >= 5) {
            auto mm = EVAL_ARG(eval, args, 4);
            if (!std::holds_alternative<Blank>(mm)) matchMode = (int)Evaluator::asNumber(mm);
        }
        
        int searchMode = 1; // 1=first-to-last, -1=last-to-first, 2=binary asc, -2=binary desc
        if (args.size() == 6) {
            auto sm = EVAL_ARG(eval, args, 5);
            if (!std::holds_alternative<Blank>(sm)) searchMode = (int)Evaluator::asNumber(sm);
        }
        
        // Flatten lookup_array and return_array
        auto lMat = std::holds_alternative<ArrayVal>(lookupArr) 
                    ? std::get<ArrayVal>(lookupArr).matrix 
                    : std::vector<std::vector<EvalResult>>{{lookupArr}};
                    
        auto rMat = std::holds_alternative<ArrayVal>(returnArr) 
                    ? std::get<ArrayVal>(returnArr).matrix 
                    : std::vector<std::vector<EvalResult>>{{returnArr}};
                    
        std::vector<EvalResult> lFlat;
        for (const auto& row : lMat) {
            for (const auto& c : row) lFlat.push_back(c);
        }
        
        if (lFlat.empty()) return ifNotFound;
        
        int matchedIdx = -1;
        std::string searchStr = Evaluator::asString(lookupVal);
        bool isNumSearch = std::holds_alternative<double>(lookupVal);
        double searchNum = isNumSearch ? std::get<double>(lookupVal) : 0.0;
        
        if (searchMode == 1 || searchMode == -1) {
            int start = (searchMode == 1) ? 0 : (int)lFlat.size() - 1;
            int end = (searchMode == 1) ? (int)lFlat.size() : -1;
            int step = (searchMode == 1) ? 1 : -1;
            
            int bestSmallerIdx = -1;
            int bestLargerIdx = -1;
            
            for (int i = start; i != end; i += step) {
                if (Evaluator::isError(lFlat[i])) continue;
                
                bool exact = false;
                if (matchMode == 2 && !isNumSearch) {
                    exact = wildcardMatch(searchStr, Evaluator::asString(lFlat[i]));
                } else {
                    exact = isEquals(lFlat[i], lookupVal);
                }
                
                if (exact) {
                    matchedIdx = i;
                    break;
                }
                
                // Track next smaller / next larger
                if (matchMode == -1) { // next smaller
                    if (isNumSearch && std::holds_alternative<double>(lFlat[i])) {
                        double v = std::get<double>(lFlat[i]);
                        if (v < searchNum) {
                            if (bestSmallerIdx == -1 || v > std::get<double>(lFlat[bestSmallerIdx])) bestSmallerIdx = i;
                        }
                    }
                } else if (matchMode == 1) { // next larger
                    if (isNumSearch && std::holds_alternative<double>(lFlat[i])) {
                        double v = std::get<double>(lFlat[i]);
                        if (v > searchNum) {
                            if (bestLargerIdx == -1 || v < std::get<double>(lFlat[bestLargerIdx])) bestLargerIdx = i;
                        }
                    }
                }
            }
            
            if (matchedIdx == -1) {
                if (matchMode == -1 && bestSmallerIdx != -1) matchedIdx = bestSmallerIdx;
                else if (matchMode == 1 && bestLargerIdx != -1) matchedIdx = bestLargerIdx;
            }
        }
        
        if (matchedIdx == -1) return ifNotFound;
        
        // Return corresponding row or cell from return_array
        if (rMat.size() == lFlat.size()) {
            if (rMat[matchedIdx].size() == 1) return rMat[matchedIdx][0];
            ArrayVal res;
            res.matrix.push_back(rMat[matchedIdx]);
            return res;
        } else {
            // Flatten return array
            std::vector<EvalResult> rFlat;
            for (const auto& row : rMat) {
                for (const auto& c : row) rFlat.push_back(c);
            }
            if (matchedIdx < (int)rFlat.size()) return rFlat[matchedIdx];
            return ifNotFound;
        }
    });
}
