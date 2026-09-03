#include "js_engine.h"
#include "grid_manager.h"
#include "conditional_formatting/cf_manager.h"
#include "data_engine/pattern_intelligence/sequence_pattern.h"
#include "data_engine/pattern_intelligence/relational_pattern.h"
#include "data_engine/pattern_intelligence/anomaly_detector.h"
#include "data_engine/pattern_intelligence/repair_suggester.h"
#include "data_engine/cleaning/record_stitcher.h"
#include "data_engine/cleaning/mixed_cell_demixer.h"
#include "data_engine/analyzer/subtotal_isolator.h"
#include "data_engine/cleaning/row_aligner.h"
#include "data_engine/cleaning/data_cleaner.h"
#include "data_engine/analyzer/header_flattener.h"
#include "data_engine/cleaning/mojibake_cleaner.h"
#include "data_engine/cleaning/address_cleaner.h"
#include "data_engine/cleaning/unit_cleaner.h"
#include "data_engine/cleaning/imputation_engine.h"
#include "data_engine/cleaning/email_cleaner.h"
#include "data_engine/brain/context_compressor.h"
#include "data_engine/cluster/cluster_engine.h"
#include "data_engine/cleaning/date_cleaner.h"
#include "data_engine/cleaning/phone_cleaner.h"
#include <android/log.h>
#include <sstream>
#include <iomanip>
#include <ctime>
#include <iostream>
#include <cctype>
#define LOG_TAG "JsEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern ConditionalFormatting::CFManager* g_cfManager;

JsEngine& JsEngine::getInstance() {
    static JsEngine instance;
    return instance;
}

JsEngine::JsEngine() {}

JsEngine::~JsEngine() {
    cleanup();
}

bool JsEngine::init() {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (m_initialized) return true;

    m_rt = JS_NewRuntime();
    if (!m_rt) {
        LOGE("Failed to create QuickJS Runtime");
        return false;
    }

    m_ctx = JS_NewContext(m_rt);
    if (!m_ctx) {
        LOGE("Failed to create QuickJS Context");
        JS_FreeRuntime(m_rt);
        m_rt = nullptr;
        return false;
    }

    bindNativeApis();
    m_initialized = true;
    LOGI("JsEngine initialized successfully with QuickJS");
    return true;
}

void JsEngine::cleanup() {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (m_ctx) {
        JS_FreeContext(m_ctx);
        m_ctx = nullptr;
    }
    if (m_rt) {
        JS_FreeRuntime(m_rt);
        m_rt = nullptr;
    }
    m_initialized = false;
}

void JsEngine::appendConsole(const std::string& text) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_consoleBuffer += text + "\n";
}

std::string JsEngine::popConsoleOutput() {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    std::string out = m_consoleBuffer;
    m_consoleBuffer.clear();
    return out;
}

// -------------------------------------------------------------
// Native QuickJS Bindings
// -------------------------------------------------------------

// console.log(...)
static JSValue js_console_log(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::ostringstream ss;
    for (int i = 0; i < argc; i++) {
        if (JS_IsObject(argv[i])) {
            JSValue json = JS_JSONStringify(ctx, argv[i], JS_UNDEFINED, JS_UNDEFINED);
            if (!JS_IsException(json) && !JS_IsUndefined(json)) {
                const char* str = JS_ToCString(ctx, json);
                if (str) {
                    ss << str << (i < argc - 1 ? " " : "");
                    JS_FreeCString(ctx, str);
                }
                JS_FreeValue(ctx, json);
                continue;
            }
            JS_FreeValue(ctx, json);
        }
        
        const char *str = JS_ToCString(ctx, argv[i]);
        if (str) {
            ss << str << (i < argc - 1 ? " " : "");
            JS_FreeCString(ctx, str);
        }
    }
    LOGI("[JS Console] %s", ss.str().c_str());
    JsEngine::getInstance().appendConsole(ss.str());
    return JS_UNDEFINED;
}

// fetch(url, options) -> Promise/Async or Sync Callback via Dart
static JSValue js_fetch(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_ThrowTypeError(ctx, "fetch requires at least 1 argument (url)");

    const char *url = JS_ToCString(ctx, argv[0]);
    if (!url) return JS_EXCEPTION;

    std::string optionsJson = "{}";
    if (argc >= 2) {
        const char *optStr = JS_ToCString(ctx, argv[1]);
        if (optStr) {
            optionsJson = optStr;
            JS_FreeCString(ctx, optStr);
        }
    }

    auto fetchCb = JsEngine::getInstance().getFetchCallback();
    if (!fetchCb) {
        JS_FreeCString(ctx, url);
        return JS_ThrowTypeError(ctx, "Fetch callback not registered from Dart bridge");
    }

    char* resPtr = fetchCb(url, optionsJson.c_str());
    JS_FreeCString(ctx, url);

    if (!resPtr) {
        return JS_NULL;
    }

    std::string resStr(resPtr);
    free(resPtr); // Allocated by Dart FFI bridge

    // Parse returned JSON string or return text object
    JSValue obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, obj, "text", JS_NewString(ctx, resStr.c_str()));
    
    // Parse JSON
    JSValue jsonVal = JS_ParseJSON(ctx, resStr.c_str(), resStr.size(), "<fetch>");
    if (!JS_IsException(jsonVal)) {
        JS_SetPropertyStr(ctx, obj, "json", jsonVal);
    }

    return obj;
}

// -------------------------------------------------------------
// Spreadsheet JS API Bindings - Full Google Apps Script Power
// -------------------------------------------------------------

// Helper: column string from 0-indexed column number
static std::string colStr(int col) {
    std::string r;
    int c = col;
    while (c >= 0) { r = char('A' + (c % 26)) + r; c = c / 26 - 1; }
    return r;
}

// Helper: column index from string (0-indexed)
static int colIdx(const std::string& s) {
    int c = 0;
    for (char ch : s) c = c * 26 + (std::toupper(ch) - 'A' + 1);
    return c - 1;
}

// Helper: parse "A1" into 0-indexed (row, col)
static bool parseRef(const std::string& ref, int& row, int& col) {
    size_t i = 0;
    std::string cp;
    while (i < ref.size() && std::isalpha(ref[i])) { cp += std::toupper(ref[i]); i++; }
    if (cp.empty() || i >= ref.size()) return false;
    try { row = std::stoi(ref.substr(i)) - 1; } catch (...) { return false; }
    col = colIdx(cp);
    return true;
}

// Helper: make cell ref from 0-indexed (row, col)
static std::string makeRef(int row, int col) {
    return colStr(col) + std::to_string(row + 1);
}

// Helper: parse "A1" or "A1:B5" into bounds (0-indexed)
static bool parseBounds(const std::string& s, int& r1, int& c1, int& r2, int& c2) {
    size_t p = s.find(':');
    if (p == std::string::npos) {
        if (!parseRef(s, r1, c1)) return false;
        r2 = r1; c2 = c1; return true;
    }
    return parseRef(s.substr(0, p), r1, c1) && parseRef(s.substr(p + 1), r2, c2);
}

// Helper: get _rangeStr from JS this_val
static std::string getRangeStr(JSContext *ctx, JSValueConst this_val) {
    JSValue v = JS_GetPropertyStr(ctx, this_val, "_rangeStr");
    const char *s = JS_ToCString(ctx, v);
    JS_FreeValue(ctx, v);
    std::string result(s ? s : "");
    if (s) JS_FreeCString(ctx, s);
    return result;
}

// Forward declaration
static JSValue createRangeObj(JSContext *ctx, const std::string& rangeStr);

// Helper: convert EvalResult to JSValue
static JSValue evalResultToJS(JSContext *ctx, const EvalResult& res) {
    if (std::holds_alternative<double>(res)) return JS_NewFloat64(ctx, std::get<double>(res));
    if (std::holds_alternative<std::string>(res)) return JS_NewString(ctx, std::get<std::string>(res).c_str());
    if (std::holds_alternative<bool>(res)) return JS_NewBool(ctx, std::get<bool>(res));
    if (std::holds_alternative<CellError>(res)) return JS_NewString(ctx, std::get<CellError>(res).type.c_str());
    return JS_NULL;
}

// ===================== RANGE METHODS =====================

static JSValue js_range_getValue(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    if (ref.empty()) return JS_NULL;
    // For multi-cell range, return top-left value
    int r1, c1, r2, c2;
    if (parseBounds(ref, r1, c1, r2, c2)) ref = makeRef(r1, c1);
    return evalResultToJS(ctx, GridManager::getInstance().evaluateCell(ref));
}

static JSValue js_range_getValues(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NULL;
    JSValue arr = JS_NewArray(ctx);
    for (int r = r1; r <= r2; r++) {
        JSValue row = JS_NewArray(ctx);
        for (int c = c1; c <= c2; c++) {
            EvalResult res = GridManager::getInstance().evaluateCell(makeRef(r, c));
            JS_SetPropertyUint32(ctx, row, c - c1, evalResultToJS(ctx, res));
        }
        JS_SetPropertyUint32(ctx, arr, r - r1, row);
    }
    return arr;
}

static bool isValidFormulaExpression(const std::string& v) {
    if (v.empty() || v[0] != '=') return false;
    if (v.size() == 1) return false;
    char next = v[1];
    if (std::isalpha((unsigned char)next) || std::isdigit((unsigned char)next) || next == '(' || next == '\'' || next == '"') {
        if (v.find("**") != std::string::npos || v.find("^") != std::string::npos) return false;
        return true;
    }
    return false;
}

static JSValue js_range_setValue(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_UNDEFINED;
    // Set value to ALL cells in range
    for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
            std::string cellRef = makeRef(r, c);
            if (JS_IsNumber(argv[0])) {
                double d; JS_ToFloat64(ctx, &d, argv[0]);
                GridManager::getInstance().setCellConstant(cellRef, d);
            } else if (JS_IsString(argv[0])) {
                const char *s = JS_ToCString(ctx, argv[0]);
                std::string v(s ? s : ""); if (s) JS_FreeCString(ctx, s);
                if (isValidFormulaExpression(v)) GridManager::getInstance().setCellFormula(cellRef, v);
                else GridManager::getInstance().setCellConstantString(cellRef, v);
            } else if (JS_IsBool(argv[0])) {
                GridManager::getInstance().setCellConstantString(cellRef, JS_ToBool(ctx, argv[0]) ? "TRUE" : "FALSE");
            }
        }
    }
    return JS_UNDEFINED;
}

