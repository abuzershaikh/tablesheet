#include "../function_registry.h"
#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <regex>
#include <algorithm>
#include <cmath>
#include <set>

// Correct Excel epoch: January 1, 1900 (Excel treats 1900 as leap year)
// Excel day 1 = January 1, 1900
const double EXCEL_EPOCH_DAYS = 25569.0; // Days between Jan 1, 1900 and Jan 1, 1970

static bool isLeapYear(int year) {
    // Excel compatibility: treats 1900 as leap year (Excel bug)
    if (year == 1900) return true;
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

static bool isValidDate(int year, int month, int day) {
    if (year < 1 || month < 1 || month > 12 || day < 1) return false;
    
    static const int daysInMonth[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    int maxDays = daysInMonth[month];
    
    if (month == 2 && isLeapYear(year)) {
        maxDays = 29;
    }
    
    return day <= maxDays;
}

static double dateToExcelSerial(int year, int month, int day) {
    if (year == 1900 && month == 2 && day == 29) return 60.0;
    int m = month;
    int y = year;
    if (m <= 2) { y -= 1; m += 12; }
    int j = 365 * y + y / 4 - y / 100 + y / 400 + (153 * m - 457) / 5 + day - 306;
    double serial = j - 693595.0; // 1899-12-31 is 693595
    if (serial > 59.0) serial += 1.0; // Day 60 is handled explicitly above
    return serial;
}

static bool excelSerialToDate(double serial, int& year, int& month, int& day) {
    if (serial < 0.0) return false;
    if ((int)serial == 60) { year = 1900; month = 2; day = 29; return true; }
    double adjustedSerial = serial;
    if (serial >= 61.0) adjustedSerial -= 1.0;
    int j = (int)adjustedSerial + 2415020;
    int l = j + 68569;
    int n = 4 * l / 146097;
    l = l - (146097 * n + 3) / 4;
    int i = 4000 * (l + 1) / 1461001;
    l = l - 1461 * i / 4 + 31;
    int k = 80 * l / 2447;
    day = l - 2447 * k / 80;
    l = k / 11;
    month = k + 2 - 12 * l;
    year = 100 * (n - 49) + i + l;
    return true;
}

static bool parseMultipleFormats(const EvalResult& val, int& outY, int& outM, int& outD) {
    if (Evaluator::isError(val)) return false;
    
    // CRITICAL FIX: Try numeric serial number FIRST before string parsing
    if (std::holds_alternative<double>(val)) {
        double serial = std::get<double>(val);
        if (serial >= 1.0 && serial <= 2958465.0) { // Valid Excel date range
            return excelSerialToDate(serial, outY, outM, outD);
        }
    }
    
    // Now try string formats
    std::string str = Evaluator::asString(val);
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    
    // Try different date formats
    std::smatch match;
    
    static const std::regex isoRe(R"((\d{4})-(\d{1,2})-(\d{1,2}))");
    static const std::regex slashRe(R"((\d{1,2})/(\d{1,2})/(\d{2,4}))");
    static const std::regex dashRe(R"((\d{1,2})-(\d{1,2})-(\d{2,4}))");
    
    auto parseYear = [](int y) {
        if (y >= 0 && y <= 29) return y + 2000;
        if (y >= 30 && y <= 99) return y + 1900;
        return y;
    };
    
    // 1. YYYY-MM-DD format (ISO 8601)
    if (std::regex_match(str, match, isoRe)) {
        outY = std::stoi(match[1].str());
        outM = std::stoi(match[2].str());
        outD = std::stoi(match[3].str());
        return isValidDate(outY, outM, outD);
    }
    
    // 2. DD/MM/YYYY or MM/DD/YYYY format (Auto-detect based on validity)
    if (std::regex_match(str, match, slashRe)) {
        int first = std::stoi(match[1].str());
        int second = std::stoi(match[2].str());
        outY = parseYear(std::stoi(match[3].str()));
        
        if (first > 12) { // Must be DD/MM
            outD = first;
            outM = second;
        } else if (second > 12) { // Must be MM/DD
            outM = first;
            outD = second;
        } else { // Ambiguous - default to MM/DD for US compatibility
            outM = first;
            outD = second;
        }
        return isValidDate(outY, outM, outD);
    }
    
    // 4. DD-MM-YYYY or MM-DD-YYYY format (Auto-detect based on validity)
    if (std::regex_match(str, match, dashRe)) {
        int first = std::stoi(match[1].str());
        int second = std::stoi(match[2].str());
        outY = parseYear(std::stoi(match[3].str()));
        
        if (first > 12) { // Must be DD/MM
            outD = first;
            outM = second;
        } else if (second > 12) { // Must be MM/DD
            outM = first;
            outD = second;
        } else { // Ambiguous - default to MM/DD for US compatibility
            outM = first;
            outD = second;
        }
        return isValidDate(outY, outM, outD);
    }
    return false;
}

// Helper array for days in months
static const int cumDays[] = {0,0,31,59,90,120,151,181,212,243,273,304,334};

// --- Array Vectorization Helpers ---
static EvalResult vectorizeUnary(const EvalResult& arg, std::function<EvalResult(const EvalResult&)> func) {
    if (std::holds_alternative<ArrayVal>(arg)) {
        ArrayVal res;
        for (const auto& row : std::get<ArrayVal>(arg).matrix) {
            std::vector<EvalResult> newRow;
            for (const auto& cell : row) {
                newRow.push_back(func(cell));
            }
            res.matrix.push_back(newRow);
        }
        return res;
    }
    return func(arg);
}

static EvalResult vectorizeBinary(const EvalResult& arg1, const EvalResult& arg2, std::function<EvalResult(const EvalResult&, const EvalResult&)> func) {
    bool isArr1 = std::holds_alternative<ArrayVal>(arg1);
    bool isArr2 = std::holds_alternative<ArrayVal>(arg2);
    
    if (!isArr1 && !isArr2) return func(arg1, arg2);
    
    const ArrayVal* a1 = isArr1 ? &std::get<ArrayVal>(arg1) : nullptr;
    const ArrayVal* a2 = isArr2 ? &std::get<ArrayVal>(arg2) : nullptr;
    
    size_t rows = std::max(a1 ? a1->matrix.size() : 1, a2 ? a2->matrix.size() : 1);
    size_t cols = 0;
    if (a1 && a1->matrix.size() > 0) cols = std::max(cols, a1->matrix[0].size());
    if (a2 && a2->matrix.size() > 0) cols = std::max(cols, a2->matrix[0].size());
    if (cols == 0) cols = 1;

    if (a1) {
        if (a1->matrix.size() != 1 && a1->matrix.size() != rows) return CellError{"#VALUE!"};
        if (a1->matrix[0].size() != 1 && a1->matrix[0].size() != cols) return CellError{"#VALUE!"};
    }
    if (a2) {
        if (a2->matrix.size() != 1 && a2->matrix.size() != rows) return CellError{"#VALUE!"};
        if (a2->matrix[0].size() != 1 && a2->matrix[0].size() != cols) return CellError{"#VALUE!"};
    }

    ArrayVal res;
    for (size_t r = 0; r < rows; ++r) {
        std::vector<EvalResult> newRow;
        for (size_t c = 0; c < cols; ++c) {
            EvalResult v1 = arg1;
            if (a1) v1 = a1->matrix[std::min(r, a1->matrix.size() - 1)][std::min(c, a1->matrix[0].size() - 1)];
            EvalResult v2 = arg2;
            if (a2) v2 = a2->matrix[std::min(r, a2->matrix.size() - 1)][std::min(c, a2->matrix[0].size() - 1)];
            newRow.push_back(func(v1, v2));
        }
        res.matrix.push_back(newRow);
    }
    return res;
}

static EvalResult vectorizeTernary(const EvalResult& arg1, const EvalResult& arg2, const EvalResult& arg3, std::function<EvalResult(const EvalResult&, const EvalResult&, const EvalResult&)> func) {
    bool isArr1 = std::holds_alternative<ArrayVal>(arg1);
    bool isArr2 = std::holds_alternative<ArrayVal>(arg2);
    bool isArr3 = std::holds_alternative<ArrayVal>(arg3);
    
    if (!isArr1 && !isArr2 && !isArr3) return func(arg1, arg2, arg3);
    
    const ArrayVal* a1 = isArr1 ? &std::get<ArrayVal>(arg1) : nullptr;
    const ArrayVal* a2 = isArr2 ? &std::get<ArrayVal>(arg2) : nullptr;
    const ArrayVal* a3 = isArr3 ? &std::get<ArrayVal>(arg3) : nullptr;
    
    size_t rows = 1, cols = 1;
    if (a1) { rows = std::max(rows, a1->matrix.size()); if(a1->matrix.size()>0) cols = std::max(cols, a1->matrix[0].size()); }
    if (a2) { rows = std::max(rows, a2->matrix.size()); if(a2->matrix.size()>0) cols = std::max(cols, a2->matrix[0].size()); }
    if (a3) { rows = std::max(rows, a3->matrix.size()); if(a3->matrix.size()>0) cols = std::max(cols, a3->matrix[0].size()); }

    if (a1) { if (a1->matrix.size() != 1 && a1->matrix.size() != rows) return CellError{"#VALUE!"}; if (a1->matrix[0].size() != 1 && a1->matrix[0].size() != cols) return CellError{"#VALUE!"}; }
    if (a2) { if (a2->matrix.size() != 1 && a2->matrix.size() != rows) return CellError{"#VALUE!"}; if (a2->matrix[0].size() != 1 && a2->matrix[0].size() != cols) return CellError{"#VALUE!"}; }
    if (a3) { if (a3->matrix.size() != 1 && a3->matrix.size() != rows) return CellError{"#VALUE!"}; if (a3->matrix[0].size() != 1 && a3->matrix[0].size() != cols) return CellError{"#VALUE!"}; }

    ArrayVal res;
    for (size_t r = 0; r < rows; ++r) {
        std::vector<EvalResult> newRow;
        for (size_t c = 0; c < cols; ++c) {
            EvalResult v1 = arg1;
            if (a1) v1 = a1->matrix[std::min(r, a1->matrix.size() - 1)][std::min(c, a1->matrix[0].size() - 1)];
            EvalResult v2 = arg2;
            if (a2) v2 = a2->matrix[std::min(r, a2->matrix.size() - 1)][std::min(c, a2->matrix[0].size() - 1)];
            EvalResult v3 = arg3;
            if (a3) v3 = a3->matrix[std::min(r, a3->matrix.size() - 1)][std::min(c, a3->matrix[0].size() - 1)];
            newRow.push_back(func(v1, v2, v3));
        }
        res.matrix.push_back(newRow);
    }
    return res;
}

static bool parseDateOrSerial(const EvalResult& val, int& outY, int& outM, int& outD) {
    return parseMultipleFormats(val, outY, outM, outD);
}

void FunctionRegistry::registerDateFunctions() {
    
    // TODAY()
    registerFunction("TODAY", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (!args.empty()) return CellError{"#VALUE!"};
        auto now = std::chrono::system_clock::now();
        std::time_t now_c = std::chrono::system_clock::to_time_t(now);
        std::tm tm_buf = {0};
#ifdef _WIN32
        localtime_s(&tm_buf, &now_c);
#else
        localtime_r(&now_c, &tm_buf);
#endif
        std::tm* tm = &tm_buf;
        return dateToExcelSerial(tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday);
    });

    // NOW()
    registerFunction("NOW", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (!args.empty()) return CellError{"#VALUE!"};
        auto now = std::chrono::system_clock::now();
        std::time_t now_c = std::chrono::system_clock::to_time_t(now);
        std::tm tm_buf = {0};
#ifdef _WIN32
        localtime_s(&tm_buf, &now_c);
#else
        localtime_r(&now_c, &tm_buf);
#endif
        std::tm* tm = &tm_buf;
        double serial = dateToExcelSerial(tm->tm_year + 1900, tm->tm_mon + 1, tm->tm_mday);
        double fraction = (tm->tm_hour * 3600 + tm->tm_min * 60 + tm->tm_sec) / 86400.0;
        return serial + fraction;
    });

    // DATE(year, month, day)
    registerFunction("DATE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto y_val = EVAL_ARG(eval, args, 0);
        auto m_val = EVAL_ARG(eval, args, 1);
        auto d_val = EVAL_ARG(eval, args, 2);
        
        if (Evaluator::isError(y_val)) return y_val;
        if (Evaluator::isError(m_val)) return m_val;
        if (Evaluator::isError(d_val)) return d_val;

        return vectorizeTernary(y_val, m_val, d_val, [](const EvalResult& yVal, const EvalResult& mVal, const EvalResult& dVal) -> EvalResult {
            if (Evaluator::isError(yVal)) return yVal;
            if (Evaluator::isError(mVal)) return mVal;
            if (Evaluator::isError(dVal)) return dVal;
            
            int y = (int)Evaluator::asNumber(yVal);
            int m = (int)Evaluator::asNumber(mVal);
            int d = (int)Evaluator::asNumber(dVal);
            
            if (y >= 0 && y <= 29) y += 2000;
            else if (y >= 30 && y <= 99) y += 1900;
            
            int m_adj = (m - 1) % 12;
            int y_adj = (m - 1) / 12;
            if (m_adj < 0) {
                m_adj += 12;
                y_adj -= 1;
            }
            m = m_adj + 1;
            y += y_adj;
            
            return dateToExcelSerial(y, m, d);
        });
    });

    // TIME(hour, minute, second) - FIXED: Returns numeric fraction, handles overflow
    registerFunction("TIME", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto h_val = EVAL_ARG(eval, args, 0);
        auto m_val = EVAL_ARG(eval, args, 1);
        auto s_val = EVAL_ARG(eval, args, 2);
        
        if (Evaluator::isError(h_val)) return h_val;
        if (Evaluator::isError(m_val)) return m_val;
        if (Evaluator::isError(s_val)) return s_val;

        return vectorizeTernary(h_val, m_val, s_val, [](const EvalResult& hVal, const EvalResult& mVal, const EvalResult& sVal) -> EvalResult {
            if (Evaluator::isError(hVal)) return hVal;
            if (Evaluator::isError(mVal)) return mVal;
            if (Evaluator::isError(sVal)) return sVal;
            
            int h = (int)Evaluator::asNumber(hVal);
            int m = (int)Evaluator::asNumber(mVal);
            int s = (int)Evaluator::asNumber(sVal);
            
            long long totalSeconds = (long long)h * 3600 + (long long)m * 60 + s;
            
            long long normalizedSeconds = totalSeconds % 86400;
            if (normalizedSeconds < 0) {
                normalizedSeconds += 86400;
            }
            return (double)normalizedSeconds / 86400.0;
        });
    });

    // HOUR(time) - FIXED: Supports both serial numbers and time strings
    registerFunction("HOUR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;

        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            if (Evaluator::isError(v)) return v;
            
            if (std::holds_alternative<double>(v)) {
                double serial = std::get<double>(v);
                double timeFraction = serial - std::floor(serial);
                long long totalSec = std::llround(timeFraction * 86400.0);
                int hour = (int)(totalSec / 3600);
                return (double)(hour % 24);
            }
            
            std::string timeStr = Evaluator::asString(v);
            std::smatch match;
            
            static const std::regex timeRe(R"(^(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*(AM|PM|am|pm)?$)");
            if (std::regex_match(timeStr, match, timeRe)) {
                int hour = std::stoi(match[1].str());
                std::string ampm = match[4].matched ? match[4].str() : "";
                std::transform(ampm.begin(), ampm.end(), ampm.begin(), ::toupper);
                if (ampm == "PM" && hour < 12) hour += 12;
                if (ampm == "AM" && hour == 12) hour = 0;
                return (double)hour;
            }
            
            return CellError{"#VALUE!"};
        });
    });

    // MINUTE(time) - FIXED: Supports both serial numbers and time strings
    registerFunction("MINUTE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;

        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            if (Evaluator::isError(v)) return v;
            
            if (std::holds_alternative<double>(v)) {
                double serial = std::get<double>(v);
                double timeFraction = serial - std::floor(serial);
                long long totalSec = std::llround(timeFraction * 86400.0);
                int minute = (int)((totalSec % 3600) / 60);
                return (double)minute;
            }
            
            std::string timeStr = Evaluator::asString(v);
            std::smatch match;
            
            static const std::regex timeRe(R"(^(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*(AM|PM|am|pm)?$)");
            if (std::regex_match(timeStr, match, timeRe)) {
                int minute = match[2].matched ? std::stoi(match[2].str()) : 0;
                return (double)minute;
            }
            
            return CellError{"#VALUE!"};
        });
    });

    // SECOND(time) - FIXED: Supports both serial numbers and time strings
    registerFunction("SECOND", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;

        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            if (Evaluator::isError(v)) return v;
            
            if (std::holds_alternative<double>(v)) {
                double serial = std::get<double>(v);
                double timeFraction = serial - std::floor(serial);
                long long totalSec = std::llround(timeFraction * 86400.0);
                int second = (int)(totalSec % 60);
                return (double)second;
            }
            
            std::string timeStr = Evaluator::asString(v);
            std::smatch match;
            
            static const std::regex timeRe(R"(^(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*(AM|PM|am|pm)?$)");
            if (std::regex_match(timeStr, match, timeRe)) {
                int second = match[3].matched ? std::stoi(match[3].str()) : 0;
                return (double)second;
            }
            
            return CellError{"#VALUE!"};
        });
    });

    // WEEKDAY(date, [type]) - FIXED: Supports types 1-3 and 11-17
    registerFunction("WEEKDAY", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 1 || args.size() > 2) return CellError{"#VALUE!"};
        auto dateVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(dateVal)) return dateVal;
        
        EvalResult typeVal = (double)1.0;
        if (args.size() == 2) {
            typeVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(typeVal)) return typeVal;
        }

        return vectorizeBinary(dateVal, typeVal, [](const EvalResult& dVal, const EvalResult& tVal) -> EvalResult {
            if (Evaluator::isError(dVal)) return dVal;
            if (Evaluator::isError(tVal)) return tVal;
            
            int y, m, d;
            if (!parseDateOrSerial(dVal, y, m, d)) return CellError{"#VALUE!"};
            int return_type = (int)Evaluator::asNumber(tVal);
            double serial = dateToExcelSerial(y, m, d);
            int standardWeekday = (int)(std::floor(serial) + 6) % 7;
            
            switch (return_type) {
                case 1:  return (double)(standardWeekday + 1);
                case 2:  return (double)((standardWeekday == 0) ? 7 : standardWeekday);
                case 3:  return (double)((standardWeekday == 0) ? 6 : standardWeekday - 1);
                case 11: return (double)((standardWeekday == 0) ? 7 : standardWeekday);
                case 12: return (double)((standardWeekday < 2) ? standardWeekday + 6 : standardWeekday - 1);
                case 13: return (double)((standardWeekday < 3) ? standardWeekday + 5 : standardWeekday - 2);
                case 14: return (double)((standardWeekday < 4) ? standardWeekday + 4 : standardWeekday - 3);
                case 15: return (double)((standardWeekday < 5) ? standardWeekday + 3 : standardWeekday - 4);
                case 16: return (double)((standardWeekday < 6) ? standardWeekday + 2 : standardWeekday - 5);
                case 17: return (double)(standardWeekday + 1);
                default: return CellError{"#NUM!"};
            }
        });
    });

    // DATEVALUE(text) - Convert text to serial number
    registerFunction("DATEVALUE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            int y, m, d;
            if (!parseDateOrSerial(v, y, m, d)) return CellError{"#VALUE!"};
            return dateToExcelSerial(y, m, d);
        });
    });

    // YEAR(date)
    registerFunction("YEAR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            int y, m, d;
            if (!parseDateOrSerial(v, y, m, d)) return CellError{"#VALUE!"};
            return (double)y;
        });
    });

    // MONTH(date)
    registerFunction("MONTH", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            int y, m, d;
            if (!parseDateOrSerial(v, y, m, d)) return CellError{"#VALUE!"};
            return (double)m;
        });
    });

    // DAY(date)
    registerFunction("DAY", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            int y, m, d;
            if (!parseDateOrSerial(v, y, m, d)) return CellError{"#VALUE!"};
            return (double)d;
        });
    });

    // DATEDIF(start_date, end_date, unit) - Fixed calculation
    registerFunction("DATEDIF", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 3) return CellError{"#VALUE!"};
        auto d1Val = EVAL_ARG(eval, args, 0);
        auto d2Val = EVAL_ARG(eval, args, 1);
        auto uVal = EVAL_ARG(eval, args, 2);
        if (Evaluator::isError(d1Val)) return d1Val;
        if (Evaluator::isError(d2Val)) return d2Val;
        if (Evaluator::isError(uVal)) return uVal;

        int y1, m1, day1, y2, m2, day2;
        if (!parseDateOrSerial(d1Val, y1, m1, day1)) return CellError{"#VALUE!"};
        if (!parseDateOrSerial(d2Val, y2, m2, day2)) return CellError{"#VALUE!"};

        // Ensure start date is before end date
        if (y1 > y2 || (y1 == y2 && m1 > m2) || (y1 == y2 && m1 == m2 && day1 > day2)) {
            return CellError{"#NUM!"};
        }

        std::string unit = Evaluator::asString(uVal);
        for (char& c : unit) c = toupper(c);

        if (unit == "Y") {
            // Years
            int years = y2 - y1;
            if (m2 < m1 || (m2 == m1 && day2 < day1)) {
                years--;
            }
            return (double)years;
        } 
        else if (unit == "M") {
            // Total months
            int months = (y2 - y1) * 12 + (m2 - m1);
            if (day2 < day1) {
                months--;
            }
            return (double)months;
        }
        else if (unit == "YM") {
            // Months ignoring years
            int months = m2 - m1;
            if (day2 < day1) {
                months--;
            }
            if (months < 0) {
                months += 12;
            }
            return (double)months;
        }
        else if (unit == "D") {
            // Total days - use proper date calculation
            double serial1 = dateToExcelSerial(y1, m1, day1);
            double serial2 = dateToExcelSerial(y2, m2, day2);
            return serial2 - serial1;
        }
        else if (unit == "MD") {
            // Days ignoring months and years
            if (day2 >= day1) {
                return (double)(day2 - day1);
            } else {
                // Get days in previous month
                int prevMonth = m2 - 1;
                int prevYear = y2;
                if (prevMonth == 0) {
                    prevMonth = 12;
                    prevYear--;
                }
                
                static const int daysInMonth[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
                int daysInPrevMonth = daysInMonth[prevMonth];
                if (prevMonth == 2 && isLeapYear(prevYear)) {
                    daysInPrevMonth = 29;
                }
                
                return (double)(daysInPrevMonth - day1 + day2);
            }
        }
        else if (unit == "YD") {
            // Days ignoring years
            int d1_adj = day1;
            if (m1 == 2 && day1 == 29 && !isLeapYear(y2)) d1_adj = 28;
            double s1 = dateToExcelSerial(y2, m1, d1_adj);
            double s2 = dateToExcelSerial(y2, m2, day2);
            if (s2 < s1) {
                // Wrap around to next year (only for end date)
                int d1_adj2 = day1;
                if (m1 == 2 && day1 == 29 && !isLeapYear(y2)) d1_adj2 = 28;
                s1 = dateToExcelSerial(y2, m1, d1_adj2);
                s2 = dateToExcelSerial(y2 + 1, m2, day2);
            }
            return s2 - s1;
        }

        return CellError{"#VALUE!"};
    });

    // Helper for EDATE - FIXED: Returns serial number instead of string
    auto calcEdate = [](const EvalResult& dateVal, int monthsOffset) -> EvalResult {
        int curYear, curMonth, curDay;
        if (!parseDateOrSerial(dateVal, curYear, curMonth, curDay)) return CellError{"#VALUE!"};

        int totalMonths = (curYear * 12 + (curMonth - 1)) + monthsOffset;
        int targetYear = totalMonths / 12;
        int targetMonth = (totalMonths % 12) + 1;
        
        // Handle negative months
        while (targetMonth <= 0) {
            targetMonth += 12;
            targetYear--;
        }
        
        // Handle month > 12
        while (targetMonth > 12) {
            targetMonth -= 12;
            targetYear++;
        }

        // Get days in target month
        static const int daysInMonth[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        int maxDays = daysInMonth[targetMonth];
        if (targetMonth == 2 && isLeapYear(targetYear)) {
            maxDays = 29;
        }

        // Adjust day if it exceeds month length
        int targetDay = std::min(curDay, maxDays);
        
        if (!isValidDate(targetYear, targetMonth, targetDay)) {
            return CellError{"#VALUE!"};
        }
        
        // Return serial number, not formatted string
        return dateToExcelSerial(targetYear, targetMonth, targetDay);
    };

    // Helper for EOMONTH - FIXED: Returns serial number instead of string
    auto calcEomonth = [](const EvalResult& dateVal, int monthsOffset) -> EvalResult {
        int curYear, curMonth, curDay;
        if (!parseDateOrSerial(dateVal, curYear, curMonth, curDay)) return CellError{"#VALUE!"};

        int totalMonths = (curYear * 12 + (curMonth - 1)) + monthsOffset;
        int targetYear = totalMonths / 12;
        int targetMonth = (totalMonths % 12) + 1;
        
        // Handle negative months
        while (targetMonth <= 0) {
            targetMonth += 12;
            targetYear--;
        }
        
        // Handle month > 12
        while (targetMonth > 12) {
            targetMonth -= 12;
            targetYear++;
        }

        // Get last day of target month
        static const int daysInMonth[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        int lastDay = daysInMonth[targetMonth];
        if (targetMonth == 2 && isLeapYear(targetYear)) {
            lastDay = 29;
        }

        // Return serial number, not formatted string
        return dateToExcelSerial(targetYear, targetMonth, lastDay);
    };

    // EDATE(start_date, months)
    registerFunction("EDATE", [calcEdate](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto dVal = EVAL_ARG(eval, args, 0);
        auto mVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(dVal)) return dVal;
        if (Evaluator::isError(mVal)) return mVal;

        bool dArr = std::holds_alternative<ArrayVal>(dVal);
        bool mArr = std::holds_alternative<ArrayVal>(mVal);

        if (dArr || mArr) {
            const ArrayVal* ref = dArr ? &std::get<ArrayVal>(dVal) : &std::get<ArrayVal>(mVal);
            ArrayVal res;
            for (size_t r = 0; r < ref->matrix.size(); r++) {
                std::vector<EvalResult> newRow;
                for (size_t c = 0; c < ref->matrix[r].size(); c++) {
                    EvalResult dCell = dArr ? (r < std::get<ArrayVal>(dVal).matrix.size() && c < std::get<ArrayVal>(dVal).matrix[r].size() ? std::get<ArrayVal>(dVal).matrix[r][c] : EvalResult(0.0)) : dVal;
                    EvalResult mCell = mArr ? (r < std::get<ArrayVal>(mVal).matrix.size() && c < std::get<ArrayVal>(mVal).matrix[r].size() ? std::get<ArrayVal>(mVal).matrix[r][c] : EvalResult(0.0)) : mVal;
                    if (Evaluator::isError(dCell)) newRow.push_back(dCell);
                    else if (Evaluator::isError(mCell)) newRow.push_back(mCell);
                    else newRow.push_back(calcEdate(dCell, (int)Evaluator::asNumber(mCell)));
                }
                res.matrix.push_back(newRow);
            }
            return res;
        }

        int mOff = (int)Evaluator::asNumber(mVal);
        return calcEdate(dVal, mOff);
    });

    // EOMONTH(start_date, months)
    registerFunction("EOMONTH", [calcEomonth](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto dVal = EVAL_ARG(eval, args, 0);
        auto mVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(dVal)) return dVal;
        if (Evaluator::isError(mVal)) return mVal;

        bool dArr = std::holds_alternative<ArrayVal>(dVal);
        bool mArr = std::holds_alternative<ArrayVal>(mVal);

        if (dArr || mArr) {
            const ArrayVal* ref = dArr ? &std::get<ArrayVal>(dVal) : &std::get<ArrayVal>(mVal);
            ArrayVal res;
            for (size_t r = 0; r < ref->matrix.size(); r++) {
                std::vector<EvalResult> newRow;
                for (size_t c = 0; c < ref->matrix[r].size(); c++) {
                    EvalResult dCell = dArr ? (r < std::get<ArrayVal>(dVal).matrix.size() && c < std::get<ArrayVal>(dVal).matrix[r].size() ? std::get<ArrayVal>(dVal).matrix[r][c] : EvalResult(0.0)) : dVal;
                    EvalResult mCell = mArr ? (r < std::get<ArrayVal>(mVal).matrix.size() && c < std::get<ArrayVal>(mVal).matrix[r].size() ? std::get<ArrayVal>(mVal).matrix[r][c] : EvalResult(0.0)) : mVal;
                    if (Evaluator::isError(dCell)) newRow.push_back(dCell);
                    else if (Evaluator::isError(mCell)) newRow.push_back(mCell);
                    else newRow.push_back(calcEomonth(dCell, (int)Evaluator::asNumber(mCell)));
                }
                res.matrix.push_back(newRow);
            }
            return res;
        }

        int mOff = (int)Evaluator::asNumber(mVal);
        return calcEomonth(dVal, mOff);
    });

    // DAYS(end_date, start_date)
    registerFunction("DAYS", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto endVal = EVAL_ARG(eval, args, 0);
        auto startVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(endVal)) return endVal;
        if (Evaluator::isError(startVal)) return startVal;

        int y1, m1, d1, y2, m2, d2;
        if (!parseDateOrSerial(endVal, y2, m2, d2)) return CellError{"#VALUE!"};
        if (!parseDateOrSerial(startVal, y1, m1, d1)) return CellError{"#VALUE!"};

        double serial1 = dateToExcelSerial(y1, m1, d1);
        double serial2 = dateToExcelSerial(y2, m2, d2);
        return serial2 - serial1;
    });

    // DAYS360(start_date, end_date, [method])
    registerFunction("DAYS360", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto startVal = EVAL_ARG(eval, args, 0);
        auto endVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(startVal)) return startVal;
        if (Evaluator::isError(endVal)) return endVal;

        bool european = false;
        if (args.size() == 3) {
            auto methVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(methVal)) return methVal;
            european = Evaluator::asBool(methVal);
        }

        int y1, m1, d1, y2, m2, d2;
        if (!parseDateOrSerial(startVal, y1, m1, d1)) return CellError{"#VALUE!"};
        if (!parseDateOrSerial(endVal, y2, m2, d2)) return CellError{"#VALUE!"};

        if (european) {
            if (d1 == 31) d1 = 30;
            if (d2 == 31) d2 = 30;
        } else {
            // US/NASD method
            static const int daysInMon[] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
            int maxD1 = daysInMon[m1]; if (m1==2 && isLeapYear(y1)) maxD1=29;
            if (d1 == maxD1) d1 = 30;
            if (d1 == 30 && d2 == 31) d2 = 30;
        }

        return (double)((y2 - y1) * 360 + (m2 - m1) * 30 + (d2 - d1));
    });

    // WEEKNUM(date, [return_type])
    registerFunction("WEEKNUM", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 1 || args.size() > 2) return CellError{"#VALUE!"};
        auto dateVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(dateVal)) return dateVal;
        
        EvalResult typeVal = (double)1.0;
        if (args.size() == 2) {
            typeVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(typeVal)) return typeVal;
        }

        return vectorizeBinary(dateVal, typeVal, [](const EvalResult& dVal, const EvalResult& tVal) -> EvalResult {
            if (Evaluator::isError(dVal)) return dVal;
            if (Evaluator::isError(tVal)) return tVal;

            int y, m, d;
            if (!parseDateOrSerial(dVal, y, m, d)) return CellError{"#VALUE!"};
            int return_type = (int)Evaluator::asNumber(tVal);
            double serial = dateToExcelSerial(y, m, d);

            switch (return_type) {
                case 1:
                case 2:
                case 11:
                case 12:
                case 13:
                case 14:
                case 15:
                case 16:
                case 17: {
                    double jan1 = dateToExcelSerial(y, 1, 1);
                    int startWday = (int)(std::floor(jan1) + 6) % 7;
                    int startOffset = 0;
                    
                    if (return_type == 1 || return_type == 17) startOffset = (7 - startWday) % 7;
                    else if (return_type == 2 || return_type == 11) startOffset = (7 - ((startWday == 0) ? 7 : startWday) + 1) % 7;
                    else if (return_type == 12) startOffset = (7 - ((startWday < 2) ? startWday + 6 : startWday - 1) + 1) % 7;
                    else if (return_type == 13) startOffset = (7 - ((startWday < 3) ? startWday + 5 : startWday - 2) + 1) % 7;
                    else if (return_type == 14) startOffset = (7 - ((startWday < 4) ? startWday + 4 : startWday - 3) + 1) % 7;
                    else if (return_type == 15) startOffset = (7 - ((startWday < 5) ? startWday + 3 : startWday - 4) + 1) % 7;
                    else if (return_type == 16) startOffset = (7 - ((startWday < 6) ? startWday + 2 : startWday - 5) + 1) % 7;

                    double daysElapsed = serial - jan1;
                    if (daysElapsed < startOffset) return 1.0;
                    return (double)(2 + (int)((daysElapsed - startOffset) / 7));
                }
                case 21: {
                    int wday = (int)(std::floor(serial) + 6) % 7;
                    if (wday == 0) wday = 7;

                    auto dayOfYear = [](int yy, int mm, int dd) {
                        int yd = cumDays[mm] + dd;
                        if (mm > 2 && isLeapYear(yy)) yd++;
                        return yd;
                    };
                    int yday = dayOfYear(y, m, d) - 1;

                    int thursDayOfYear = yday + (4 - wday) + 1;
                    if (thursDayOfYear >= 1 && thursDayOfYear <= (isLeapYear(y) ? 366 : 365)) {
                        int jan1Wday = (int)(std::floor(dateToExcelSerial(y, 1, 1)) + 6) % 7;
                        if (jan1Wday == 0) jan1Wday = 7;
                        return (double)(1 + (thursDayOfYear - 1 + jan1Wday - 1) / 7);
                    }
                    
                    if (thursDayOfYear < 1) {
                        int prevY = y - 1;
                        int prevDays = isLeapYear(prevY) ? 366 : 365;
                        double prevJan1 = dateToExcelSerial(prevY, 1, 1);
                        int prevJan1Wday = (int)(std::floor(prevJan1) + 6) % 7;
                        if (prevJan1Wday == 0) prevJan1Wday = 7;
                        return (double)(1 + (prevDays + thursDayOfYear - 1 + prevJan1Wday - 1) / 7);
                    } else {
                        return 1.0;
                    }
                }
                default:
                    return CellError{"#NUM!"};
            }
        });
    });

    // ISOWEEKNUM(date) - FIXED: Correct year boundary handling
    registerFunction("ISOWEEKNUM", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;

        int y, m, d;
        if (!parseDateOrSerial(val, y, m, d)) return CellError{"#VALUE!"};

        double serial = dateToExcelSerial(y, m, d);
        int wday = (int)(std::floor(serial) + 6) % 7;
        
        // ISO: Monday=1, Sunday=7
        if (wday == 0) wday = 7;

        int yday = cumDays[m] + d - 1; // 0-indexed
        if (m > 2 && isLeapYear(y)) yday++;

        // Find Thursday of the same week (ISO week belongs to year of Thursday)
        int thursDayOfYear = yday + (4 - wday) + 1; // 1-indexed for math below
        
        // Determine which year this Thursday belongs to
        int thursYear = y;
        if (thursDayOfYear < 1) {
            // Thursday is in previous year
            thursYear--;
            int daysInPrevYear = isLeapYear(thursYear) ? 366 : 365;
            thursDayOfYear += daysInPrevYear;
        } else {
            int daysInCurYear = isLeapYear(y) ? 366 : 365;
            if (thursDayOfYear > daysInCurYear) {
                // Thursday is in next year
                thursYear++;
                thursDayOfYear -= daysInCurYear;
            }
        }
        
        int isoWeek = (thursDayOfYear - 1) / 7 + 1;
        return (double)isoWeek;
    });

    // Helper: is weekend day
    auto isWeekend = [](int wday) -> bool {
        return wday == 0 || wday == 6; // Sun=0, Sat=6
    };

    // Helper: parse holidays from array or range
    auto parseHolidays = [](const EvalResult& holidayArg) -> std::set<long long> {
        std::set<long long> holidays;
        
        if (std::holds_alternative<ArrayVal>(holidayArg)) {
            const ArrayVal& arr = std::get<ArrayVal>(holidayArg);
            for (const auto& row : arr.matrix) {
                for (const auto& cell : row) {
                    if (std::holds_alternative<double>(cell)) {
                        holidays.insert(std::llround(std::floor(std::get<double>(cell))));
                    } else if (std::holds_alternative<std::string>(cell)) {
                        // Try to parse as date string
                        int y, m, d;
                        if (parseMultipleFormats(cell, y, m, d)) {
                            holidays.insert(std::llround(dateToExcelSerial(y, m, d)));
                        }
                    }
                }
            }
        } else if (std::holds_alternative<double>(holidayArg)) {
            holidays.insert(std::llround(std::floor(std::get<double>(holidayArg))));
        } else if (std::holds_alternative<std::string>(holidayArg)) {
            int y, m, d;
            if (parseMultipleFormats(holidayArg, y, m, d)) {
                holidays.insert(std::llround(dateToExcelSerial(y, m, d)));
            }
        }
        
        return holidays;
    };

    // NETWORKDAYS(start_date, end_date, [holidays]) - FIXED: Holidays now implemented
    registerFunction("NETWORKDAYS", [isWeekend, parseHolidays](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto startVal = EVAL_ARG(eval, args, 0);
        auto endVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(startVal)) return startVal;
        if (Evaluator::isError(endVal)) return endVal;

        // Parse holidays if provided
        std::set<long long> holidays;
        if (args.size() == 3) {
            auto holidayVal = EVAL_ARG(eval, args, 2);
            if (!Evaluator::isError(holidayVal)) {
                holidays = parseHolidays(holidayVal);
            }
        }

        return vectorizeBinary(startVal, endVal, [&isWeekend, &holidays](const EvalResult& sVal, const EvalResult& eVal) -> EvalResult {
            if (Evaluator::isError(sVal)) return sVal;
            if (Evaluator::isError(eVal)) return eVal;
            
            int y1, m1, d1, y2, m2, d2;
            if (!parseDateOrSerial(sVal, y1, m1, d1)) return CellError{"#VALUE!"};
            if (!parseDateOrSerial(eVal, y2, m2, d2)) return CellError{"#VALUE!"};

            double serial1 = dateToExcelSerial(y1, m1, d1);
            double serial2 = dateToExcelSerial(y2, m2, d2);

            int sign = 1;
            if (serial1 > serial2) {
                std::swap(serial1, serial2);
                sign = -1;
            }

            int count = 0;
            for (double s = serial1; s <= serial2; s += 1.0) {
                if (holidays.count(std::llround(std::floor(s))) > 0) continue;
                int wday = (int)(std::floor(s) + 6) % 7;
                if (!isWeekend(wday)) count++;
            }
            return (double)(count * sign);
        });
    });

    // WORKDAY(start_date, days, [holidays]) - FIXED: Holidays now implemented
    registerFunction("WORKDAY", [isWeekend, parseHolidays](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto startVal = EVAL_ARG(eval, args, 0);
        auto daysVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(startVal)) return startVal;
        if (Evaluator::isError(daysVal)) return daysVal;

        std::set<long long> holidays;
        if (args.size() == 3) {
            auto holidayVal = EVAL_ARG(eval, args, 2);
            if (!Evaluator::isError(holidayVal)) {
                holidays = parseHolidays(holidayVal);
            }
        }

        return vectorizeBinary(startVal, daysVal, [&isWeekend, &holidays](const EvalResult& sVal, const EvalResult& dVal) -> EvalResult {
            if (Evaluator::isError(sVal)) return sVal;
            if (Evaluator::isError(dVal)) return dVal;
            
            int y, m, d;
            if (!parseDateOrSerial(sVal, y, m, d)) return CellError{"#VALUE!"};

            int numDays = (int)Evaluator::asNumber(dVal);
            double serial = dateToExcelSerial(y, m, d);

            int step = (numDays > 0) ? 1 : -1;
            int remaining = std::abs(numDays);
            int maxIter = remaining * 366 + (int)holidays.size() + 10;
            int iter = 0;

            while (remaining > 0 && iter++ < maxIter) {
                serial += step;
                if (holidays.count(std::llround(std::floor(serial))) > 0) continue;
                int wday = (int)(std::floor(serial) + 6) % 7;
                if (!isWeekend(wday)) remaining--;
            }
            
            if (remaining > 0) return CellError{"#NUM!"};
            return serial;
        });
    });

    // TIMEVALUE(time_text)
    registerFunction("TIMEVALUE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;

        std::string timeStr = Evaluator::asString(val);
        std::smatch match;
        static const std::regex timeRe(R"(^(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*(AM|PM|am|pm)?$)");
        if (std::regex_match(timeStr, match, timeRe)) {
            int h = std::stoi(match[1].str());
            int m = match[2].matched ? std::stoi(match[2].str()) : 0;
            int s = match[3].matched ? std::stoi(match[3].str()) : 0;
            
            std::string ampm = match[4].matched ? match[4].str() : "";
            std::transform(ampm.begin(), ampm.end(), ampm.begin(), ::toupper);
            
            if (ampm == "PM" && h < 12) h += 12;
            if (ampm == "AM" && h == 12) h = 0;
            
            return (h * 3600.0 + m * 60.0 + s) / 86400.0;
        }
        return CellError{"#VALUE!"};
    });

    // YEARFRAC(start_date, end_date, [basis]) - FIXED: Correct algorithms for all bases
    registerFunction("YEARFRAC", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 3) return CellError{"#VALUE!"};
        auto startVal = EVAL_ARG(eval, args, 0);
        auto endVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(startVal)) return startVal;
        if (Evaluator::isError(endVal)) return endVal;

        int y1, m1, d1, y2, m2, d2;
        if (!parseDateOrSerial(startVal, y1, m1, d1)) return CellError{"#VALUE!"};
        if (!parseDateOrSerial(endVal, y2, m2, d2)) return CellError{"#VALUE!"};

        int basis = 0;
        if (args.size() == 3) {
            auto bVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(bVal)) return bVal;
            basis = (int)Evaluator::asNumber(bVal);
        }

        if (basis < 0 || basis > 4) return CellError{"#NUM!"};

        double serial1 = dateToExcelSerial(y1, m1, d1);
        double serial2 = dateToExcelSerial(y2, m2, d2);
        
        // Ensure start <= end
        if (serial1 > serial2) {
            std::swap(y1, y2);
            std::swap(m1, m2);
            std::swap(d1, d2);
            std::swap(serial1, serial2);
        }

        switch (basis) {
            case 0: // US (NASD) 30/360
            {
                int dd1 = d1, dd2 = d2;
                static const int daysInMon[] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
                int maxD1 = daysInMon[m1];
                if (m1 == 2 && isLeapYear(y1)) maxD1 = 29;
                
                // US 30/360 rules (NASD)
                bool isEom1 = (m1 == 2 && dd1 == maxD1);
                bool isEom2 = (m2 == 2 && dd2 == (isLeapYear(y2) ? 29 : 28));
                
                if (isEom1 && isEom2) dd2 = 30;
                if (isEom1) dd1 = 30;
                if (dd2 == 31 && dd1 >= 30) dd2 = 30;
                if (dd1 == 31) dd1 = 30;
                
                int days = 360 * (y2 - y1) + 30 * (m2 - m1) + (dd2 - dd1);
                return days / 360.0;
            }
            case 1: // Actual/actual
            {
                double totalDays = serial2 - serial1;
                
                if (y1 == y2) {
                    int daysInYear = isLeapYear(y1) ? 366 : 365;
                    return totalDays / daysInYear;
                } else {
                    double daysInY1 = isLeapYear(y1) ? 366.0 : 365.0;
                    double daysInY2 = isLeapYear(y2) ? 366.0 : 365.0;
                    
                    auto dayOfYear = [](int y, int m, int d) -> int {
                        static const int cumDays[] = {0,0,31,59,90,120,151,181,212,243,273,304,334};
                        int yday = cumDays[m] + d;
                        if (m > 2 && isLeapYear(y)) yday++;
                        return yday;
                    };
                    
                    double frac = (daysInY1 - dayOfYear(y1,m1,d1) + 1) / daysInY1 
                                + (y2 - y1 - 1) 
                                + (dayOfYear(y2,m2,d2) - 1) / daysInY2;
                    return frac;
                }
            }
            case 2: // Actual/360
            {
                double totalDays = serial2 - serial1;
                return totalDays / 360.0;
            }
            case 3: // Actual/365
            {
                double totalDays = serial2 - serial1;
                return totalDays / 365.0;
            }
            case 4: // European 30/360
            {
                int dd1 = d1, dd2 = d2;
                
                // European 30/360 rules (simpler than US)
                if (dd1 == 31) dd1 = 30;
                if (dd2 == 31) dd2 = 30;
                
                int days = 360 * (y2 - y1) + 30 * (m2 - m1) + (dd2 - dd1);
                return days / 360.0;
            }
            default:
                return CellError{"#NUM!"};
        }
    });

    // Helper: is weekend intl
    auto isWeekendIntl = [](int wday, const std::string& weekendSpec) -> bool {
        // wday: 0=Sun, 1=Mon, ..., 6=Sat
        if (weekendSpec.length() == 7) {
            int idx = (wday == 0) ? 6 : wday - 1;
            return weekendSpec[idx] == '1';
        }
        int type = 1;
        try { type = std::stoi(weekendSpec); } catch(...) {}
        
        switch (type) {
            case 1: return wday == 0 || wday == 6; // Sat, Sun
            case 2: return wday == 0 || wday == 1; // Sun, Mon
            case 3: return wday == 1 || wday == 2; // Mon, Tue
            case 4: return wday == 2 || wday == 3; // Tue, Wed
            case 5: return wday == 3 || wday == 4; // Wed, Thu
            case 6: return wday == 4 || wday == 5; // Thu, Fri
            case 7: return wday == 5 || wday == 6; // Fri, Sat
            case 11: return wday == 0; // Sun
            case 12: return wday == 1; // Mon
            case 13: return wday == 2; // Tue
            case 14: return wday == 3; // Wed
            case 15: return wday == 4; // Thu
            case 16: return wday == 5; // Fri
            case 17: return wday == 6; // Sat
            default: return wday == 0 || wday == 6; // Fallback to Sat, Sun
        }
    };

    // NETWORKDAYS.INTL(start_date, end_date, [weekend], [holidays]) - FIXED: Holidays now implemented
    registerFunction("NETWORKDAYS.INTL", [isWeekendIntl, parseHolidays](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 4) return CellError{"#VALUE!"};
        auto startVal = EVAL_ARG(eval, args, 0);
        auto endVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(startVal)) return startVal;
        if (Evaluator::isError(endVal)) return endVal;

        std::string weekend = "1";
        if (args.size() >= 3) {
            auto wVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(wVal)) return wVal;
            if (std::holds_alternative<double>(wVal)) {
                weekend = std::to_string((int)std::get<double>(wVal));
            } else {
                weekend = Evaluator::asString(wVal);
            }
        }

        std::set<long long> holidays;
        if (args.size() == 4) {
            auto holidayVal = EVAL_ARG(eval, args, 3);
            if (!Evaluator::isError(holidayVal)) {
                holidays = parseHolidays(holidayVal);
            }
        }

        return vectorizeBinary(startVal, endVal, [&isWeekendIntl, &weekend, &holidays](const EvalResult& sVal, const EvalResult& eVal) -> EvalResult {
            if (Evaluator::isError(sVal)) return sVal;
            if (Evaluator::isError(eVal)) return eVal;
            
            int y1, m1, d1, y2, m2, d2;
            if (!parseDateOrSerial(sVal, y1, m1, d1)) return CellError{"#VALUE!"};
            if (!parseDateOrSerial(eVal, y2, m2, d2)) return CellError{"#VALUE!"};

            double serial1 = dateToExcelSerial(y1, m1, d1);
            double serial2 = dateToExcelSerial(y2, m2, d2);

            int sign = 1;
            if (serial1 > serial2) {
                std::swap(serial1, serial2);
                sign = -1;
            }

            int count = 0;
            for (double s = serial1; s <= serial2; s += 1.0) {
                if (holidays.count(std::llround(std::floor(s))) > 0) continue;
                int wday = (int)(std::floor(s) + 6) % 7;
                if (!isWeekendIntl(wday, weekend)) count++;
            }
            return (double)(count * sign);
        });
    });

    // WORKDAY.INTL(start_date, days, [weekend], [holidays]) - FIXED: Holidays now implemented
    registerFunction("WORKDAY.INTL", [isWeekendIntl, parseHolidays](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 2 || args.size() > 4) return CellError{"#VALUE!"};
        auto startVal = EVAL_ARG(eval, args, 0);
        auto daysVal = EVAL_ARG(eval, args, 1);
        if (Evaluator::isError(startVal)) return startVal;
        if (Evaluator::isError(daysVal)) return daysVal;

        std::string weekend = "1";
        if (args.size() >= 3) {
            auto wVal = EVAL_ARG(eval, args, 2);
            if (Evaluator::isError(wVal)) return wVal;
            if (std::holds_alternative<double>(wVal)) {
                weekend = std::to_string((int)std::get<double>(wVal));
            } else {
                weekend = Evaluator::asString(wVal);
            }
        }

        std::set<long long> holidays;
        if (args.size() == 4) {
            auto holidayVal = EVAL_ARG(eval, args, 3);
            if (!Evaluator::isError(holidayVal)) {
                holidays = parseHolidays(holidayVal);
            }
        }

        return vectorizeBinary(startVal, daysVal, [&isWeekendIntl, &weekend, &holidays](const EvalResult& sVal, const EvalResult& dVal) -> EvalResult {
            if (Evaluator::isError(sVal)) return sVal;
            if (Evaluator::isError(dVal)) return dVal;
            
            int y, m, d;
            if (!parseDateOrSerial(sVal, y, m, d)) return CellError{"#VALUE!"};

            int numDays = (int)Evaluator::asNumber(dVal);
            double serial = dateToExcelSerial(y, m, d);

            int step = (numDays > 0) ? 1 : -1;
            int remaining = std::abs(numDays);
            int maxIter = remaining * 366 + (int)holidays.size() + 10;
            int iter = 0;

            while (remaining > 0 && iter++ < maxIter) {
                serial += step;
                if (holidays.count(std::llround(std::floor(serial))) > 0) continue;
                int wday = (int)(std::floor(serial) + 6) % 7;
                if (!isWeekendIntl(wday, weekend)) remaining--;
            }
            
            if (remaining > 0) return CellError{"#NUM!"};
            return serial;
        });
    });



    // DAYNAME(date, [format]) - NEW: Return day name
    registerFunction("DAYNAME", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 1 || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        int format = 1; // Default: full name
        if (args.size() == 2) {
            auto fmtVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(fmtVal)) return fmtVal;
            format = (int)Evaluator::asNumber(fmtVal);
        }
        
        int y, m, d;
        if (!parseDateOrSerial(val, y, m, d)) return CellError{"#VALUE!"};
        
        // Calculate day of week (0=Sunday)
        double serial = dateToExcelSerial(y, m, d);
        int wday = (int)(std::floor(serial) + 6) % 7;
        
        static const char* daysFull[] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};
        static const char* daysShort[] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};
        
        if (format == 1) {
            return std::string(daysFull[wday]);
        } else {
            return std::string(daysShort[wday]);
        }
    });

    // DATESTRING(serial)
    registerFunction("DATESTRING", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;

        return vectorizeUnary(val, [](const EvalResult& v) -> EvalResult {
            int y, m, d;
            if (!parseDateOrSerial(v, y, m, d)) return CellError{"#VALUE!"};
            char buf[32];
            std::snprintf(buf, sizeof(buf), "%02d/%02d/%04d", m, d, y);
            return std::string(buf);
        });
    });

    // TEXT(value, format_text)
    registerFunction("TEXT", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        auto fmtVal = EVAL_ARG(eval, args, 1);
        
        if (Evaluator::isError(val)) return val;
        if (Evaluator::isError(fmtVal)) return fmtVal;

        return vectorizeBinary(val, fmtVal, [](const EvalResult& v, const EvalResult& fVal) -> EvalResult {
            std::string format = Evaluator::asString(fVal);
            std::transform(format.begin(), format.end(), format.begin(), ::tolower);
            
            // Basic date format checking
            if (format.find("y") != std::string::npos || format.find("m") != std::string::npos || format.find("d") != std::string::npos) {
                int y, m, d;
                if (parseDateOrSerial(v, y, m, d)) {
                    std::string res = format;
                    char buf[32];
                    double serial = dateToExcelSerial(y, m, d);
                    int wday = (int)(std::floor(serial) + 6) % 7;
                    static const char* daysFull[] = {"sunday","monday","tuesday","wednesday","thursday","friday","saturday"};
                    static const char* daysShort[] = {"sun","mon","tue","wed","thu","fri","sat"};
                    static const char* monthsFull[] = {"","january","february","march","april","may","june","july","august","september","october","november","december"};
                    static const char* monthsShort[] = {"","jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"};
                    
                    std::snprintf(buf, sizeof(buf), "%04d", y);
                    res = std::regex_replace(res, std::regex("\\byyyy\\b"), buf);
                    std::snprintf(buf, sizeof(buf), "%02d", y % 100);
                    res = std::regex_replace(res, std::regex("\\byy\\b"), buf);
                    
                    res = std::regex_replace(res, std::regex("\\bmmmm\\b"), monthsFull[m]);
                    res = std::regex_replace(res, std::regex("\\bmmm\\b"), monthsShort[m]);
                    std::snprintf(buf, sizeof(buf), "%02d", m);
                    res = std::regex_replace(res, std::regex("\\bmm\\b"), buf);
                    std::snprintf(buf, sizeof(buf), "%d", m);
                    res = std::regex_replace(res, std::regex("\\bm\\b"), buf);
                    
                    res = std::regex_replace(res, std::regex("\\bdddd\\b"), daysFull[wday]);
                    res = std::regex_replace(res, std::regex("\\bddd\\b"), daysShort[wday]);
                    std::snprintf(buf, sizeof(buf), "%02d", d);
                    res = std::regex_replace(res, std::regex("\\bdd\\b"), buf);
                    std::snprintf(buf, sizeof(buf), "%d", d);
                    res = std::regex_replace(res, std::regex("\\bd\\b"), buf);
                    
                    return res;
                }
            }
            
            // Very basic number fallback
            try {
                double num = Evaluator::asNumber(v);
                char buf[64];
                if (format == "0.00") {
                    std::snprintf(buf, sizeof(buf), "%.2f", num);
                } else if (format == "0%") {
                    std::snprintf(buf, sizeof(buf), "%.0f%%", num * 100.0);
                } else if (format == "0.00%") {
                    std::snprintf(buf, sizeof(buf), "%.2f%%", num * 100.0);
                } else {
                    std::snprintf(buf, sizeof(buf), "%g", num);
                }
                return std::string(buf);
            } catch (...) {
                return Evaluator::asString(v);
            }
        });
    });

    // MONTHNAME(date, [format]) - NEW: Return month name
    registerFunction("MONTHNAME", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 1 || args.size() > 2) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        int format = 1; // Default: full name
        if (args.size() == 2) {
            auto fmtVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(fmtVal)) return fmtVal;
            format = (int)Evaluator::asNumber(fmtVal);
        }
        
        int y, m, d;
        if (!parseDateOrSerial(val, y, m, d)) return CellError{"#VALUE!"};
        
        static const char* monthsFull[] = {"","January","February","March","April","May","June",
            "July","August","September","October","November","December"};
        static const char* monthsShort[] = {"","Jan","Feb","Mar","Apr","May","Jun",
            "Jul","Aug","Sep","Oct","Nov","Dec"};
        
        if (m < 1 || m > 12) return CellError{"#VALUE!"};
        
        if (format == 1) {
            return std::string(monthsFull[m]);
        } else {
            return std::string(monthsShort[m]);
        }
    });

    // ISLEAPYEAR(year) - NEW: Check if year is leap year
    registerFunction("ISLEAPYEAR", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() != 1) return CellError{"#VALUE!"};
        auto val = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(val)) return val;
        
        int year = (int)Evaluator::asNumber(val);
        return isLeapYear(year) ? 1.0 : 0.0;
    });

    // EPOCHTODATE(timestamp, [unit]) - NEW: Convert Unix timestamp to date/time
    registerFunction("EPOCHTODATE", [](Evaluator& eval, const std::vector<std::unique_ptr<ASTNode>>& args) -> EvalResult {
        if (args.size() < 1 || args.size() > 2) return CellError{"#VALUE!"};
        auto timestampVal = EVAL_ARG(eval, args, 0);
        if (Evaluator::isError(timestampVal)) return timestampVal;
        
        std::string unit = "seconds"; // Default
        if (args.size() == 2) {
            auto unitVal = EVAL_ARG(eval, args, 1);
            if (Evaluator::isError(unitVal)) return unitVal;
            unit = Evaluator::asString(unitVal);
            std::transform(unit.begin(), unit.end(), unit.begin(), ::tolower);
        }
        
        double timestamp = Evaluator::asNumber(timestampVal);
        
        // Convert to seconds based on unit
        double timestampSeconds = timestamp;
        if (unit == "milliseconds" || unit == "ms") {
            timestampSeconds = timestamp / 1000.0;
        } else if (unit == "microseconds" || unit == "us") {
            timestampSeconds = timestamp / 1000000.0;
        } else if (unit != "seconds" && unit != "s") {
            return CellError{"#VALUE!"};
        }
        
        // Unix epoch starts at January 1, 1970 UTC
        // Convert to Excel serial number
        // Unix epoch: Jan 1, 1970 = Excel serial 25569
        double excelSerial = 25569.0 + (timestampSeconds / 86400.0);
        
        return excelSerial;
    });
}
