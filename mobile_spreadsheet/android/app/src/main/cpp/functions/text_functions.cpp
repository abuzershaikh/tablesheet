#include "../function_registry.h"
#include <string>
#include <algorithm>
#include <cctype>





void FunctionRegistry::registerTextFunctions() {
    
    // LEN(text)
    registerFunction("LEN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        return (double)Evaluator::asString(val).length();
    });

    // LEFT(text, [num_chars])
    registerFunction("LEFT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string text = Evaluator::asString(val);
        int num = 1;
        if (args.size() == 2) {
            auto num_val = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(num_val)) return num_val;
            num = (int)Evaluator::asNumber(num_val);
        }
        if (num < 0) return CellError{"#VALUE!"};
        if (num > (int)text.length()) num = (int)text.length();
        
        return text.substr(0, num);
    });

    // RIGHT(text, [num_chars])
    registerFunction("RIGHT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string text = Evaluator::asString(val);
        int num = 1;
        if (args.size() == 2) {
            auto num_val = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(num_val)) return num_val;
            num = (int)Evaluator::asNumber(num_val);
        }
        if (num < 0) return CellError{"#VALUE!"};
        if (num > (int)text.length()) num = (int)text.length();
        
        return text.substr(text.length() - num, num);
    });

    // MID(text, start_num, num_chars)
    registerFunction("MID", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto start_val = EVAL_ARG(eval, args, 1);
        auto num_val = EVAL_ARG(eval, args, 2);
        
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(start_val)) return start_val;
        if (Evaluator::isError(num_val)) return num_val;
        
        std::string text = Evaluator::asString(val);
        int start = (int)Evaluator::asNumber(start_val);
        int num = (int)Evaluator::asNumber(num_val);
        
        if (start < 1 || num < 0) return CellError{"#VALUE!"};
        if (start > (int)text.length()) return std::string("");
        
        int available = (int)text.length() - (start - 1);
        if (num > available) num = available;
        
        return text.substr(start - 1, num);
    });

    // LOWER(text)
    registerFunction("LOWER", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        std::string text = Evaluator::asString(val);
        std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c){ return std::tolower(c); });
        return text;
    });

    // UPPER(text)
    registerFunction("UPPER", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string text = Evaluator::asString(val);
        std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c){ return std::toupper(c); });
        return text;
    });

    // TRIM(text)
    registerFunction("TRIM", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string text = Evaluator::asString(val);
        
        // Remove leading spaces
        size_t start = text.find_first_not_of(" \t\n\r");
        if (start == std::string::npos) return std::string("");
        
        // Remove trailing spaces
        size_t end = text.find_last_not_of(" \t\n\r");
        
        // Remove extra internal spaces
        std::string trimmed = text.substr(start, end - start + 1);
        std::string result;
        bool inSpace = false;
        
        for (char c : trimmed) {
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                if (!inSpace) {
                    result += ' ';
                    inSpace = true;
                }
            } else {
                result += c;
                inSpace = false;
            }
        }
        
        return result;
    });

    // CONCATENATE(text1, [text2], ...) & CONCAT
    auto concatLambda = [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty()) return CellError{"#VALUE!"};
        std::string result = "";
        for (const auto& arg : args) {
            auto val = eval.evaluate(arg.get());
            if (Evaluator::isError(val)) return val;
            
            if (std::holds_alternative<ArrayVal>(val)) {
                for (const auto& row : std::get<ArrayVal>(val).matrix) {
                    for (const auto& cell : row) {
                        result += Evaluator::asString(cell);
                    }
                }
            } else {
                result += Evaluator::asString(val);
            }
        }
        return result;
    };
    registerFunction("CONCATENATE", concatLambda);
    registerFunction("CONCAT", concatLambda);

    // EXACT(text1, text2)
    registerFunction("EXACT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val1 = EVAL_ARG(eval, args, 0);
        auto val2 = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val1)) return val1;
        if (Evaluator::isError(val2)) return val2;
        return Evaluator::asString(val1) == Evaluator::asString(val2);
    });

    // FIND(find_text, within_text, [start_num])
    registerFunction("FIND", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto find_val = EVAL_ARG(eval, args, 0);
        auto within_val = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(find_val)) return find_val;
        if (Evaluator::isError(within_val)) return within_val;
        
        std::string find_text = Evaluator::asString(find_val);
        std::string within_text = Evaluator::asString(within_val);
        
        int start = 1;
        if (args.size() == 3) {
            auto start_val = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(start_val)) return start_val;
            start = (int)Evaluator::asNumber(start_val);
        }
        if (start < 1) return CellError{"#VALUE!"};
        
        size_t pos = within_text.find(find_text, start - 1);
        if (pos == std::string::npos) return CellError{"#VALUE!"};
        
        return (double)(pos + 1);
    });

    // SUBSTITUTE(text, old_text, new_text, [instance_num])
    registerFunction("SUBSTITUTE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3 || args.size() > 4) return CellError{"#VALUE!"};
        auto text_val = EVAL_ARG(eval, args, 0);
        auto old_val = EVAL_ARG(eval, args, 1);
        auto new_val = EVAL_ARG(eval, args, 2);
        
        if (Evaluator::isError(text_val)) return text_val;
        if (Evaluator::isError(old_val)) return old_val;
        if (Evaluator::isError(new_val)) return new_val;
        
        std::string text = Evaluator::asString(text_val);
        std::string old_text = Evaluator::asString(old_val);
        std::string new_text = Evaluator::asString(new_val);
        
        if (old_text.empty()) return text;
        
        int instance = -1;
        if (args.size() == 4) {
            auto inst_val = EVAL_ARG(eval, args, 3);
            if (Evaluator::isError(inst_val)) return inst_val;
            instance = (int)Evaluator::asNumber(inst_val);
            if (instance < 1) return CellError{"#VALUE!"};
        }
        
        std::string result = text;
        size_t pos = 0;
        int count = 0;
        
        while ((pos = result.find(old_text, pos)) != std::string::npos) {
            count++;
            if (instance == -1 || instance == count) {
                result.replace(pos, old_text.length(), new_text);
                pos += new_text.length();
                if (instance != -1) break;
            } else {
                pos += old_text.length();
            }
        }
        return result;
    });

    // CHAR(number) - supports scalar or array argument
    registerFunction("CHAR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        auto toChar = [](const EvalResult& item) -> EvalResult {
            if (Evaluator::isError(item)) return item;
            int code = (int)Evaluator::asNumber(item);
            if (code < 1 || code > 255) return CellError{"#VALUE!"};
            return std::string(1, (char)code);
        };

        if (std::holds_alternative<ArrayVal>(val)) {
            ArrayVal resultArr;
            for (const auto& row : std::get<ArrayVal>(val).matrix) {
                std::vector<EvalResult> newRow;
                for (const auto& cell : row) {
                    newRow.push_back(toChar(cell));
                }
                resultArr.matrix.push_back(newRow);
            }
            return resultArr;
        }

        return toChar(val);
    });

    // CODE(text)
    registerFunction("CODE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        std::string str = Evaluator::asString(val);
        if (str.empty()) return CellError{"#VALUE!"};
        return (double)(unsigned char)str[0];
    });

    // TEXTJOIN(delimiter, ignore_empty, text1, [text2], ...)
    registerFunction("TEXTJOIN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 3) return CellError{"#VALUE!"};
        auto delimVal = EVAL_ARG(eval, args, 0);
        auto ignVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(delimVal)) return delimVal;
        if (Evaluator::isError(ignVal)) return ignVal;

        std::string delim = Evaluator::asString(delimVal);
        bool ignoreEmpty = Evaluator::asBool(ignVal);

        std::string result = "";
        bool first = true;

        for (size_t i = 2; i < args.size(); i++) {
            auto val = EVAL_ARG(eval, args, i);
            if (Evaluator::isError(val)) return val;

            std::vector<std::string> items;
            if (std::holds_alternative<ArrayVal>(val)) {
                for (const auto& row : std::get<ArrayVal>(val).matrix) {
                    for (const auto& cell : row) items.push_back(Evaluator::asString(cell));
                }
            } else {
                items.push_back(Evaluator::asString(val));
            }

            for (const auto& item : items) {
                if (ignoreEmpty && item.empty()) continue;
                if (!first) result += delim;
                result += item;
                first = false;
            }
        }
        return result;
    });

    // TEXTSPLIT(text, col_delimiter, [row_delimiter], [ignore_empty])
    registerFunction("TEXTSPLIT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 4) return CellError{"#VALUE!"};
        auto textVal = EVAL_ARG(eval, args, 0);
        auto delimVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(textVal)) return textVal;
        if (Evaluator::isError(delimVal)) return delimVal;

        std::string text = Evaluator::asString(textVal);
        std::string colDelim = Evaluator::asString(delimVal);
        std::string rowDelim = "";
        bool ignoreEmpty = false;
        
        if (args.size() >= 3) {
            auto rDelimVal = EVAL_ARG(eval, args, 2);
            if (!Evaluator::isError(rDelimVal)) rowDelim = Evaluator::asString(rDelimVal);
        }
        if (args.size() == 4) {
            auto ignVal = EVAL_ARG(eval, args, 3);
            if (!Evaluator::isError(ignVal)) ignoreEmpty = Evaluator::asBool(ignVal);
        }

        if (colDelim.empty() && rowDelim.empty()) return CellError{"#VALUE!"};

        ArrayVal res;
        
        auto splitStr = [](const std::string& s, const std::string& delim, bool ignore) {
            std::vector<std::string> parts;
            if (delim.empty()) { parts.push_back(s); return parts; }
            size_t start = 0, pos = 0;
            while ((pos = s.find(delim, start)) != std::string::npos) {
                std::string part = s.substr(start, pos - start);
                if (!ignore || !part.empty()) parts.push_back(part);
                start = pos + delim.length();
            }
            std::string last = s.substr(start);
            if (!ignore || !last.empty() || (parts.empty() && !ignore)) parts.push_back(last);
            return parts;
        };
        
        std::vector<std::string> rows = rowDelim.empty() ? std::vector<std::string>{text} : splitStr(text, rowDelim, ignoreEmpty);
        
        for (const auto& r : rows) {
            std::vector<std::string> cols = colDelim.empty() ? std::vector<std::string>{r} : splitStr(r, colDelim, ignoreEmpty);
            std::vector<EvalResult> evalRow;
            for (const auto& c : cols) evalRow.push_back(c);
            if (!evalRow.empty() || !ignoreEmpty) {
                if (evalRow.empty()) evalRow.push_back("");
                res.matrix.push_back(evalRow);
            }
        }
        
        if (res.matrix.empty()) res.matrix.push_back({""});
        return res;
    });

    // VALUE(text)
    registerFunction("VALUE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        try {
            return std::stod(Evaluator::asString(val));
        } catch (...) {
            return CellError{"#VALUE!"};
        }
    });

    // TEXT(value, format_text) - Full Excel date/number format support + array vectorization
    registerFunction("TEXT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto fmt = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(fmt)) return fmt;

        std::string format = Evaluator::asString(fmt);

        // ── Helper: format one scalar value ──────────────────────────
        auto formatOne = [&](const EvalResult& cellVal) -> EvalResult {
            if (Evaluator::isError(cellVal)) return cellVal;

            std::string fmtLower = format;
            std::transform(fmtLower.begin(), fmtLower.end(), fmtLower.begin(), ::tolower);

            // Detect date format tokens
            bool isDateFmt = fmtLower.find('y') != std::string::npos ||
                             fmtLower.find("mmm") != std::string::npos ||
                             fmtLower.find("ddd") != std::string::npos;
            if (!isDateFmt && fmtLower.find('d') != std::string::npos &&
                fmtLower.find('m') != std::string::npos) {
                isDateFmt = true;
            }

            if (isDateFmt) {
                // Parse value as date string "YYYY-MM-DD" or "YYYY-MM-DD HH:MM:SS"
                int y = 0, mo = 0, da = 0, h = 0, mi = 0, se = 0;
                bool parsed = false;

                std::string str = Evaluator::asString(cellVal);
                if (str.size() >= 10 && str[4] == '-' && str[7] == '-') {
                    try {
                        y  = std::stoi(str.substr(0, 4));
                        mo = std::stoi(str.substr(5, 2));
                        da = std::stoi(str.substr(8, 2));
                        parsed = true;
                        if (str.size() >= 19 && str[10] == ' ' && str[13] == ':') {
                            h  = std::stoi(str.substr(11, 2));
                            mi = std::stoi(str.substr(14, 2));
                            se = std::stoi(str.substr(17, 2));
                        }
                    } catch (...) {}
                }
                // Try MM/DD/YYYY
                if (!parsed && str.size() >= 10) {
                    auto p1 = str.find('/');
                    auto p2 = str.find('/', p1 + 1);
                    if (p1 != std::string::npos && p2 != std::string::npos) {
                        try {
                            mo = std::stoi(str.substr(0, p1));
                            da = std::stoi(str.substr(p1 + 1, p2 - p1 - 1));
                            y  = std::stoi(str.substr(p2 + 1));
                            parsed = true;
                        } catch (...) {}
                    }
                }

                if (!parsed) return CellError{"#VALUE!"};

                // Month & day name tables
                static const char* monthFull[] = {"","January","February","March","April","May","June",
                    "July","August","September","October","November","December"};
                static const char* monthShort[] = {"","Jan","Feb","Mar","Apr","May","Jun",
                    "Jul","Aug","Sep","Oct","Nov","Dec"};
                static const char* dayFull[] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};
                static const char* dayShort[] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};

                // Calculate day of week
                std::tm tmBuf = {};
                tmBuf.tm_year = y - 1900;
                tmBuf.tm_mon  = mo - 1;
                tmBuf.tm_mday = da;
                tmBuf.tm_hour = 12;
                std::mktime(&tmBuf);
                int wday = tmBuf.tm_wday; // 0=Sun

                // ── Token scanner ────────────────────────────────
                std::string result;
                size_t i = 0;
                bool afterHour = false;

                while (i < format.size()) {
                    char c = tolower(format[i]);

                    if (c == 'y') {
                        int cnt = 0;
                        while (i < format.size() && tolower(format[i]) == 'y') { cnt++; i++; }
                        char b[8];
                        if (cnt >= 4) { snprintf(b, sizeof(b), "%04d", y); }
                        else          { snprintf(b, sizeof(b), "%02d", y % 100); }
                        result += b;
                        afterHour = false;
                    }
                    else if (c == 'm') {
                        int cnt = 0;
                        while (i < format.size() && tolower(format[i]) == 'm') { cnt++; i++; }
                        if (afterHour) {
                            // Minutes
                            char b[8];
                            if (cnt >= 2) snprintf(b, sizeof(b), "%02d", mi);
                            else          snprintf(b, sizeof(b), "%d", mi);
                            result += b;
                            afterHour = false;
                        } else {
                            int safeMo = (mo >= 0 && mo <= 12) ? mo : 0;
                            if (cnt >= 5) result += monthFull[safeMo]; // mmmm+ → full name
                            else if (cnt == 4) result += monthFull[safeMo];
                            else if (cnt == 3) result += monthShort[safeMo];
                            else {
                                char b[8];
                                if (cnt == 2) snprintf(b, sizeof(b), "%02d", mo);
                                else          snprintf(b, sizeof(b), "%d", mo);
                                result += b;
                            }
                        }
                    }
                    else if (c == 'd') {
                        int cnt = 0;
                        while (i < format.size() && tolower(format[i]) == 'd') { cnt++; i++; }
                        int safeWday = (wday >= 0 && wday <= 6) ? wday : 0;
                        if (cnt >= 4)      result += dayFull[safeWday];
                        else if (cnt == 3) result += dayShort[safeWday];
                        else {
                            char b[8];
                            if (cnt == 2) snprintf(b, sizeof(b), "%02d", da);
                            else          snprintf(b, sizeof(b), "%d", da);
                            result += b;
                        }
                        afterHour = false;
                    }
                    else if (c == 'h') {
                        int cnt = 0;
                        while (i < format.size() && tolower(format[i]) == 'h') { cnt++; i++; }
                        char b[8];
                        if (cnt >= 2) snprintf(b, sizeof(b), "%02d", h);
                        else          snprintf(b, sizeof(b), "%d", h);
                        result += b;
                        afterHour = true;
                    }
                    else if (c == 's') {
                        int cnt = 0;
                        while (i < format.size() && tolower(format[i]) == 's') { cnt++; i++; }
                        char b[8];
                        if (cnt >= 2) snprintf(b, sizeof(b), "%02d", se);
                        else          snprintf(b, sizeof(b), "%d", se);
                        result += b;
                        afterHour = false;
                    }
                    else {
                        // Literal character (/, -, space, comma, colon, etc.)
                        result += format[i];
                        i++;
                    }
                }
                return result;
            }

            // ── Number formatting ────────────────────────────────
            double num = Evaluator::asNumber(cellVal);
            char buf[128];

            if (format.find('%') != std::string::npos) {
                // Count decimal places in format
                auto dotPos = format.find('.');
                int decimals = 2;
                if (dotPos != std::string::npos) {
                    decimals = 0;
                    for (size_t j = dotPos + 1; j < format.size() && (format[j] == '0' || format[j] == '#'); j++)
                        decimals++;
                }
                snprintf(buf, sizeof(buf), "%.*f%%", decimals, num * 100.0);
            }
            else if (fmtLower.find('#') != std::string::npos || fmtLower.find("0,") != std::string::npos ||
                     fmtLower.find(",0") != std::string::npos) {
                // Number with commas #,##0 or #,##0.00
                auto dotPos = format.find('.');
                int decimals = 0;
                if (dotPos != std::string::npos) {
                    for (size_t j = dotPos + 1; j < format.size() && (format[j] == '0' || format[j] == '#'); j++)
                        decimals++;
                }
                snprintf(buf, sizeof(buf), "%.*f", decimals, num);
                // Insert comma separators
                std::string s(buf);
                auto dp = s.find('.');
                std::string intPart = (dp != std::string::npos) ? s.substr(0, dp) : s;
                std::string decPart = (dp != std::string::npos) ? s.substr(dp) : "";
                bool neg = false;
                if (!intPart.empty() && intPart[0] == '-') { neg = true; intPart = intPart.substr(1); }
                std::string withComma;
                int count = 0;
                for (int j = (int)intPart.size() - 1; j >= 0; j--) {
                    if (count > 0 && count % 3 == 0) withComma = "," + withComma;
                    withComma = intPart[j] + withComma;
                    count++;
                }
                return std::string((neg ? "-" : "") + withComma + decPart);
            }
            else if (format.find('.') != std::string::npos) {
                // Count decimal places
                auto dotPos = format.find('.');
                int decimals = 0;
                for (size_t j = dotPos + 1; j < format.size() && (format[j] == '0' || format[j] == '#'); j++)
                    decimals++;
                if (decimals == 0) decimals = 2;
                snprintf(buf, sizeof(buf), "%.*f", decimals, num);
            }
            else {
                snprintf(buf, sizeof(buf), "%.0f", num);
            }
            return std::string(buf);
        };

        // ── Array vectorization ──────────────────────────────────
        if (std::holds_alternative<ArrayVal>(val)) {
            ArrayVal res;
            for (const auto& row : std::get<ArrayVal>(val).matrix) {
                std::vector<EvalResult> newRow;
                for (const auto& cell : row) {
                    newRow.push_back(formatOne(cell));
                }
                res.matrix.push_back(newRow);
            }
            return res;
        }

        return formatOne(val);
    });

    // SEARCH(find_text, within_text, [start_num])
    registerFunction("SEARCH", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto find_val = EVAL_ARG(eval, args, 0);
        auto within_val = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(find_val)) return find_val;
        if (Evaluator::isError(within_val)) return within_val;
        
        std::string find_text = Evaluator::asString(find_val);
        std::string within_text = Evaluator::asString(within_val);
        
        int start = 1;
        if (args.size() == 3) {
            auto start_val = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(start_val)) return start_val;
            start = (int)Evaluator::asNumber(start_val);
        }
        if (start < 1) return CellError{"#VALUE!"};
        
        std::string lower_find = find_text;
        std::string lower_within = within_text;
        std::transform(lower_find.begin(), lower_find.end(), lower_find.begin(), ::tolower);
        std::transform(lower_within.begin(), lower_within.end(), lower_within.begin(), ::tolower);
        
        size_t pos = lower_within.find(lower_find, start - 1);
        if (pos == std::string::npos) return CellError{"#VALUE!"};
        
        return (double)(pos + 1);
    });

    // REPLACE(old_text, start_num, num_chars, new_text)
    registerFunction("REPLACE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 4) return CellError{"#VALUE!"};
        auto old_val = EVAL_ARG(eval, args, 0);
        auto start_val = EVAL_ARG(eval, args, 1);
        auto num_val = EVAL_ARG(eval, args, 2);
        auto new_val = EVAL_ARG(eval, args, 3);
        
        if (Evaluator::isError(old_val)) return old_val;
        if (Evaluator::isError(start_val)) return start_val;
        if (Evaluator::isError(num_val)) return num_val;
        if (Evaluator::isError(new_val)) return new_val;
        
        std::string old_text = Evaluator::asString(old_val);
        int start = (int)Evaluator::asNumber(start_val);
        int num_chars = (int)Evaluator::asNumber(num_val);
        std::string new_text = Evaluator::asString(new_val);
        
        if (start < 1 || num_chars < 0) return CellError{"#VALUE!"};
        
        if (start > (int)old_text.length()) {
            return old_text + new_text;
        }
        
        std::string result = old_text;
        int max_replace = (int)old_text.length() - start + 1;
        if (num_chars > max_replace) {
            num_chars = max_replace;
        }
        
        result.replace(start - 1, num_chars, new_text);
        
        return result;
    });

    // PROPER(text)
    registerFunction("PROPER", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string text = Evaluator::asString(val);
        bool new_word = true;
        for (char& c : text) {
            if (std::isalpha(static_cast<unsigned char>(c))) {
                if (new_word) {
                    c = std::toupper(static_cast<unsigned char>(c));
                    new_word = false;
                } else {
                    c = std::tolower(static_cast<unsigned char>(c));
                }
            } else {
                new_word = true;
            }
        }
        return text;
    });

    // REPT(text, number_times)
    registerFunction("REPT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto text_val = EVAL_ARG(eval, args, 0);
        auto num_val = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(text_val)) return text_val;
        if (Evaluator::isError(num_val)) return num_val;
        
        std::string text = Evaluator::asString(text_val);
        int times = (int)Evaluator::asNumber(num_val);
        if (times < 0) return CellError{"#VALUE!"};
        
        std::string result;
        for (int i = 0; i < times; ++i) {
            result += text;
        }
        return result;
    });

    // CLEAN(text)
    registerFunction("CLEAN", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string text = Evaluator::asString(val);
        std::string result;
        for (char c : text) {
            if (static_cast<unsigned char>(c) >= 32) {
                result += c;
            }
        }
        return result;
    });

    // NUMBERVALUE(text, [decimal_separator], [group_separator])
    registerFunction("NUMBERVALUE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 3) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        std::string text = Evaluator::asString(val);
        std::string dec_sep = ".";
        std::string grp_sep = ",";
        
        if (args.size() >= 2) {
            auto ds_val = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(ds_val)) return ds_val;
            dec_sep = Evaluator::asString(ds_val);
        }
        if (args.size() == 3) {
            auto gs_val = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(gs_val)) return gs_val;
            grp_sep = Evaluator::asString(gs_val);
        }
        
        if (dec_sep.empty()) dec_sep = ".";
        if (grp_sep.empty()) grp_sep = ",";
        
        std::string clean_text;
        for (size_t i = 0; i < text.length(); ++i) {
            if (text.substr(i, grp_sep.length()) == grp_sep) {
                i += grp_sep.length() - 1;
                continue;
            }
            if (text.substr(i, dec_sep.length()) == dec_sep) {
                clean_text += '.';
                i += dec_sep.length() - 1;
                continue;
            }
            if (text[i] != ' ' && text[i] != '\t') {
                clean_text += text[i];
            }
        }
        
        try {
            if (clean_text.empty()) return 0.0;
            // Handle percentages
            if (clean_text.back() == '%') {
                clean_text.pop_back();
                return std::stod(clean_text) / 100.0;
            }
            return std::stod(clean_text);
        } catch (...) {
            return CellError{"#VALUE!"};
        }
    });

    // TEXTSPLIT(text, col_delimiter, [row_delimiter], [ignore_empty], [match_mode], [pad_with])
    registerFunction("TEXTSPLIT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 6) return CellError{"#VALUE!"};
        auto textVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(textVal)) return textVal;
        std::string str = Evaluator::asString(textVal);
        
        auto colDelimVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(colDelimVal)) return colDelimVal;
        std::string colDelim = Evaluator::asString(colDelimVal);
        
        std::string rowDelim = "";
        if (args.size() >= 3) {
            auto rVal = EVAL_ARG(eval, args, 2);
            if (!std::holds_alternative<Blank>(rVal)) rowDelim = Evaluator::asString(rVal);
        }
        
        bool ignoreEmpty = false;
        if (args.size() >= 4) {
            auto ieVal = EVAL_ARG(eval, args, 3);
            if (!std::holds_alternative<Blank>(ieVal)) ignoreEmpty = Evaluator::asBool(ieVal);
        }

        auto splitStr = [](const std::string& input, const std::string& delim, bool ign) -> std::vector<std::string> {
            std::vector<std::string> tokens;
            if (delim.empty()) {
                for (char c : input) tokens.push_back(std::string(1, c));
                return tokens;
            }
            size_t start = 0;
            size_t end = input.find(delim);
            while (end != std::string::npos) {
                std::string token = input.substr(start, end - start);
                if (!ign || !token.empty()) tokens.push_back(token);
                start = end + delim.length();
                end = input.find(delim, start);
            }
            std::string lastToken = input.substr(start);
            if (!ign || !lastToken.empty()) tokens.push_back(lastToken);
            return tokens;
        };

        ArrayVal res;
        if (!rowDelim.empty()) {
            std::vector<std::string> rowLines = splitStr(str, rowDelim, ignoreEmpty);
            size_t maxCols = 0;
            std::vector<std::vector<EvalResult>> grid;
            for (const auto& line : rowLines) {
                std::vector<std::string> cols = splitStr(line, colDelim, ignoreEmpty);
                maxCols = std::max(maxCols, cols.size());
                std::vector<EvalResult> row;
                for (const auto& c : cols) row.push_back(c);
                grid.push_back(row);
            }
            EvalResult padWith = CellError{"#N/A"};
            if (args.size() == 6) {
                auto pVal = EVAL_ARG(eval, args, 5);
                if (!std::holds_alternative<Blank>(pVal)) padWith = pVal;
            }
            for (auto& row : grid) {
                while (row.size() < maxCols) row.push_back(padWith);
                res.matrix.push_back(row);
            }
        } else {
            std::vector<std::string> cols = splitStr(str, colDelim, ignoreEmpty);
            std::vector<EvalResult> row;
            for (const auto& c : cols) row.push_back(c);
            res.matrix.push_back(row);
        }
        return res;
    });

    // TEXTBEFORE(text, delimiter, [instance_num])
    registerFunction("TEXTBEFORE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 6) return CellError{"#VALUE!"};
        auto textVal = EVAL_ARG(eval, args, 0);
        auto delimVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(textVal)) return textVal;
        if (Evaluator::isError(delimVal)) return delimVal;
        
        std::string str = Evaluator::asString(textVal);
        std::string delim = Evaluator::asString(delimVal);
        
        int instanceNum = 1;
        if (args.size() >= 3) {
            auto iVal = EVAL_ARG(eval, args, 2);
            if (!std::holds_alternative<Blank>(iVal)) instanceNum = (int)Evaluator::asNumber(iVal);
        }
        
        if (delim.empty()) return "";
        
        size_t pos = 0;
        int found = 0;
        while ((pos = str.find(delim, pos)) != std::string::npos) {
            found++;
            if (found == instanceNum) {
                return str.substr(0, pos);
            }
            pos += delim.length();
        }
        return CellError{"#N/A"};
    });

    // TEXTAFTER(text, delimiter, [instance_num])
    registerFunction("TEXTAFTER", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 6) return CellError{"#VALUE!"};
        auto textVal = EVAL_ARG(eval, args, 0);
        auto delimVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(textVal)) return textVal;
        if (Evaluator::isError(delimVal)) return delimVal;
        
        std::string str = Evaluator::asString(textVal);
        std::string delim = Evaluator::asString(delimVal);
        
        int instanceNum = 1;
        if (args.size() >= 3) {
            auto iVal = EVAL_ARG(eval, args, 2);
            if (!std::holds_alternative<Blank>(iVal)) instanceNum = (int)Evaluator::asNumber(iVal);
        }
        
        if (delim.empty()) return str;
        
        size_t pos = 0;
        int found = 0;
        while ((pos = str.find(delim, pos)) != std::string::npos) {
            found++;
            if (found == instanceNum) {
                return str.substr(pos + delim.length());
            }
            pos += delim.length();
        }
        return CellError{"#N/A"};
    });

    // ARRAYTOTEXT(array, [format])
    registerFunction("ARRAYTOTEXT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto arrVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(arrVal)) return arrVal;
        
        int format = 0; // 0=concise, 1=strict
        if (args.size() == 2) {
            auto fVal = EVAL_ARG(eval, args, 1);
            if (!std::holds_alternative<Blank>(fVal)) format = (int)Evaluator::asNumber(fVal);
        }
        
        auto mat = std::holds_alternative<ArrayVal>(arrVal) 
                   ? std::get<ArrayVal>(arrVal).matrix 
                   : std::vector<std::vector<EvalResult>>{{arrVal}};
                   
        std::string result;
        if (format == 1) result += "{";
        for (size_t r = 0; r < mat.size(); r++) {
            if (r > 0) result += (format == 1 ? ";" : ", ");
            for (size_t c = 0; c < mat[r].size(); c++) {
                if (c > 0) result += (format == 1 ? "," : ", ");
                if (format == 1 && std::holds_alternative<std::string>(mat[r][c])) {
                    result += "\"" + std::get<std::string>(mat[r][c]) + "\"";
                } else {
                    result += Evaluator::asString(mat[r][c]);
                }
            }
        }
        if (format == 1) result += "}";
        return result;
    });

    // VALUETOTEXT(value, [format])
    registerFunction("VALUETOTEXT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.empty() || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        int format = 0;
        if (args.size() == 2) {
            auto fVal = EVAL_ARG(eval, args, 1);
            if (!std::holds_alternative<Blank>(fVal)) format = (int)Evaluator::asNumber(fVal);
        }
        
        if (format == 1 && std::holds_alternative<std::string>(val)) {
            return "\"" + std::get<std::string>(val) + "\"";
        }
        return Evaluator::asString(val);
    });
}