static JSValue js_range_setValues(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsArray(ctx, argv[0])) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_UNDEFINED;
    int numRows = r2 - r1 + 1;
    for (int r = 0; r < numRows; r++) {
        JSValue rowArr = JS_GetPropertyUint32(ctx, argv[0], r);
        if (!JS_IsArray(ctx, rowArr)) { JS_FreeValue(ctx, rowArr); continue; }
        int numCols = c2 - c1 + 1;
        for (int c = 0; c < numCols; c++) {
            JSValue cellVal = JS_GetPropertyUint32(ctx, rowArr, c);
            std::string cellRef = makeRef(r1 + r, c1 + c);
            if (JS_IsNumber(cellVal)) {
                double d; JS_ToFloat64(ctx, &d, cellVal);
                GridManager::getInstance().setCellConstant(cellRef, d);
            } else {
                const char *s = JS_ToCString(ctx, cellVal);
                std::string v(s ? s : ""); if (s) JS_FreeCString(ctx, s);
                if (isValidFormulaExpression(v)) GridManager::getInstance().setCellFormula(cellRef, v);
                else GridManager::getInstance().setCellConstantString(cellRef, v);
            }
            JS_FreeValue(ctx, cellVal);
        }
        JS_FreeValue(ctx, rowArr);
    }
    return JS_UNDEFINED;
}


static JSValue js_range_getNumRows(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NewInt32(ctx, 1);
    return JS_NewInt32(ctx, r2 - r1 + 1);
}

static JSValue js_range_getNumColumns(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NewInt32(ctx, 1);
    return JS_NewInt32(ctx, c2 - c1 + 1);
}

static JSValue js_range_getRow(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NewInt32(ctx, 1);
    return JS_NewInt32(ctx, r1 + 1); // 1-indexed like Google
}

static JSValue js_range_getColumn(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NewInt32(ctx, 1);
    return JS_NewInt32(ctx, c1 + 1); // 1-indexed
}

static JSValue js_range_clearFormat(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (parseBounds(ref, r1, c1, r2, c2) && g_cfManager) {
        for (int r = r1; r <= r2; r++) {
            for (int c = c1; c <= c2; c++) {
                std::string cellRef = makeRef(r, c);
                g_cfManager->removeRule("Sheet1", "bg_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fg_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fw_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fst_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fl_" + cellRef);
            }
        }
    }
    return JS_UNDEFINED;
}

static JSValue js_range_clear(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_UNDEFINED;
    for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
            std::string cellRef = makeRef(r, c);
            GridManager::getInstance().clearCell(cellRef);
            if (g_cfManager) {
                g_cfManager->removeRule("Sheet1", "bg_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fg_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fw_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fst_" + cellRef);
                g_cfManager->removeRule("Sheet1", "fl_" + cellRef);
            }
        }
    }
    return JS_UNDEFINED;
}

static JSValue js_range_isBlank(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_TRUE;
    for (int r = r1; r <= r2; r++)
        for (int c = c1; c <= c2; c++)
            if (!GridManager::getInstance().isCellEmpty(makeRef(r, c))) return JS_FALSE;
    return JS_TRUE;
}

static JSValue js_range_getFormula(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NewString(ctx, "");
    std::string f = GridManager::getInstance().getCellFormula(makeRef(r1, c1));
    return JS_NewString(ctx, f.c_str());
}

static JSValue js_range_setFormula(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_UNDEFINED;
    const char *s = JS_ToCString(ctx, argv[0]);
    if (!s) return JS_UNDEFINED;
    std::string formula(s); JS_FreeCString(ctx, s);
    if (formula.empty() || formula[0] != '=') formula = "=" + formula;
    GridManager::getInstance().setCellFormula(makeRef(r1, c1), formula);
    return JS_UNDEFINED;
}

static JSValue js_range_offset(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NULL;
    int rOff = 0, cOff = 0;
    if (argc >= 1) { JS_ToInt32(ctx, &rOff, argv[0]); }
    if (argc >= 2) { JS_ToInt32(ctx, &cOff, argv[1]); }
    int nr = r2 - r1 + 1, nc = c2 - c1 + 1;
    if (argc >= 3) { JS_ToInt32(ctx, &nr, argv[2]); }
    if (argc >= 4) { JS_ToInt32(ctx, &nc, argv[3]); }
    std::string newRange = makeRef(r1 + rOff, c1 + cOff) + ":" + makeRef(r1 + rOff + nr - 1, c1 + cOff + nc - 1);
    return createRangeObj(ctx, newRange);
}

static JSValue js_range_setBackground(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    const char *colorStr = JS_ToCString(ctx, argv[0]);
    if (colorStr && g_cfManager) {
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "bg_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.op = ConditionalFormatting::Operator::None;
                    rule.style.bgColor = colorStr;
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
        JS_FreeCString(ctx, colorStr);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setFontColor(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    const char *colorStr = JS_ToCString(ctx, argv[0]);
    if (colorStr && g_cfManager) {
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "fg_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.op = ConditionalFormatting::Operator::None;
                    rule.style.textColor = colorStr;
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
        JS_FreeCString(ctx, colorStr);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setFontWeight(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    const char *weightStr = JS_ToCString(ctx, argv[0]);
    if (weightStr && g_cfManager) {
        std::string weight(weightStr);
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "fw_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.op = ConditionalFormatting::Operator::None;
                    rule.style.bold = (weight == "bold");
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
        JS_FreeCString(ctx, weightStr);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setFontStyle(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    const char *styleStr = JS_ToCString(ctx, argv[0]);
    if (styleStr && g_cfManager) {
        std::string style(styleStr);
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "fst_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.op = ConditionalFormatting::Operator::None;
                    rule.style.italic = (style == "italic");
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
        JS_FreeCString(ctx, styleStr);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setFontLine(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_UNDEFINED;
    std::string ref = getRangeStr(ctx, this_val);
    const char *lineStr = JS_ToCString(ctx, argv[0]);
    if (lineStr && g_cfManager) {
        std::string line(lineStr);
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "fl_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.op = ConditionalFormatting::Operator::None;
                    if (line == "underline") {
                        rule.style.underline = true;
                        rule.style.strike = false;
                    } else if (line == "line-through") {
                        rule.style.strike = true;
                        rule.style.underline = false;
                    } else if (line == "none") {
                        rule.style.underline = false;
                        rule.style.strike = false;
                    }
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
        JS_FreeCString(ctx, lineStr);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setFontSize(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_DupValue(ctx, this_val);
    std::string ref = getRangeStr(ctx, this_val);
    int size = 0;
    if (JS_ToInt32(ctx, &size, argv[0]) == 0 && g_cfManager) {
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "fsize_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.style.fontSize = size;
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setHorizontalAlignment(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_DupValue(ctx, this_val);
    std::string ref = getRangeStr(ctx, this_val);
    const char *alignStr = JS_ToCString(ctx, argv[0]);
    if (alignStr && g_cfManager) {
        std::string align(alignStr);
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "align_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.style.horizontalAlignment = align;
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
        JS_FreeCString(ctx, alignStr);
    }
    return JS_DupValue(ctx, this_val);
}

static std::string formatExcelSerialDateOrNumber(double val, const std::string& fmt) {
    std::string lowerFmt = fmt;
    for (char &c : lowerFmt) c = (char)std::tolower((unsigned char)c);

    bool isDate = (lowerFmt.find('y') != std::string::npos ||
                   lowerFmt.find('d') != std::string::npos ||
                   lowerFmt.find("mm") != std::string::npos ||
                   lowerFmt.find("date") != std::string::npos);

    if (isDate && val > 0 && val < 2958465) {
        int days = (int)val;
        double fraction = val - days;
        int seconds = (int)(fraction * 86400.0 + 0.5);
        int64_t unixTime = (int64_t)(days - 25569) * 86400 + seconds;
        time_t rawTime = (time_t)unixTime;
        struct tm * timeinfo = gmtime(&rawTime);
        if (timeinfo) {
            char buf[64];
            char sep = (lowerFmt.find('/') != std::string::npos) ? '/' : '-';

            size_t yPos = lowerFmt.find('y');
            size_t mPos = lowerFmt.find("mm");
            if (mPos == std::string::npos) mPos = lowerFmt.find('m');
            size_t dPos = lowerFmt.find("dd");
            if (dPos == std::string::npos) dPos = lowerFmt.find('d');

            if (yPos != std::string::npos && (mPos == std::string::npos || yPos < mPos) && (dPos == std::string::npos || yPos < dPos)) {
                snprintf(buf, sizeof(buf), "%04d%c%02d%c%02d",
                         timeinfo->tm_year + 1900, sep, timeinfo->tm_mon + 1, sep, timeinfo->tm_mday);
            } else if (mPos != std::string::npos && (dPos == std::string::npos || mPos < dPos)) {
                snprintf(buf, sizeof(buf), "%02d%c%02d%c%04d",
                         timeinfo->tm_mon + 1, sep, timeinfo->tm_mday, sep, timeinfo->tm_year + 1900);
            } else {
                snprintf(buf, sizeof(buf), "%02d%c%02d%c%04d",
                         timeinfo->tm_mday, sep, timeinfo->tm_mon + 1, sep, timeinfo->tm_year + 1900);
            }
            return std::string(buf);
        }
    }

    if (fmt.find('$') != std::string::npos || fmt.find("₹") != std::string::npos || lowerFmt.find("currency") != std::string::npos) {
        std::ostringstream ss;
        ss << std::fixed << std::setprecision(2) << val;
        std::string symbol = (fmt.find('$') != std::string::npos) ? "$" : "₹";
        return symbol + ss.str();
    }

    if (fmt.find('%') != std::string::npos || lowerFmt.find("percent") != std::string::npos) {
        std::ostringstream ss;
        ss << std::fixed << std::setprecision(2) << (val * 100.0) << "%";
        return ss.str();
    }

    return "";
}

static JSValue js_range_setNumberFormat(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_DupValue(ctx, this_val);
    std::string ref = getRangeStr(ctx, this_val);
    const char *fmtStr = JS_ToCString(ctx, argv[0]);
    if (fmtStr) {
        std::string format(fmtStr);
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    if (g_cfManager) {
                        ConditionalFormatting::CFRule rule;
                        rule.id = "numfmt_" + cellRef;
                        rule.type = ConditionalFormatting::RuleType::Static;
                        rule.style.numberFormat = format;
                        rule.ranges.push_back(cellRef);
                        g_cfManager->addRule("Sheet1", rule);
                    }
                    EvalResult res = GridManager::getInstance().evaluateCell(cellRef);
                    double numVal = 0.0;
                    bool hasNum = false;
                    if (std::holds_alternative<double>(res)) {
                        numVal = std::get<double>(res);
                        hasNum = true;
                    } else if (std::holds_alternative<std::string>(res)) {
                        std::string s = std::get<std::string>(res);
                        while (!s.empty() && std::isspace((unsigned char)s.front())) s.erase(0, 1);
                        while (!s.empty() && std::isspace((unsigned char)s.back())) s.pop_back();
                        try {
                            size_t p = 0;
                            numVal = std::stod(s, &p);
                            if (p == s.length()) hasNum = true;
                        } catch (...) {}
                    }
                    if (hasNum) {
                        std::string formatted = formatExcelSerialDateOrNumber(numVal, format);
                        if (!formatted.empty()) {
                            GridManager::getInstance().setCellConstantString(cellRef, formatted);
                        }
                    }
                }
            }
        }
        JS_FreeCString(ctx, fmtStr);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_removeDuplicates(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    if (!ref.empty()) GridManager::getInstance().removeDuplicates(ref);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_findAndReplace(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 2) return JS_DupValue(ctx, this_val);
    std::string ref = getRangeStr(ctx, this_val);
    const char *p = JS_ToCString(ctx, argv[0]);
    const char *r = JS_ToCString(ctx, argv[1]);
    bool isReg = (argc > 2) ? JS_ToBool(ctx, argv[2]) : false;
    if (p && r && !ref.empty()) GridManager::getInstance().findAndReplace(ref, p, r, isReg);
    if (p) JS_FreeCString(ctx, p);
    if (r) JS_FreeCString(ctx, r);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setDataValidation(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsArray(ctx, argv[0])) return JS_DupValue(ctx, this_val);
    std::string ref = getRangeStr(ctx, this_val);
    std::vector<std::string> vals;
    uint32_t len;
    JSValue lengthObj = JS_GetPropertyStr(ctx, argv[0], "length");
    JS_ToUint32(ctx, &len, lengthObj);
    JS_FreeValue(ctx, lengthObj);
    for (uint32_t i = 0; i < len; i++) {
        JSValue el = JS_GetPropertyUint32(ctx, argv[0], i);
        const char *s = JS_ToCString(ctx, el);
        if (s) { vals.push_back(s); JS_FreeCString(ctx, s); }
        JS_FreeValue(ctx, el);
    }
    if (!ref.empty()) GridManager::getInstance().setDataValidation(ref, vals);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_flashFill(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_DupValue(ctx, this_val);
    std::string targetRef = getRangeStr(ctx, this_val);
    std::string sourceRef = "";
    if (JS_IsObject(argv[0])) {
        JSValue v = JS_GetPropertyStr(ctx, argv[0], "_rangeStr");
        const char *s = JS_ToCString(ctx, v);
        if (s) { sourceRef = s; JS_FreeCString(ctx, s); }
        JS_FreeValue(ctx, v);
    } else {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { sourceRef = s; JS_FreeCString(ctx, s); }
    }
    if (!targetRef.empty() && !sourceRef.empty()) GridManager::getInstance().flashFill(sourceRef, targetRef);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_addConditionalFormatRule(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 2) return JS_DupValue(ctx, this_val);
    std::string ref = getRangeStr(ctx, this_val);
    const char *typeStr = JS_ToCString(ctx, argv[0]);
    const char *valStr = JS_ToCString(ctx, argv[1]);
    const char *colorStr = argc > 2 ? JS_ToCString(ctx, argv[2]) : nullptr;
    
    if (typeStr && valStr && g_cfManager) {
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "cfr_" + cellRef + "_" + typeStr;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.style.bgColor = std::string(colorStr ? colorStr : "#FFFF00");
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
    }
    if (typeStr) JS_FreeCString(ctx, typeStr);
    if (valStr) JS_FreeCString(ctx, valStr);
    if (colorStr) JS_FreeCString(ctx, colorStr);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setWrap(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_DupValue(ctx, this_val);
    std::string ref = getRangeStr(ctx, this_val);
    bool wrap = JS_ToBool(ctx, argv[0]);
    if (g_cfManager) {
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::CFRule rule;
                    rule.id = "wrap_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.style.wrapText = wrap;
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setBorder(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (g_cfManager) {
        std::string ref = getRangeStr(ctx, this_val);
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            bool top = (argc > 0 && !JS_IsNull(argv[0]) && !JS_IsUndefined(argv[0])) ? JS_ToBool(ctx, argv[0]) : true;
            bool left = (argc > 1 && !JS_IsNull(argv[1]) && !JS_IsUndefined(argv[1])) ? JS_ToBool(ctx, argv[1]) : true;
            bool bottom = (argc > 2 && !JS_IsNull(argv[2]) && !JS_IsUndefined(argv[2])) ? JS_ToBool(ctx, argv[2]) : true;
            bool right = (argc > 3 && !JS_IsNull(argv[3]) && !JS_IsUndefined(argv[3])) ? JS_ToBool(ctx, argv[3]) : true;

            std::string color = "#000000";
            if (argc > 6 && JS_IsString(argv[6])) {
                const char* cStr = JS_ToCString(ctx, argv[6]);
                if (cStr) { color = cStr; JS_FreeCString(ctx, cStr); }
            }

            std::string styleStr = "solid";
            if (argc > 7 && JS_IsString(argv[7])) {
                const char* sStr = JS_ToCString(ctx, argv[7]);
                if (sStr) { styleStr = sStr; JS_FreeCString(ctx, sStr); }
            }

            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::BorderConfig bConf;
                    if (top && r == r1) bConf.top = ConditionalFormatting::BorderStyle{true, color, styleStr};
                    if (bottom && r == r2) bConf.bottom = ConditionalFormatting::BorderStyle{true, color, styleStr};
                    if (left && c == c1) bConf.left = ConditionalFormatting::BorderStyle{true, color, styleStr};
                    if (right && c == c2) bConf.right = ConditionalFormatting::BorderStyle{true, color, styleStr};

                    if (top && r > r1) bConf.top = ConditionalFormatting::BorderStyle{true, color, styleStr};
                    if (bottom && r < r2) bConf.bottom = ConditionalFormatting::BorderStyle{true, color, styleStr};
                    if (left && c > c1) bConf.left = ConditionalFormatting::BorderStyle{true, color, styleStr};
                    if (right && c < c2) bConf.right = ConditionalFormatting::BorderStyle{true, color, styleStr};

                    ConditionalFormatting::CFRule rule;
                    rule.id = "border_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.style.border = bConf;
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_setOutline(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (g_cfManager) {
        std::string ref = getRangeStr(ctx, this_val);
        int r1, c1, r2, c2;
        if (parseBounds(ref, r1, c1, r2, c2)) {
            std::string color = "#000000";
            if (argc > 0 && JS_IsString(argv[0])) {
                const char* cStr = JS_ToCString(ctx, argv[0]);
                if (cStr) { color = cStr; JS_FreeCString(ctx, cStr); }
            }

            for (int r = r1; r <= r2; r++) {
                for (int c = c1; c <= c2; c++) {
                    std::string cellRef = makeRef(r, c);
                    ConditionalFormatting::BorderConfig bConf;
                    if (r == r1) bConf.top = ConditionalFormatting::BorderStyle{true, color, "solid"};
                    if (r == r2) bConf.bottom = ConditionalFormatting::BorderStyle{true, color, "solid"};
                    if (c == c1) bConf.left = ConditionalFormatting::BorderStyle{true, color, "solid"};
                    if (c == c2) bConf.right = ConditionalFormatting::BorderStyle{true, color, "solid"};

                    ConditionalFormatting::CFRule rule;
                    rule.id = "outline_" + cellRef;
                    rule.type = ConditionalFormatting::RuleType::Static;
                    rule.style.border = bConf;
                    rule.ranges.push_back(cellRef);
                    g_cfManager->addRule("Sheet1", rule);
                }
            }
        }
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_merge(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    GridManager::getInstance().mergeCells(ref);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_breakApart(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    GridManager::getInstance().breakApartCells(ref);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_getA1Notation(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    return JS_NewString(ctx, ref.c_str());
}

static JSValue js_range_activate(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    std::string action = "{\"action\":\"select\",\"range\":\"" + ref + "\"}";
    JsEngine::getInstance().enqueueUiAction(action);
    return JS_DupValue(ctx, this_val);
}

static JSValue js_range_checkSequenceAnomaly(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NULL;
    
    std::vector<std::string> values;
    std::vector<std::string> cellRefs;
    for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
            std::string cellRef = makeRef(r, c);
            EvalResult res = GridManager::getInstance().evaluateCell(cellRef);
            if (std::holds_alternative<double>(res)) values.push_back(std::to_string(static_cast<int>(std::get<double>(res))));
            else if (std::holds_alternative<std::string>(res)) values.push_back(std::get<std::string>(res));
            else values.push_back("");
            cellRefs.push_back(cellRef);
        }
    }
    
    auto anomalies = PatternIntelligence::SequencePattern::checkNumericSequence(values, cellRefs);
    JSValue arr = JS_NewArray(ctx);
    for (size_t i = 0; i < anomalies.size(); ++i) {
        JSValue obj = JS_NewObject(ctx);
        JS_SetPropertyStr(ctx, obj, "cellRef", JS_NewString(ctx, anomalies[i].cellRef.c_str()));
        JS_SetPropertyStr(ctx, obj, "expectedValue", JS_NewString(ctx, anomalies[i].expectedValue.c_str()));
        JS_SetPropertyStr(ctx, obj, "foundValue", JS_NewString(ctx, anomalies[i].foundValue.c_str()));
        JS_SetPropertyUint32(ctx, arr, i, obj);
    }
    return arr;
}

static JSValue js_range_checkRelationalAnomaly(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsString(argv[0])) return JS_NULL;
    
    std::string ref1 = getRangeStr(ctx, this_val);
    const char* ref2_cstr = JS_ToCString(ctx, argv[0]);
    std::string ref2(ref2_cstr ? ref2_cstr : "");
    if (ref2_cstr) JS_FreeCString(ctx, ref2_cstr);
    
    int r1a, c1a, r2a, c2a;
    if (!parseBounds(ref1, r1a, c1a, r2a, c2a)) return JS_NULL;
    int r1b, c1b, r2b, c2b;
    if (!parseBounds(ref2, r1b, c1b, r2b, c2b)) return JS_NULL;
    
    std::vector<std::string> dates1, refs1, dates2, refs2;
    
    for (int r = r1a; r <= r2a; r++) {
        for (int c = c1a; c <= c2a; c++) {
            std::string cr = makeRef(r, c);
            EvalResult res = GridManager::getInstance().evaluateCell(cr);
            dates1.push_back(std::holds_alternative<std::string>(res) ? std::get<std::string>(res) : "");
            refs1.push_back(cr);
        }
    }
    
    for (int r = r1b; r <= r2b; r++) {
        for (int c = c1b; c <= c2b; c++) {
            std::string cr = makeRef(r, c);
            EvalResult res = GridManager::getInstance().evaluateCell(cr);
            dates2.push_back(std::holds_alternative<std::string>(res) ? std::get<std::string>(res) : "");
            refs2.push_back(cr);
        }
    }
    
    auto anomalies = PatternIntelligence::RelationalPattern::checkTemporalLogic(dates1, refs1, dates2, refs2);
    JSValue arr = JS_NewArray(ctx);
    for (size_t i = 0; i < anomalies.size(); ++i) {
        JSValue obj = JS_NewObject(ctx);
        JS_SetPropertyStr(ctx, obj, "primaryCellRef", JS_NewString(ctx, anomalies[i].primaryCellRef.c_str()));
        JS_SetPropertyStr(ctx, obj, "secondaryCellRef", JS_NewString(ctx, anomalies[i].secondaryCellRef.c_str()));
        JS_SetPropertyStr(ctx, obj, "description", JS_NewString(ctx, anomalies[i].description.c_str()));
        JS_SetPropertyUint32(ctx, arr, i, obj);
    }
    return arr;
}

static JSValue js_range_getRepairSuggestions(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NULL;
    
    std::vector<std::string> values;
    std::vector<std::string> cellRefs;
    for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
            std::string cellRef = makeRef(r, c);
            EvalResult res = GridManager::getInstance().evaluateCell(cellRef);
            if (std::holds_alternative<double>(res)) values.push_back(std::to_string(static_cast<int>(std::get<double>(res))));
            else if (std::holds_alternative<std::string>(res)) values.push_back(std::get<std::string>(res));
            else values.push_back("");
            cellRefs.push_back(cellRef);
        }
    }
    
    auto suggestions = PatternIntelligence::RepairSuggester::suggestRepairs(values, cellRefs);
    JSValue arr = JS_NewArray(ctx);
    for (size_t i = 0; i < suggestions.size(); ++i) {
        JSValue obj = JS_NewObject(ctx);
        JS_SetPropertyStr(ctx, obj, "cellRef", JS_NewString(ctx, suggestions[i].cellRef.c_str()));
        JS_SetPropertyStr(ctx, obj, "originalValue", JS_NewString(ctx, suggestions[i].originalValue.c_str()));
        JS_SetPropertyStr(ctx, obj, "suggestedValue", JS_NewString(ctx, suggestions[i].suggestedValue.c_str()));
        JS_SetPropertyStr(ctx, obj, "confidenceScore", JS_NewFloat64(ctx, suggestions[i].confidenceScore));
        JS_SetPropertyUint32(ctx, arr, i, obj);
    }
    return arr;
}

static JSValue js_range_detectAnomalies(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string ref = getRangeStr(ctx, this_val);
    int r1, c1, r2, c2;
    if (!parseBounds(ref, r1, c1, r2, c2)) return JS_NULL;
    
    std::vector<std::string> values;
    std::vector<std::string> cellRefs;
    for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
            std::string cellRef = makeRef(r, c);
            EvalResult res = GridManager::getInstance().evaluateCell(cellRef);
            if (std::holds_alternative<double>(res)) values.push_back(std::to_string(static_cast<int>(std::get<double>(res))));
            else if (std::holds_alternative<std::string>(res)) values.push_back(std::get<std::string>(res));
            else values.push_back("");
            cellRefs.push_back(cellRef);
        }
    }
    
    auto anomalies = PatternIntelligence::AnomalyDetector::detectAnomalies(values, cellRefs);
    JSValue arr = JS_NewArray(ctx);
    for (size_t i = 0; i < anomalies.size(); ++i) {
        JSValue obj = JS_NewObject(ctx);
        JS_SetPropertyStr(ctx, obj, "cellRef", JS_NewString(ctx, anomalies[i].cellRef.c_str()));
        JS_SetPropertyStr(ctx, obj, "value", JS_NewString(ctx, anomalies[i].value.c_str()));
        JS_SetPropertyStr(ctx, obj, "reason", JS_NewString(ctx, anomalies[i].reason.c_str()));
        JS_SetPropertyUint32(ctx, arr, i, obj);
    }
    return arr;
}

// Create a Range object with ALL methods bound
static JSValue createRangeObj(JSContext *ctx, const std::string& rangeStr) {
    JSValue obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, obj, "_rangeStr", JS_NewString(ctx, rangeStr.c_str()));
    JS_SetPropertyStr(ctx, obj, "getValue", JS_NewCFunction(ctx, js_range_getValue, "getValue", 0));
    JS_SetPropertyStr(ctx, obj, "getValues", JS_NewCFunction(ctx, js_range_getValues, "getValues", 0));
    JS_SetPropertyStr(ctx, obj, "setValue", JS_NewCFunction(ctx, js_range_setValue, "setValue", 1));
    JS_SetPropertyStr(ctx, obj, "setValues", JS_NewCFunction(ctx, js_range_setValues, "setValues", 1));
    JS_SetPropertyStr(ctx, obj, "getNumRows", JS_NewCFunction(ctx, js_range_getNumRows, "getNumRows", 0));
    JS_SetPropertyStr(ctx, obj, "getNumColumns", JS_NewCFunction(ctx, js_range_getNumColumns, "getNumColumns", 0));
    JS_SetPropertyStr(ctx, obj, "getRow", JS_NewCFunction(ctx, js_range_getRow, "getRow", 0));
    JS_SetPropertyStr(ctx, obj, "getColumn", JS_NewCFunction(ctx, js_range_getColumn, "getColumn", 0));
    JS_SetPropertyStr(ctx, obj, "clear", JS_NewCFunction(ctx, js_range_clear, "clear", 0));
    JS_SetPropertyStr(ctx, obj, "clearContent", JS_NewCFunction(ctx, js_range_clear, "clearContent", 0));
    JS_SetPropertyStr(ctx, obj, "clearFormat", JS_NewCFunction(ctx, js_range_clearFormat, "clearFormat", 0));
    JS_SetPropertyStr(ctx, obj, "isBlank", JS_NewCFunction(ctx, js_range_isBlank, "isBlank", 0));
    JS_SetPropertyStr(ctx, obj, "getFormula", JS_NewCFunction(ctx, js_range_getFormula, "getFormula", 0));
    JS_SetPropertyStr(ctx, obj, "setFormula", JS_NewCFunction(ctx, js_range_setFormula, "setFormula", 1));
    JS_SetPropertyStr(ctx, obj, "offset", JS_NewCFunction(ctx, js_range_offset, "offset", 4));
    JS_SetPropertyStr(ctx, obj, "setBackground", JS_NewCFunction(ctx, js_range_setBackground, "setBackground", 1));
    JS_SetPropertyStr(ctx, obj, "setFontColor", JS_NewCFunction(ctx, js_range_setFontColor, "setFontColor", 1));
    JS_SetPropertyStr(ctx, obj, "setFontWeight", JS_NewCFunction(ctx, js_range_setFontWeight, "setFontWeight", 1));
    JS_SetPropertyStr(ctx, obj, "setFontStyle", JS_NewCFunction(ctx, js_range_setFontStyle, "setFontStyle", 1));
    JS_SetPropertyStr(ctx, obj, "setFontLine", JS_NewCFunction(ctx, js_range_setFontLine, "setFontLine", 1));
    JS_SetPropertyStr(ctx, obj, "setFontSize", JS_NewCFunction(ctx, js_range_setFontSize, "setFontSize", 1));
    JS_SetPropertyStr(ctx, obj, "setHorizontalAlignment", JS_NewCFunction(ctx, js_range_setHorizontalAlignment, "setHorizontalAlignment", 1));
    JS_SetPropertyStr(ctx, obj, "setNumberFormat", JS_NewCFunction(ctx, js_range_setNumberFormat, "setNumberFormat", 1));
    
    // Advanced Data Tools
    JS_SetPropertyStr(ctx, obj, "removeDuplicates", JS_NewCFunction(ctx, js_range_removeDuplicates, "removeDuplicates", 0));
    JS_SetPropertyStr(ctx, obj, "findAndReplace", JS_NewCFunction(ctx, js_range_findAndReplace, "findAndReplace", 3));
    JS_SetPropertyStr(ctx, obj, "setDataValidation", JS_NewCFunction(ctx, js_range_setDataValidation, "setDataValidation", 1));
    JS_SetPropertyStr(ctx, obj, "flashFill", JS_NewCFunction(ctx, js_range_flashFill, "flashFill", 1));
    JS_SetPropertyStr(ctx, obj, "addConditionalFormatRule", JS_NewCFunction(ctx, js_range_addConditionalFormatRule, "addConditionalFormatRule", 3));
    JS_SetPropertyStr(ctx, obj, "checkSequenceAnomaly", JS_NewCFunction(ctx, js_range_checkSequenceAnomaly, "checkSequenceAnomaly", 0));
    JS_SetPropertyStr(ctx, obj, "checkRelationalAnomaly", JS_NewCFunction(ctx, js_range_checkRelationalAnomaly, "checkRelationalAnomaly", 1));
    JS_SetPropertyStr(ctx, obj, "getRepairSuggestions", JS_NewCFunction(ctx, js_range_getRepairSuggestions, "getRepairSuggestions", 0));
    JS_SetPropertyStr(ctx, obj, "detectAnomalies", JS_NewCFunction(ctx, js_range_detectAnomalies, "detectAnomalies", 0));
    JS_SetPropertyStr(ctx, obj, "setWrap", JS_NewCFunction(ctx, js_range_setWrap, "setWrap", 1));
    JS_SetPropertyStr(ctx, obj, "setBorder", JS_NewCFunction(ctx, js_range_setBorder, "setBorder", 8));
    JS_SetPropertyStr(ctx, obj, "setBorders", JS_NewCFunction(ctx, js_range_setBorder, "setBorders", 8));
    JS_SetPropertyStr(ctx, obj, "setOutline", JS_NewCFunction(ctx, js_range_setOutline, "setOutline", 1));
    JS_SetPropertyStr(ctx, obj, "merge", JS_NewCFunction(ctx, js_range_merge, "merge", 0));
    JS_SetPropertyStr(ctx, obj, "breakApart", JS_NewCFunction(ctx, js_range_breakApart, "breakApart", 0));
    JS_SetPropertyStr(ctx, obj, "getA1Notation", JS_NewCFunction(ctx, js_range_getA1Notation, "getA1Notation", 0));
    JS_SetPropertyStr(ctx, obj, "activate", JS_NewCFunction(ctx, js_range_activate, "activate", 0));
    return obj;
}

// ===================== SHEET METHODS =====================

// Sheet.getRange - supports (string), (row,col), (row,col,numRows,numCols)
static JSValue js_sheet_getRange(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1) return JS_NULL;
    if (JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (!s) return JS_NULL;
        std::string rangeStr(s); JS_FreeCString(ctx, s);
        return createRangeObj(ctx, rangeStr);
    }
    // Numeric: getRange(row, col) or getRange(row, col, numRows, numCols)
    int row = 0, col = 0;
    JS_ToInt32(ctx, &row, argv[0]); // 1-indexed
    if (argc >= 2) JS_ToInt32(ctx, &col, argv[1]);
    if (argc >= 4) {
        int numRows = 1, numCols = 1;
        JS_ToInt32(ctx, &numRows, argv[2]);
        JS_ToInt32(ctx, &numCols, argv[3]);
        if (numRows <= 0) numRows = 1;
        if (numCols <= 0) numCols = 1;
        std::string rangeStr = makeRef(row - 1, col - 1) + ":" + makeRef(row - 1 + numRows - 1, col - 1 + numCols - 1);
        return createRangeObj(ctx, rangeStr);
    }
    return createRangeObj(ctx, makeRef(row - 1, col - 1));
}

static JSValue js_sheet_getLastRow(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    int lr = GridManager::getInstance().getLastRow();
    return JS_NewInt32(ctx, lr > 0 ? lr : 1);
}


static JSValue js_sheet_getLastColumn(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    int lc = GridManager::getInstance().getLastColumn();
    return JS_NewInt32(ctx, lc > 0 ? lc : 26);
}


static JSValue js_sheet_getDataRange(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    int lr = GridManager::getInstance().getLastRow();
    int lc = GridManager::getInstance().getLastColumn();
    if (lr == 0 || lc == 0) return createRangeObj(ctx, "A1");
    std::string rangeStr = "A1:" + makeRef(lr - 1, lc - 1);
    return createRangeObj(ctx, rangeStr);
}

static JSValue js_sheet_clear(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    GridManager::getInstance().clearGrid();
    return JS_UNDEFINED;
}

static JSValue js_sheet_appendRow(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsArray(ctx, argv[0])) return JS_UNDEFINED;
    int lastRow = GridManager::getInstance().getLastRow(); // 1-indexed count
    JSValue lenVal = JS_GetPropertyStr(ctx, argv[0], "length");
    int len = 0; JS_ToInt32(ctx, &len, lenVal); JS_FreeValue(ctx, lenVal);
    for (int c = 0; c < len; c++) {
        JSValue val = JS_GetPropertyUint32(ctx, argv[0], c);
        std::string cellRef = makeRef(lastRow, c); // lastRow is already next row (0-indexed = lastRow)
        if (JS_IsNumber(val)) {
            double d; JS_ToFloat64(ctx, &d, val);
            GridManager::getInstance().setCellConstant(cellRef, d);
        } else {
            const char *s = JS_ToCString(ctx, val);
            std::string v(s ? s : ""); if (s) JS_FreeCString(ctx, s);
            GridManager::getInstance().setCellConstantString(cellRef, v);
        }
        JS_FreeValue(ctx, val);
    }
    return JS_UNDEFINED;
}

static JSValue js_sheet_getMaxRows(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_NewInt32(ctx, 1000); // Default max
}

static JSValue js_sheet_getMaxColumns(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_NewInt32(ctx, 26); // Default max
}

static JSValue js_sheet_getName(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_GetPropertyStr(ctx, this_val, "name");
}

static JSValue js_sheet_getSheetId(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_NewInt32(ctx, 0);
}

static JSValue js_sheet_insertRows(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    // Stub - would need grid shifting logic
    return JS_UNDEFINED;
}

static JSValue js_sheet_deleteRows(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_UNDEFINED;
}

static JSValue js_sheet_insertColumns(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_UNDEFINED;
}

static JSValue js_sheet_deleteColumns(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_UNDEFINED;
}

static JSValue js_sheet_setColumnWidth(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 2) return JS_DupValue(ctx, this_val);
    int col, width;
    if (JS_ToInt32(ctx, &col, argv[0]) == 0 && JS_ToInt32(ctx, &width, argv[1]) == 0) {
        // Apps Script is 1-indexed for columns
        GridManager::getInstance().setColumnWidth(col - 1, width);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_sheet_setRowHeight(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 2) return JS_DupValue(ctx, this_val);
    int row, height;
    if (JS_ToInt32(ctx, &row, argv[0]) == 0 && JS_ToInt32(ctx, &height, argv[1]) == 0) {
        // Apps Script is 1-indexed for rows
        GridManager::getInstance().setRowHeight(row - 1, height);
    }
    return JS_DupValue(ctx, this_val);
}

static JSValue js_sheet_getActiveCell(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return createRangeObj(ctx, "A1");
}

static JSValue createSheetObj(JSContext *ctx, const std::string& sheetName);
static JSValue js_spreadsheetapp_getActiveSheet(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv);

static JSValue js_sheet_getSheets(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    JSValue arr = JS_NewArray(ctx);
    const auto& sheets = JsEngine::getInstance().getSheetNames();
    for (size_t i = 0; i < sheets.size(); i++) {
        JS_SetPropertyUint32(ctx, arr, i, createSheetObj(ctx, sheets[i]));
    }
    return arr;
}

static JSValue js_sheet_stitchMultiLineRecords(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    int lastRow = GridManager::getInstance().getLastRow();
    int lastCol = GridManager::getInstance().getLastColumn();
    if (lastRow <= 1) return JS_NewInt32(ctx, 0);

    std::vector<std::vector<std::string>> matrix(lastRow + 1, std::vector<std::string>(lastCol, ""));
    for (int r = 1; r <= lastRow; ++r) {
        for (int c = 1; c <= lastCol; ++c) {
            std::string ref = makeRef(r - 1, c - 1);
            EvalResult ev = GridManager::getInstance().evaluateCell(ref);
            if (std::holds_alternative<std::string>(ev)) matrix[r][c - 1] = std::get<std::string>(ev);
            else if (std::holds_alternative<double>(ev)) matrix[r][c - 1] = std::to_string(std::get<double>(ev));
        }
    }

    auto stitchRes = Filters::RecordStitcher::getInstance().stitchGrid(matrix, true);
    GridManager::getInstance().clearGrid();
    for (size_t r = 1; r < stitchRes.cleanGrid.size(); ++r) {
        for (size_t c = 0; c < stitchRes.cleanGrid[r].size(); ++c) {
            if (!stitchRes.cleanGrid[r][c].empty()) {
                std::string ref = makeRef(static_cast<int>(r - 1), static_cast<int>(c));
                GridManager::getInstance().setCellConstantString(ref, stitchRes.cleanGrid[r][c]);
            }
        }
    }
    return JS_NewInt32(ctx, stitchRes.report.stitchedRowsCount);
}

static JSValue js_sheet_demixColumn(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string colLetter = "A";
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { colLetter = s; JS_FreeCString(ctx, s); }
    }
    for (char& ch : colLetter) ch = std::toupper((unsigned char)ch);
    int col = colIdx(colLetter);

    int lastRow = GridManager::getInstance().getLastRow();
    if (lastRow < 2) return JS_NewInt32(ctx, 0);

    std::vector<std::string> values;
    for (int r = 2; r <= lastRow; ++r) {
        std::string ref = colLetter + std::to_string(r);
        EvalResult ev = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<std::string>(ev)) values.push_back(std::get<std::string>(ev));
        else values.push_back("");
    }

    auto demixRes = Filters::MixedCellDeMixer::getInstance().demixColumn(values);
    for (size_t colOffset = 0; colOffset < demixRes.columnHeaders.size(); ++colOffset) {
        int targetCol = col + 1 + static_cast<int>(colOffset);
        GridManager::getInstance().setCellConstantString(makeRef(0, targetCol), demixRes.columnHeaders[colOffset]);
        for (size_t r = 0; r < demixRes.matrix.size(); ++r) {
            if (!demixRes.matrix[r][colOffset].empty()) {
                GridManager::getInstance().setCellConstantString(makeRef(static_cast<int>(r + 1), targetCol), demixRes.matrix[r][colOffset]);
            }
        }
    }
    return JS_NewInt32(ctx, demixRes.successfullyExtractedCount);
}

static JSValue js_sheet_isolateSubtotals(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    int lastRow = GridManager::getInstance().getLastRow();
    int lastCol = GridManager::getInstance().getLastColumn();
    if (lastRow <= 1) return JS_NewInt32(ctx, 0);

    std::vector<std::vector<std::string>> matrix(lastRow + 1, std::vector<std::string>(lastCol, ""));
    for (int r = 1; r <= lastRow; ++r) {
        for (int c = 1; c <= lastCol; ++c) {
            std::string ref = makeRef(r - 1, c - 1);
            EvalResult ev = GridManager::getInstance().evaluateCell(ref);
            if (std::holds_alternative<std::string>(ev)) matrix[r][c - 1] = std::get<std::string>(ev);
            else if (std::holds_alternative<double>(ev)) matrix[r][c - 1] = std::to_string(std::get<double>(ev));
        }
    }

    auto isoRes = Filters::SubtotalIsolator::getInstance().isolateSubtotals(matrix, true);
    GridManager::getInstance().clearGrid();
    for (size_t r = 1; r < isoRes.cleanGrid.size(); ++r) {
        for (size_t c = 0; c < isoRes.cleanGrid[r].size(); ++c) {
            if (!isoRes.cleanGrid[r][c].empty()) {
                std::string ref = makeRef(static_cast<int>(r - 1), static_cast<int>(c));
                GridManager::getInstance().setCellConstantString(ref, isoRes.cleanGrid[r][c]);
            }
        }
    }
    return JS_NewInt32(ctx, isoRes.removedNoiseRowsCount);
}

static JSValue js_sheet_alignShiftedRows(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    int lastRow = GridManager::getInstance().getLastRow();
    int lastCol = GridManager::getInstance().getLastColumn();
    if (lastRow <= 1) return JS_NewInt32(ctx, 0);

    std::vector<std::vector<std::string>> matrix(lastRow + 1, std::vector<std::string>(lastCol, ""));
    for (int r = 1; r <= lastRow; ++r) {
        for (int c = 1; c <= lastCol; ++c) {
            std::string ref = makeRef(r - 1, c - 1);
            EvalResult ev = GridManager::getInstance().evaluateCell(ref);
            if (std::holds_alternative<std::string>(ev)) matrix[r][c - 1] = std::get<std::string>(ev);
            else if (std::holds_alternative<double>(ev)) matrix[r][c - 1] = std::to_string(std::get<double>(ev));
        }
    }

    auto aligned = Filters::RowAligner::getInstance().alignGrid(matrix, true);
    for (size_t r = 1; r < aligned.size(); ++r) {
        for (size_t c = 0; c < aligned[r].size(); ++c) {
            std::string ref = makeRef(static_cast<int>(r - 1), static_cast<int>(c));
            GridManager::getInstance().setCellConstantString(ref, aligned[r][c]);
        }
    }
    return JS_NewInt32(ctx, 1);
}

static JSValue js_sheet_cleanColumn(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string colLetter = "A";
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { colLetter = s; JS_FreeCString(ctx, s); }
    }
    for (char& ch : colLetter) ch = std::toupper((unsigned char)ch);

    int lastRow = GridManager::getInstance().getLastRow();
    if (lastRow < 2) return JS_NewInt32(ctx, 0);

    std::vector<std::string> values;
    for (int r = 2; r <= lastRow; ++r) {
        std::string ref = colLetter + std::to_string(r);
        EvalResult ev = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<std::string>(ev)) values.push_back(std::get<std::string>(ev));
        else values.push_back("");
    }

    auto cleaned = Filters::DataCleaner::getInstance().cleanColumn(values);
    int count = 0;
    for (size_t i = 0; i < cleaned.size(); ++i) {
        if (!cleaned[i].empty() && cleaned[i] != values[i]) {
            std::string ref = colLetter + std::to_string(i + 2);
            GridManager::getInstance().setCellConstantString(ref, cleaned[i]);
            count++;
        }
    }
    return JS_NewInt32(ctx, count);
}

static JSValue js_sheet_flattenMultiTierHeaders(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    int maxRows = 3;
    if (argc >= 1) JS_ToInt32(ctx, &maxRows, argv[0]);
    if (maxRows < 2) maxRows = 2;
    int lastCol = GridManager::getInstance().getLastColumn();
    if (lastCol < 1) return JS_NewInt32(ctx, 0);

    std::vector<std::vector<std::string>> headerRows;
    for (int r = 1; r <= maxRows; ++r) {
        std::vector<std::string> row;
        for (int c = 1; c <= lastCol; ++c) {
            std::string ref = makeRef(r - 1, c - 1);
            EvalResult ev = GridManager::getInstance().evaluateCell(ref);
            if (std::holds_alternative<std::string>(ev)) row.push_back(std::get<std::string>(ev));
            else if (std::holds_alternative<double>(ev)) row.push_back(std::to_string(static_cast<int>(std::get<double>(ev))));
            else row.push_back("");
        }
        headerRows.push_back(row);
    }

    auto res = Filters::HeaderFlattener::getInstance().flatten(headerRows);
    if (res.wasMultiLevel) {
        for (size_t c = 0; c < res.flattenedHeaders.size(); ++c) {
            GridManager::getInstance().setCellConstantString(makeRef(0, static_cast<int>(c)), res.flattenedHeaders[c]);
        }
    }
    return JS_NewInt32(ctx, res.wasMultiLevel ? res.headerRowCount : 1);
}

static JSValue js_sheet_fixMojibake(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string colLetter = "A";
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { colLetter = s; JS_FreeCString(ctx, s); }
    }
    for (char& ch : colLetter) ch = std::toupper((unsigned char)ch);

    int lastRow = GridManager::getInstance().getLastRow();
    if (lastRow < 2) return JS_NewInt32(ctx, 0);

    int fixedCount = 0;
    for (int r = 2; r <= lastRow; ++r) {
        std::string ref = colLetter + std::to_string(r);
        EvalResult ev = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<std::string>(ev)) {
            std::string val = std::get<std::string>(ev);
            std::string cleaned = Filters::MojibakeCleaner::getInstance().clean(val);
            if (cleaned != val) {
                GridManager::getInstance().setCellConstantString(ref, cleaned);
                fixedCount++;
            }
        }
    }
    return JS_NewInt32(ctx, fixedCount);
}

static JSValue js_sheet_imputeGaps(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string colLetter = "A";
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { colLetter = s; JS_FreeCString(ctx, s); }
    }
    for (char& ch : colLetter) ch = std::toupper((unsigned char)ch);

    std::string methodStr = "linear";
    if (argc >= 2 && JS_IsString(argv[1])) {
        const char *m = JS_ToCString(ctx, argv[1]);
        if (m) { methodStr = m; JS_FreeCString(ctx, m); }
    }

    Filters::ImputationMethod method = Filters::ImputationMethod::LINEAR_INTERPOLATE;
    if (methodStr == "ffill" || methodStr == "forward") method = Filters::ImputationMethod::FORWARD_FILL;
    else if (methodStr == "bfill" || methodStr == "backward") method = Filters::ImputationMethod::BACKWARD_FILL;
    else if (methodStr == "mean") method = Filters::ImputationMethod::MEAN;
    else if (methodStr == "median") method = Filters::ImputationMethod::MEDIAN;
    else if (methodStr == "mode") method = Filters::ImputationMethod::MODE;

    int lastRow = GridManager::getInstance().getLastRow();
    if (lastRow < 2) return JS_NewInt32(ctx, 0);

    std::vector<std::string> values;
    for (int r = 2; r <= lastRow; ++r) {
        std::string ref = colLetter + std::to_string(r);
        EvalResult ev = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<std::string>(ev)) values.push_back(std::get<std::string>(ev));
        else if (std::holds_alternative<double>(ev)) values.push_back(std::to_string(std::get<double>(ev)));
        else values.push_back("");
    }

    auto rep = Filters::ImputationEngine::getInstance().impute(values, method);
    for (size_t i = 0; i < rep.resultValues.size(); ++i) {
        if (rep.resultValues[i] != values[i]) {
            std::string ref = colLetter + std::to_string(i + 2);
            GridManager::getInstance().setCellConstantString(ref, rep.resultValues[i]);
        }
    }
    return JS_NewInt32(ctx, rep.filledCount);
}

static JSValue js_sheet_understandSheet(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    auto aiCtx = Filters::ContextCompressor::getInstance().compress();
    std::string jsonStr = aiCtx.toJson();
    return JS_ParseJSON(ctx, jsonStr.c_str(), jsonStr.size(), "<sheet_brain>");
}

static JSValue js_sheet_findClusters(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string colLetter = "A";
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { colLetter = s; JS_FreeCString(ctx, s); }
    }
    for (char& ch : colLetter) ch = std::toupper((unsigned char)ch);

    double threshold = 0.85;
    if (argc >= 2 && JS_IsNumber(argv[1])) {
        JS_ToFloat64(ctx, &threshold, argv[1]);
    }

    int lastRow = GridManager::getInstance().getLastRow();
    if (lastRow < 2) return JS_ParseJSON(ctx, "{\"clusters\":[]}", 15, "<clusters>");

    std::vector<std::string> values;
    for (int r = 2; r <= lastRow; ++r) {
        std::string ref = colLetter + std::to_string(r);
        EvalResult ev = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<std::string>(ev)) values.push_back(std::get<std::string>(ev));
        else values.push_back("");
    }

    auto res = Filters::ClusterEngine::getInstance().cluster(values, colLetter, static_cast<float>(threshold));
    std::string jsonStr = res.toJson();
    return JS_ParseJSON(ctx, jsonStr.c_str(), jsonStr.size(), "<clusters>");
}

static JSValue js_sheet_normalizeDates(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string colLetter = "A";
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { colLetter = s; JS_FreeCString(ctx, s); }
    }
    for (char& ch : colLetter) ch = std::toupper((unsigned char)ch);

    std::string outFmt = "YYYY-MM-DD";
    if (argc >= 2 && JS_IsString(argv[1])) {
        const char *f = JS_ToCString(ctx, argv[1]);
        if (f) { outFmt = f; JS_FreeCString(ctx, f); }
    }

    int lastRow = GridManager::getInstance().getLastRow();
    if (lastRow < 2) return JS_NewInt32(ctx, 0);

    std::vector<std::string> values;
    for (int r = 2; r <= lastRow; ++r) {
        std::string ref = colLetter + std::to_string(r);
        EvalResult ev = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<std::string>(ev)) values.push_back(std::get<std::string>(ev));
        else values.push_back("");
    }

    auto cleaned = Filters::DateCleaner::getInstance().cleanColumnConsensus(values, outFmt);
    int count = 0;
    for (size_t i = 0; i < cleaned.size(); ++i) {
        if (!cleaned[i].empty() && cleaned[i] != values[i]) {
            std::string ref = colLetter + std::to_string(i + 2);
            GridManager::getInstance().setCellConstantString(ref, cleaned[i]);
            count++;
        }
    }
    return JS_NewInt32(ctx, count);
}

static JSValue js_spreadsheetapp_parseAddress(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsString(argv[0])) return JS_NULL;
    const char *s = JS_ToCString(ctx, argv[0]);
    if (!s) return JS_NULL;
    std::string text(s); JS_FreeCString(ctx, s);

    auto parsed = Filters::AddressCleaner::getInstance().parse(text);
    JSValue obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, obj, "pincode", JS_NewString(ctx, parsed.pincode.c_str()));
    JS_SetPropertyStr(ctx, obj, "city", JS_NewString(ctx, parsed.city.c_str()));
    JS_SetPropertyStr(ctx, obj, "state", JS_NewString(ctx, parsed.state.c_str()));
    JS_SetPropertyStr(ctx, obj, "country", JS_NewString(ctx, parsed.country.c_str()));
    JS_SetPropertyStr(ctx, obj, "cleanAddress", JS_NewString(ctx, parsed.cleanAddress.c_str()));
    JS_SetPropertyStr(ctx, obj, "isValid", JS_NewBool(ctx, parsed.isValid));
    return obj;
}

static JSValue js_spreadsheetapp_convertUnit(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsString(argv[0])) return JS_NULL;
    const char *s = JS_ToCString(ctx, argv[0]);
    if (!s) return JS_NULL;
    std::string text(s); JS_FreeCString(ctx, s);
    std::string targetUnit = "";
    if (argc >= 2 && JS_IsString(argv[1])) {
        const char *t = JS_ToCString(ctx, argv[1]);
        if (t) { targetUnit = t; JS_FreeCString(ctx, t); }
    }

    std::string converted = Filters::UnitCleaner::getInstance().cleanAndConvert(text, targetUnit);
    return JS_NewString(ctx, converted.c_str());
}

static JSValue js_spreadsheetapp_analyzeEmail(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc < 1 || !JS_IsString(argv[0])) return JS_NULL;
    const char *s = JS_ToCString(ctx, argv[0]);
    if (!s) return JS_NULL;
    std::string text(s); JS_FreeCString(ctx, s);

    auto meta = Filters::EmailCleaner::analyzeAndNormalize(text);
    JSValue obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, obj, "originalEmail", JS_NewString(ctx, meta.originalEmail.c_str()));
    JS_SetPropertyStr(ctx, obj, "rawCleanedEmail", JS_NewString(ctx, meta.rawCleanedEmail.c_str()));
    JS_SetPropertyStr(ctx, obj, "normalizedEmail", JS_NewString(ctx, meta.normalizedEmail.c_str()));
    JS_SetPropertyStr(ctx, obj, "localPart", JS_NewString(ctx, meta.localPart.c_str()));
    JS_SetPropertyStr(ctx, obj, "domain", JS_NewString(ctx, meta.domain.c_str()));
    JS_SetPropertyStr(ctx, obj, "tld", JS_NewString(ctx, meta.tld.c_str()));
    JS_SetPropertyStr(ctx, obj, "provider", JS_NewString(ctx, meta.provider.c_str()));
    JS_SetPropertyStr(ctx, obj, "isValid", JS_NewBool(ctx, meta.isValid));
    JS_SetPropertyStr(ctx, obj, "isDisposable", JS_NewBool(ctx, meta.isDisposable));
    JS_SetPropertyStr(ctx, obj, "hasPlusAlias", JS_NewBool(ctx, meta.hasPlusAlias));
    JS_SetPropertyStr(ctx, obj, "confidenceScore", JS_NewInt32(ctx, meta.confidenceScore));
    return obj;
}

static JSValue createSheetObj(JSContext *ctx, const std::string& sheetName) {
    JSValue obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, obj, "name", JS_NewString(ctx, sheetName.c_str()));
    JS_SetPropertyStr(ctx, obj, "getRange", JS_NewCFunction(ctx, js_sheet_getRange, "getRange", 4));
    JS_SetPropertyStr(ctx, obj, "getLastRow", JS_NewCFunction(ctx, js_sheet_getLastRow, "getLastRow", 0));
    JS_SetPropertyStr(ctx, obj, "getLastColumn", JS_NewCFunction(ctx, js_sheet_getLastColumn, "getLastColumn", 0));
    JS_SetPropertyStr(ctx, obj, "getDataRange", JS_NewCFunction(ctx, js_sheet_getDataRange, "getDataRange", 0));
    JS_SetPropertyStr(ctx, obj, "clear", JS_NewCFunction(ctx, js_sheet_clear, "clear", 0));
    JS_SetPropertyStr(ctx, obj, "appendRow", JS_NewCFunction(ctx, js_sheet_appendRow, "appendRow", 1));
    JS_SetPropertyStr(ctx, obj, "getMaxRows", JS_NewCFunction(ctx, js_sheet_getMaxRows, "getMaxRows", 0));
    JS_SetPropertyStr(ctx, obj, "getMaxColumns", JS_NewCFunction(ctx, js_sheet_getMaxColumns, "getMaxColumns", 0));
    JS_SetPropertyStr(ctx, obj, "getName", JS_NewCFunction(ctx, js_sheet_getName, "getName", 0));
    JS_SetPropertyStr(ctx, obj, "getSheetName", JS_NewCFunction(ctx, js_sheet_getName, "getSheetName", 0));
    JS_SetPropertyStr(ctx, obj, "getSheetId", JS_NewCFunction(ctx, js_sheet_getSheetId, "getSheetId", 0));
    JS_SetPropertyStr(ctx, obj, "insertRows", JS_NewCFunction(ctx, js_sheet_insertRows, "insertRows", 2));
    JS_SetPropertyStr(ctx, obj, "deleteRows", JS_NewCFunction(ctx, js_sheet_deleteRows, "deleteRows", 2));
    JS_SetPropertyStr(ctx, obj, "insertColumns", JS_NewCFunction(ctx, js_sheet_insertColumns, "insertColumns", 2));
    JS_SetPropertyStr(ctx, obj, "deleteColumns", JS_NewCFunction(ctx, js_sheet_deleteColumns, "deleteColumns", 2));
    JS_SetPropertyStr(ctx, obj, "setColumnWidth", JS_NewCFunction(ctx, js_sheet_setColumnWidth, "setColumnWidth", 2));
    JS_SetPropertyStr(ctx, obj, "setRowHeight", JS_NewCFunction(ctx, js_sheet_setRowHeight, "setRowHeight", 2));
    JS_SetPropertyStr(ctx, obj, "getActiveCell", JS_NewCFunction(ctx, js_sheet_getActiveCell, "getActiveCell", 0));
    JS_SetPropertyStr(ctx, obj, "getActiveSheet", JS_NewCFunction(ctx, js_spreadsheetapp_getActiveSheet, "getActiveSheet", 0));
    JS_SetPropertyStr(ctx, obj, "getSheets", JS_NewCFunction(ctx, js_sheet_getSheets, "getSheets", 0));

    // SOTA Data Cleaning & Smart Tools
    JS_SetPropertyStr(ctx, obj, "stitchMultiLineRecords", JS_NewCFunction(ctx, js_sheet_stitchMultiLineRecords, "stitchMultiLineRecords", 0));
    JS_SetPropertyStr(ctx, obj, "demixColumn", JS_NewCFunction(ctx, js_sheet_demixColumn, "demixColumn", 1));
    JS_SetPropertyStr(ctx, obj, "isolateSubtotals", JS_NewCFunction(ctx, js_sheet_isolateSubtotals, "isolateSubtotals", 0));
    JS_SetPropertyStr(ctx, obj, "alignShiftedRows", JS_NewCFunction(ctx, js_sheet_alignShiftedRows, "alignShiftedRows", 0));
    JS_SetPropertyStr(ctx, obj, "cleanColumn", JS_NewCFunction(ctx, js_sheet_cleanColumn, "cleanColumn", 1));
    JS_SetPropertyStr(ctx, obj, "flattenMultiTierHeaders", JS_NewCFunction(ctx, js_sheet_flattenMultiTierHeaders, "flattenMultiTierHeaders", 1));
    JS_SetPropertyStr(ctx, obj, "fixMojibake", JS_NewCFunction(ctx, js_sheet_fixMojibake, "fixMojibake", 1));
    JS_SetPropertyStr(ctx, obj, "imputeGaps", JS_NewCFunction(ctx, js_sheet_imputeGaps, "imputeGaps", 2));
    JS_SetPropertyStr(ctx, obj, "understandSheet", JS_NewCFunction(ctx, js_sheet_understandSheet, "understandSheet", 0));
    JS_SetPropertyStr(ctx, obj, "findClusters", JS_NewCFunction(ctx, js_sheet_findClusters, "findClusters", 2));
    JS_SetPropertyStr(ctx, obj, "normalizeDates", JS_NewCFunction(ctx, js_sheet_normalizeDates, "normalizeDates", 2));
    return obj;
}

// SpreadsheetApp.getActiveSpreadsheet() / getActiveSheet()
static JSValue js_spreadsheetapp_getActiveSheet(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return createSheetObj(ctx, JsEngine::getInstance().getActiveSheetName());
}

static JSValue js_spreadsheetapp_createChart(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) {
            std::string config(s);
            std::string action = "{\"action\":\"create_chart\",\"config\":" + config + "}";
            JsEngine::getInstance().enqueueUiAction(action);
            JS_FreeCString(ctx, s);
        }
    }
    return JS_UNDEFINED;
}

static JSValue js_spreadsheetapp_createPivotTable(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) {
            std::string config(s);
            std::string action = "{\"action\":\"create_pivot\",\"config\":" + config + "}";
            JsEngine::getInstance().enqueueUiAction(action);
            JS_FreeCString(ctx, s);
        }
    }
    return JS_UNDEFINED;
}

void JsEngine::bindNativeApis() {
    if (!m_ctx) return;
    bindConsole();
    bindSpreadsheetApp();
    bindFetch();
}

void JsEngine::bindConsole() {
    JSValue globalObj = JS_GetGlobalObject(m_ctx);
    JSValue consoleObj = JS_NewObject(m_ctx);
    JS_SetPropertyStr(m_ctx, consoleObj, "log", JS_NewCFunction(m_ctx, js_console_log, "log", 1));
    JS_SetPropertyStr(m_ctx, consoleObj, "warn", JS_NewCFunction(m_ctx, js_console_log, "warn", 1));
    JS_SetPropertyStr(m_ctx, consoleObj, "error", JS_NewCFunction(m_ctx, js_console_log, "error", 1));
    JS_SetPropertyStr(m_ctx, consoleObj, "info", JS_NewCFunction(m_ctx, js_console_log, "info", 1));
    JS_SetPropertyStr(m_ctx, globalObj, "console", consoleObj);
    
    // Logger.log (Google Apps Script style)
    JSValue loggerObj = JS_NewObject(m_ctx);
    JS_SetPropertyStr(m_ctx, loggerObj, "log", JS_NewCFunction(m_ctx, js_console_log, "log", 1));
    JS_SetPropertyStr(m_ctx, globalObj, "Logger", loggerObj);
    
    JS_FreeValue(m_ctx, globalObj);
}

static JSValue js_spreadsheetapp_insertSheet(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string sheetName = "Sheet" + std::to_string(JsEngine::getInstance().getSheetNames().size() + 1);
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { sheetName = s; JS_FreeCString(ctx, s); }
    }
    JsEngine::getInstance().addSheet(sheetName);
    
    // Dispatch UI Action for Dart
    std::string action = "{\"action\":\"insertSheet\",\"name\":\"" + sheetName + "\"}";
    JsEngine::getInstance().enqueueUiAction(action);
    
    return createSheetObj(ctx, sheetName);
}

static JSValue js_spreadsheetapp_renameActiveSheet(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) {
            std::string newName(s);
            JsEngine::getInstance().renameActiveSheet(newName);
            
            // Dispatch UI Action for Dart
            std::string action = "{\"action\":\"renameSheet\",\"name\":\"" + newName + "\"}";
            JsEngine::getInstance().enqueueUiAction(action);
            
            JS_FreeCString(ctx, s);
            return createSheetObj(ctx, newName);
        }
    }
    return JS_UNDEFINED;
}

static JSValue js_spreadsheetapp_getSheetByName(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    std::string targetName = "Sheet1";
    if (argc >= 1 && JS_IsString(argv[0])) {
        const char *s = JS_ToCString(ctx, argv[0]);
        if (s) { targetName = s; JS_FreeCString(ctx, s); }
    }
    
    const auto& sheets = JsEngine::getInstance().getSheetNames();
    if (std::find(sheets.begin(), sheets.end(), targetName) != sheets.end()) {
        return createSheetObj(ctx, targetName);
    }
    
    return JS_NULL;
}

static JSValue js_spreadsheetapp_setActiveSheet(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    if (argc >= 1 && JS_IsObject(argv[0])) {
        return argv[0];
    }
    return JS_UNDEFINED;
}

static JSValue js_spreadsheetapp_deleteSheet(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv) {
    return JS_UNDEFINED;
}

void JsEngine::bindSpreadsheetApp() {
    JSValue globalObj = JS_GetGlobalObject(m_ctx);
    JSValue appObj = JS_NewObject(m_ctx);
    
    JS_SetPropertyStr(m_ctx, appObj, "getActiveSheet", JS_NewCFunction(m_ctx, js_spreadsheetapp_getActiveSheet, "getActiveSheet", 0));
    JS_SetPropertyStr(m_ctx, appObj, "getActiveSpreadsheet", JS_NewCFunction(m_ctx, js_spreadsheetapp_getActiveSheet, "getActiveSpreadsheet", 0));
    JS_SetPropertyStr(m_ctx, appObj, "insertSheet", JS_NewCFunction(m_ctx, js_spreadsheetapp_insertSheet, "insertSheet", 1));
    JS_SetPropertyStr(m_ctx, appObj, "renameActiveSheet", JS_NewCFunction(m_ctx, js_spreadsheetapp_renameActiveSheet, "renameActiveSheet", 1));
    JS_SetPropertyStr(m_ctx, appObj, "getSheetByName", JS_NewCFunction(m_ctx, js_spreadsheetapp_getSheetByName, "getSheetByName", 1));
    JS_SetPropertyStr(m_ctx, appObj, "getSheets", JS_NewCFunction(m_ctx, js_sheet_getSheets, "getSheets", 0));
    JS_SetPropertyStr(m_ctx, appObj, "setActiveSheet", JS_NewCFunction(m_ctx, js_spreadsheetapp_setActiveSheet, "setActiveSheet", 1));
    JS_SetPropertyStr(m_ctx, appObj, "deleteSheet", JS_NewCFunction(m_ctx, js_spreadsheetapp_deleteSheet, "deleteSheet", 1));
    JS_SetPropertyStr(m_ctx, appObj, "createChart", JS_NewCFunction(m_ctx, js_spreadsheetapp_createChart, "createChart", 1));
    JS_SetPropertyStr(m_ctx, appObj, "createPivotTable", JS_NewCFunction(m_ctx, js_spreadsheetapp_createPivotTable, "createPivotTable", 1));
    JS_SetPropertyStr(m_ctx, appObj, "stitchMultiLineRecords", JS_NewCFunction(m_ctx, js_sheet_stitchMultiLineRecords, "stitchMultiLineRecords", 0));
    JS_SetPropertyStr(m_ctx, appObj, "demixColumn", JS_NewCFunction(m_ctx, js_sheet_demixColumn, "demixColumn", 1));
    JS_SetPropertyStr(m_ctx, appObj, "isolateSubtotals", JS_NewCFunction(m_ctx, js_sheet_isolateSubtotals, "isolateSubtotals", 0));
    JS_SetPropertyStr(m_ctx, appObj, "alignShiftedRows", JS_NewCFunction(m_ctx, js_sheet_alignShiftedRows, "alignShiftedRows", 0));
    JS_SetPropertyStr(m_ctx, appObj, "cleanColumn", JS_NewCFunction(m_ctx, js_sheet_cleanColumn, "cleanColumn", 1));
    JS_SetPropertyStr(m_ctx, appObj, "flattenMultiTierHeaders", JS_NewCFunction(m_ctx, js_sheet_flattenMultiTierHeaders, "flattenMultiTierHeaders", 1));
    JS_SetPropertyStr(m_ctx, appObj, "fixMojibake", JS_NewCFunction(m_ctx, js_sheet_fixMojibake, "fixMojibake", 1));
    JS_SetPropertyStr(m_ctx, appObj, "imputeGaps", JS_NewCFunction(m_ctx, js_sheet_imputeGaps, "imputeGaps", 2));
    JS_SetPropertyStr(m_ctx, appObj, "understandSheet", JS_NewCFunction(m_ctx, js_sheet_understandSheet, "understandSheet", 0));
    JS_SetPropertyStr(m_ctx, appObj, "findClusters", JS_NewCFunction(m_ctx, js_sheet_findClusters, "findClusters", 2));
    JS_SetPropertyStr(m_ctx, appObj, "normalizeDates", JS_NewCFunction(m_ctx, js_sheet_normalizeDates, "normalizeDates", 2));
    JS_SetPropertyStr(m_ctx, appObj, "parseAddress", JS_NewCFunction(m_ctx, js_spreadsheetapp_parseAddress, "parseAddress", 1));
    JS_SetPropertyStr(m_ctx, appObj, "convertUnit", JS_NewCFunction(m_ctx, js_spreadsheetapp_convertUnit, "convertUnit", 2));
    JS_SetPropertyStr(m_ctx, appObj, "analyzeEmail", JS_NewCFunction(m_ctx, js_spreadsheetapp_analyzeEmail, "analyzeEmail", 1));

    JS_SetPropertyStr(m_ctx, globalObj, "SpreadsheetApp", appObj);
    JS_FreeValue(m_ctx, globalObj);
}


void JsEngine::bindFetch() {
    JSValue globalObj = JS_GetGlobalObject(m_ctx);
    JS_SetPropertyStr(m_ctx, globalObj, "fetch", JS_NewCFunction(m_ctx, js_fetch, "fetch", 2));
    JS_FreeValue(m_ctx, globalObj);
}

// -------------------------------------------------------------
// Script Execution Methods
// -------------------------------------------------------------

std::string JsEngine::evalScript(const std::string& code) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (!init()) return "Error: Engine not initialized";

    // 🛡️ IIFE Wrapper to support top-level return statements in AI/User scripts
    std::string wrappedCode = "(function() {\n" + code + "\n})();";
    JSValue val = JS_Eval(m_ctx, wrappedCode.c_str(), wrappedCode.size(), "<user_script>", JS_EVAL_TYPE_GLOBAL);

    
    if (JS_IsException(val)) {
        JSValue exception_val = JS_GetException(m_ctx);
        const char* errStr = JS_ToCString(m_ctx, exception_val);
        std::string err(errStr ? errStr : "Unknown error");
        if (errStr) JS_FreeCString(m_ctx, errStr);
        JS_FreeValue(m_ctx, exception_val);
        JS_FreeValue(m_ctx, val);
        
        std::string consoleOut = popConsoleOutput();
        std::string escapedErr = err;
        // Escape quotes for JSON
        size_t pos = 0;
        while ((pos = escapedErr.find('"', pos)) != std::string::npos) { escapedErr.replace(pos, 1, "\\\""); pos += 2; }
        while ((pos = escapedErr.find('\n', pos)) != std::string::npos) { escapedErr.replace(pos, 1, "\\n"); pos += 2; }
        
        std::string escapedConsole = consoleOut;
        pos = 0; while ((pos = escapedConsole.find('"', pos)) != std::string::npos) { escapedConsole.replace(pos, 1, "\\\""); pos += 2; }
        pos = 0; while ((pos = escapedConsole.find('\n', pos)) != std::string::npos) { escapedConsole.replace(pos, 1, "\\n"); pos += 2; }
        
        return "{\"error\":\"" + escapedErr + "\",\"console\":\"" + escapedConsole + "\"}";
    }

    // Calculate grid once after script execution completes
    GridManager::getInstance().calculateAll();

    const char* str = JS_ToCString(m_ctx, val);
    std::string result(str ? str : "undefined");
    if (str) JS_FreeCString(m_ctx, str);
    JS_FreeValue(m_ctx, val);
    
    std::string consoleOut = popConsoleOutput();
    
    // JSON escape
    std::string escapedResult = result;
    size_t pos = 0;
    while ((pos = escapedResult.find('"', pos)) != std::string::npos) { escapedResult.replace(pos, 1, "\\\""); pos += 2; }
    pos = 0; while ((pos = escapedResult.find('\n', pos)) != std::string::npos) { escapedResult.replace(pos, 1, "\\n"); pos += 2; }
    
    std::string escapedConsole = consoleOut;
    pos = 0; while ((pos = escapedConsole.find('"', pos)) != std::string::npos) { escapedConsole.replace(pos, 1, "\\\""); pos += 2; }
    pos = 0; while ((pos = escapedConsole.find('\n', pos)) != std::string::npos) { escapedConsole.replace(pos, 1, "\\n"); pos += 2; }
    
    // Flush UI Actions
    std::vector<std::string> uiActions = flushUiActions();
    std::string uiActionsJson = "[";
    for (size_t i = 0; i < uiActions.size(); ++i) {
        uiActionsJson += uiActions[i];
        if (i < uiActions.size() - 1) uiActionsJson += ",";
    }
    uiActionsJson += "]";
    
    return "{\"result\":\"" + escapedResult + "\",\"console\":\"" + escapedConsole + "\",\"ui_actions\":" + uiActionsJson + "}";
}

std::string JsEngine::callJsFunction(const std::string& funcName, const std::vector<std::string>& jsonArgs) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (!init()) return "Error: Engine not initialized";

    JSValue globalObj = JS_GetGlobalObject(m_ctx);
    JSValue funcVal = JS_GetPropertyStr(m_ctx, globalObj, funcName.c_str());
    JS_FreeValue(m_ctx, globalObj);

    if (!JS_IsFunction(m_ctx, funcVal)) {
        JS_FreeValue(m_ctx, funcVal);
        return "Error: Function " + funcName + " not found";
    }

    std::vector<JSValue> args;
    for (const auto& argJson : jsonArgs) {
        JSValue argVal = JS_ParseJSON(m_ctx, argJson.c_str(), argJson.size(), "<arg>");
        if (JS_IsException(argVal)) {
            argVal = JS_NewString(m_ctx, argJson.c_str());
        }
        args.push_back(argVal);
    }

    JSValue resVal = JS_Call(m_ctx, funcVal, JS_UNDEFINED, args.size(), args.data());
    
    for (auto& a : args) JS_FreeValue(m_ctx, a);
    JS_FreeValue(m_ctx, funcVal);

    if (JS_IsException(resVal)) {
        JSValue exceptionVal = JS_GetException(m_ctx);
        const char *str = JS_ToCString(m_ctx, exceptionVal);
        std::string err = "JS Error: ";
        if (str) {
            err += str;
            JS_FreeCString(m_ctx, str);
        }
        JS_FreeValue(m_ctx, exceptionVal);
        JS_FreeValue(m_ctx, resVal);
        return err;
    }

    const char *resCStr = JS_ToCString(m_ctx, resVal);
    std::string resStr = resCStr ? resCStr : "";
    if (resCStr) JS_FreeCString(m_ctx, resCStr);
    JS_FreeValue(m_ctx, resVal);

    return resStr;
}

bool JsEngine::registerMacro(const std::string& name, const std::string& code) {
    m_userMacros[name] = code;
    evalScript(code);
    return true;
}

std::vector<std::string> JsEngine::getMacroNames() {
    std::vector<std::string> names;
    for (const auto& kv : m_userMacros) {
        names.push_back(kv.first);
    }
    return names;
}

std::string JsEngine::getMacroCode(const std::string& name) {
    if (m_userMacros.count(name)) return m_userMacros[name];
    return "";
}

void JsEngine::triggerOnEdit(const std::string& sheetName, const std::string& cellRef, const std::string& oldValue, const std::string& newValue) {
    std::ostringstream jsonStream;
    jsonStream << "{\"sheet\":\"" << sheetName << "\",\"range\":\"" << cellRef << "\",\"oldValue\":\"" << oldValue << "\",\"value\":\"" << newValue << "\"}";
    callJsFunction("onEdit", {jsonStream.str()});
}

void JsEngine::triggerOnChange(const std::string& changeType) {
    std::ostringstream jsonStream;
    jsonStream << "{\"type\":\"" << changeType << "\"}";
    callJsFunction("onChange", {jsonStream.str()});
}

void JsEngine::setFetchCallback(DartFetchCallbackFn callback) {
    m_fetchCallback = callback;
}

void JsEngine::enqueueUiAction(const std::string& actionJson) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_uiActionQueue.push_back(actionJson);
}

std::vector<std::string> JsEngine::flushUiActions() {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    std::vector<std::string> actions = std::move(m_uiActionQueue);
    m_uiActionQueue.clear();
    return actions;
}
