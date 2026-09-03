#include "spreadsheet_compute.h"
#include "parser.h"
#include "evaluator.h"
#include "grid_manager.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <mutex>
#include <android/log.h>
#include "conditional_formatting/cf_manager.h"
#include "conditional_formatting/cf_rule.h"
#include "conditional_formatting/rule_evaluator.h"
#include "js_engine.h"
#include "data_engine/engine/filter_engine.h"
#include "data_engine/rules/phone_filter.h"
#include "data_engine/detector/data_detector.h"
#include "data_engine/engine/pipeline_executor.h"
#include "data_engine/pipeline/pipeline_registry.h"
#include "data_engine/pipeline/steps/filter_step.h"
#include "data_engine/pipeline/steps/fill_data_step.h"
#include "data_engine/pipeline/steps/script_step.h"
// --- Data Intelligence Engine (data_engine/analyzer/ + data_engine/cleaning/ + data_engine/validator/) ---
#include "data_engine/analyzer/column_analyzer.h"
#include "data_engine/analyzer/sheet_summarizer.h"
#include "data_engine/cleaning/data_cleaner.h"
#include "data_engine/cleaning/email_cleaner.h"
#include "data_engine/cleaning/date_cleaner.h"
#include "data_engine/cleaning/extreme_cleaning_engine.h"
#include "data_engine/cleaning/row_aligner.h"
#include "data_engine/cleaning/record_stitcher.h"
#include "data_engine/cleaning/mixed_cell_demixer.h"
#include "data_engine/cleaning/name_from_email_cleaner.h"
#include "data_engine/cleaning/guarded_fill_down.h"
#include "data_engine/analyzer/subtotal_isolator.h"
#include "data_engine/tests/test_runner.h"

#include "data_engine/validator/phone_validator.h"
#include "data_engine/validator/email_validator.h"
#include "data_engine/validator/gst_validator.h"
#include "data_engine/validator/aadhaar_validator.h"
#include "data_engine/validator/date_validator.h"
// --- Phase 3: Sheet Brain modules ---
// Context Compressor: brain/context_compressor.h
// Fuzzy Cluster Engine: cluster/cluster_engine.h
// Semantic Detector: semantic/semantic_detector.h
#include "data_engine/brain/context_compressor.h"
#include "data_engine/cluster/cluster_engine.h"
#include "data_engine/semantic/semantic_detector.h"
#include <sstream>

class ClearSheetStep : public DataPipeline::IPipelineStep {
public:
    std::string getName() const override { return "ClearSheet"; }
    void configure(const nlohmann::json& config) override {}
    DataPipeline::PipelineResult execute(DataPipeline::PipelineContext& ctx) override {
        GridManager::getInstance().clearGrid();
        return {DataPipeline::ExecutionStatus::SUCCESS, 0, "Sheet cleared successfully", -1};
    }
};

class PassThroughStep : public DataPipeline::IPipelineStep {
public:
    std::string getName() const override { return "PassThrough"; }
    void configure(const nlohmann::json& config) override {}
    DataPipeline::PipelineResult execute(DataPipeline::PipelineContext& ctx) override {
        return {DataPipeline::ExecutionStatus::SUCCESS, 0, "Step executed successfully", -1};
    }
};

#ifdef __cplusplus
extern "C" {
#endif

// Global instance of the compute engine
SpreadsheetCompute* g_computeEngine = nullptr;
ConditionalFormatting::CFManager* g_cfManager = nullptr;

// Unified FFI String Allocator (compatible with freeString / Dart _freeString)
static char* allocFfiString(const std::string& str) {
    char* cstr = (char*)malloc(str.length() + 1);
    if (!cstr) return nullptr;
    strcpy(cstr, str.c_str());
    return cstr;
}

struct FormulaProgressState {
    int current = 0;
    int total = 0;
    bool active = false;
};

static std::mutex g_formulaProgressMutex;
static FormulaProgressState g_formulaProgressState;

static void updateFormulaProgress(int current, int total, bool active) {
    std::lock_guard<std::mutex> lock(g_formulaProgressMutex);
    g_formulaProgressState.current = current;
    g_formulaProgressState.total = total;
    g_formulaProgressState.active = active;
}

static void progressCallbackBridge(int current, int total) {
    updateFormulaProgress(current, total, true);
}

// Global environment for named ranges
std::unordered_map<std::string, EvalResult> g_namedRanges;
std::mutex g_namedRangesMutex;

#if defined(_WIN32)
#define FFI_EXPORT __declspec(dllexport)
#else
#define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

FFI_EXPORT void setNamedRange(const char* name, double value) {
    std::lock_guard<std::mutex> lock(g_namedRangesMutex);
    if (name != nullptr) {
        g_namedRanges[std::string(name)] = value;
    }
}

FFI_EXPORT void setNamedRangeString(const char* name, const char* value) {
    std::lock_guard<std::mutex> lock(g_namedRangesMutex);
    if (name != nullptr && value != nullptr) {
        g_namedRanges[std::string(name)] = std::string(value);
    }
}

FFI_EXPORT void clearNamedRanges() {
    std::lock_guard<std::mutex> lock(g_namedRangesMutex);
    g_namedRanges.clear();
}

FFI_EXPORT void initComputeEngine() {
    if (g_computeEngine == nullptr) {
        g_computeEngine = new SpreadsheetCompute();
    }
    if (g_cfManager == nullptr) {
        g_cfManager = new ConditionalFormatting::CFManager();
    }
    GridManager::getInstance().setProgressCallback(progressCallbackBridge);
    updateFormulaProgress(0, 0, false);
    
    // Register Pipeline Steps
    DataPipeline::PipelineRegistry::getInstance().registerStep("Filter", []() {
        return std::make_shared<DataPipeline::FilterStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("FillData", []() {
        return std::make_shared<DataPipeline::FillDataStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("fill_data", []() {
        return std::make_shared<DataPipeline::FillDataStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("Script", []() {
        return std::make_shared<DataPipeline::ScriptStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("script", []() {
        return std::make_shared<DataPipeline::ScriptStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("run_script", []() {
        return std::make_shared<DataPipeline::ScriptStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("clear_sheet", []() {
        return std::make_shared<ClearSheetStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("ClearSheet", []() {
        return std::make_shared<ClearSheetStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("clear", []() {
        return std::make_shared<ClearSheetStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("format_cells", []() {
        return std::make_shared<PassThroughStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("format_column", []() {
        return std::make_shared<PassThroughStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("format_row", []() {
        return std::make_shared<PassThroughStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("style", []() {
        return std::make_shared<PassThroughStep>();
    });
    DataPipeline::PipelineRegistry::getInstance().registerStep("conditional_formatting", []() {
        return std::make_shared<PassThroughStep>();
    });
}

FFI_EXPORT void cleanupComputeEngine() {
    if (g_computeEngine != nullptr) {
        delete g_computeEngine;
        g_computeEngine = nullptr;
    }
    if (g_cfManager != nullptr) {
        delete g_cfManager;
        g_cfManager = nullptr;
    }
    GridManager::getInstance().setProgressCallback(nullptr);
    updateFormulaProgress(0, 0, false);
}

FFI_EXPORT void enableGPUCompute(int enable) {
    if (g_computeEngine != nullptr) {
        g_computeEngine->enableGPUCompute(enable != 0);
    }
}

FFI_EXPORT double calculateSum(const double* values, int count) {
    if (g_computeEngine == nullptr || values == nullptr || count <= 0) return 0.0;
    std::vector<double> vec(values, values + count);
    return g_computeEngine->sumRange(vec);
}

FFI_EXPORT double calculateAverage(const double* values, int count) {
    if (g_computeEngine == nullptr || values == nullptr || count <= 0) return 0.0;
    std::vector<double> vec(values, values + count);
    return g_computeEngine->averageRange(vec);
}

FFI_EXPORT double calculateMedian(const double* values, int count) {
    if (g_computeEngine == nullptr || values == nullptr || count <= 0) return 0.0;
    std::vector<double> vec(values, values + count);
    return g_computeEngine->median(vec);
}

FFI_EXPORT double calculateStandardDeviation(const double* values, int count) {
    if (g_computeEngine == nullptr || values == nullptr || count <= 0) return 0.0;
    std::vector<double> vec(values, values + count);
    return g_computeEngine->standardDeviation(vec);
}

// Memory allocation helpers for FFI
FFI_EXPORT double* allocateDoubleArray(int count) {
    return (double*)malloc(sizeof(double) * count);
}

FFI_EXPORT void freeDoubleArray(double* ptr) {
    if (ptr != nullptr) {
        free(ptr);
    }
}

static std::string formatDouble(double val) {
    if (std::isnan(val)) return "#VALUE!";
    if (std::isinf(val)) return "#DIV/0!";
    if (val == (int64_t)val && std::abs(val) < 9007199254740992.0) {
        return std::to_string((int64_t)val);
    }
    std::string s = std::to_string(val);
    s.erase(s.find_last_not_of('0') + 1, std::string::npos);
    if (s.back() == '.') s.pop_back();
    return s;
}

// Temporary test endpoint for AST Evaluator
// Evaluates a string and returns a dynamically allocated string (must be freed by Dart)
FFI_EXPORT char* evaluateFormulaString(const char* formulaStr, int currentRow, int currentCol) {
    if (formulaStr == nullptr) return nullptr;
    
    try {
        updateFormulaProgress(0, 0, true);
        std::string formula(formulaStr);
        Tokenizer tokenizer(formula);
        auto tokens = tokenizer.tokenize();
        
        Parser parser(tokens);
        auto ast = parser.parse();
        
        Evaluator evaluator;
        evaluator.currentRow = currentRow;
        evaluator.currentCol = currentCol;
        evaluator.globalEnvironment = &g_namedRanges;
        evaluator.progressCallback = progressCallbackBridge;
        
        EvalResult result = evaluator.evaluate(ast.get());
        
        std::string resStr;
        if (std::holds_alternative<double>(result)) {
            resStr = formatDouble(std::get<double>(result));
        } else if (std::holds_alternative<std::string>(result)) {
            resStr = std::get<std::string>(result);
        } else if (std::holds_alternative<bool>(result)) {
            resStr = std::get<bool>(result) ? "TRUE" : "FALSE";
        } else if (std::holds_alternative<CellError>(result)) {
            resStr = std::get<CellError>(result).type;
        } else if (std::holds_alternative<ArrayVal>(result)) {
            // Serialize ArrayVal to {"type":"spill", "data": [[...]]}
            const auto& mat = std::get<ArrayVal>(result).matrix;
            resStr = "{\"type\":\"spill\",\"data\":[";
            for (size_t r = 0; r < mat.size(); r++) {
                resStr += "[";
                for (size_t c = 0; c < mat[r].size(); c++) {
                    const auto& cell = mat[r][c];
                    if (std::holds_alternative<double>(cell)) {
                        resStr += formatDouble(std::get<double>(cell));
                    } else if (std::holds_alternative<std::string>(cell)) {
                        resStr += "\"" + std::get<std::string>(cell) + "\"";
                    } else if (std::holds_alternative<bool>(cell)) {
                        resStr += std::get<bool>(cell) ? "true" : "false";
                    } else if (std::holds_alternative<CellError>(cell)) {
                        resStr += "\"" + std::get<CellError>(cell).type + "\"";
                    } else {
                        resStr += "\"\"";
                    }
                    if (c < mat[r].size() - 1) resStr += ",";
                }
                resStr += "]";
                if (r < mat.size() - 1) resStr += ",";
            }
            resStr += "]}";
        } else {
            resStr = "#ERROR";
        }
        updateFormulaProgress(0, 0, false);
        
        char* cStr = (char*)malloc(resStr.length() + 1);
        strcpy(cStr, resStr.c_str());
        return cStr;
    } catch (...) {
        updateFormulaProgress(0, 0, false);
        char* cStr = (char*)malloc(8);
        strcpy(cStr, "#ERROR!");
        return cStr;
    }
}

// --- Grid Manager FFI Endpoints ---

FFI_EXPORT void setCellFormula(const char* cellRef, const char* formula) {
    if (!cellRef || !formula) return;
    GridManager::getInstance().setCellFormula(cellRef, formula);
}

// Set progress callback for large array operations
FFI_EXPORT void setProgressCallback(void (*callback)(int, int)) {
    if (callback != nullptr) {
        GridManager::getInstance().setProgressCallback(callback);
    } else {
        GridManager::getInstance().setProgressCallback(progressCallbackBridge);
    }
}

FFI_EXPORT void resetFormulaProgress() {
    updateFormulaProgress(0, 0, false);
}

FFI_EXPORT int getFormulaProgressCurrent() {
    std::lock_guard<std::mutex> lock(g_formulaProgressMutex);
    return g_formulaProgressState.current;
}

FFI_EXPORT int getFormulaProgressTotal() {
    std::lock_guard<std::mutex> lock(g_formulaProgressMutex);
    return g_formulaProgressState.total;
}

FFI_EXPORT int isFormulaProgressActive() {
    std::lock_guard<std::mutex> lock(g_formulaProgressMutex);
    return g_formulaProgressState.active ? 1 : 0;
}

FFI_EXPORT void setCellConstant(const char* cellRef, double value) {
    if (!cellRef) return;
    GridManager::getInstance().setCellConstant(cellRef, value);
}

FFI_EXPORT void setCellConstantString(const char* cellRef, const char* value) {
    if (!cellRef || !value) return;
    GridManager::getInstance().setCellConstantString(cellRef, value);
}

FFI_EXPORT void clearGrid() {
    GridManager::getInstance().clearGrid();
}

FFI_EXPORT int native_getLastRow() {
    return GridManager::getInstance().getLastRow();
}

FFI_EXPORT char* pasteDataBlock(int startRow, int startCol, const char* csvText) {
    try {
        if (!csvText) return nullptr;
        std::string text = GridManager::getInstance().pasteDataBlock(startRow, startCol, std::string(csvText));
        char* cstr = (char*)malloc(text.length() + 1);
        if (cstr) {
            std::strcpy(cstr, text.c_str());
        }
        return cstr;
    } catch (...) {
        char* err = (char*)malloc(3);
        strcpy(err, "{}");
        return err;
    }
}

FFI_EXPORT char* copyDataBlock(int startRow, int startCol, int endRow, int endCol) {
    try {
        std::string text = GridManager::getInstance().copyDataBlock(startRow, startCol, endRow, endCol);
        char* cstr = (char*)malloc(text.length() + 1);
        if (cstr) {
            std::strcpy(cstr, text.c_str());
        }
        return cstr;
    } catch (...) {
        char* err = (char*)malloc(3);
        strcpy(err, "{}");
        return err;
    }
}

FFI_EXPORT char* calculateAll() {
    try {
        updateFormulaProgress(0, 0, true);
        std::string jsonStr = GridManager::getInstance().calculateAll();
        updateFormulaProgress(0, 0, false);
        char* cstr = (char*)malloc(jsonStr.length() + 1);
        if (cstr) {
            std::strcpy(cstr, jsonStr.c_str());
        }
        return cstr;
    } catch (...) {
        updateFormulaProgress(0, 0, false);
        char* err = (char*)malloc(3);
        strcpy(err, "{}");
        return err;
    }
}

FFI_EXPORT char* getRawGrid() {
    try {
        std::string jsonStr = GridManager::getInstance().getRawGrid();
        char* cstr = (char*)malloc(jsonStr.length() + 1);
        if (cstr) {
            std::strcpy(cstr, jsonStr.c_str());
        }
        return cstr;
    } catch (...) {
        char* err = (char*)malloc(3);
        strcpy(err, "{}");
        return err;
    }
}


FFI_EXPORT void freeString(char* ptr) {
    if (ptr != nullptr) {
        free(ptr);
    }
}

// --- Conditional Formatting API ---
FFI_EXPORT void cf_addRule(const char* sheetId, const char* ruleJson) {
    if (!g_cfManager || !sheetId || !ruleJson) return;
    ConditionalFormatting::CFRule rule = ConditionalFormatting::CFRule::fromJson(ruleJson);
    g_cfManager->addRule(sheetId, rule);
}

FFI_EXPORT void cf_removeRule(const char* sheetId, const char* ruleId) {
    if (!g_cfManager || !sheetId || !ruleId) return;
    g_cfManager->removeRule(sheetId, ruleId);
}

FFI_EXPORT void cf_reorderRule(const char* sheetId, const char* ruleId, int newPriority) {
    if (!g_cfManager || !sheetId || !ruleId) return;
    g_cfManager->reorderRule(sheetId, ruleId, newPriority);
}

FFI_EXPORT void cf_clearRules(const char* sheetId) {
    if (!g_cfManager || !sheetId) return;
    g_cfManager->clearRules(sheetId);
}

FFI_EXPORT char* cf_getRules(const char* sheetId) {
    if (!g_cfManager || !sheetId) {
        char* err = (char*)malloc(3);
        strcpy(err, "[]");
        return err;
    }
    auto rules = g_cfManager->getRulesForSheet(sheetId);
    std::string json = "[";
    for (size_t i = 0; i < rules.size(); i++) {
        json += rules[i].toJson();
        if (i < rules.size() - 1) json += ",";
    }
    json += "]";
    char* out = (char*)malloc(json.size() + 1);
    strcpy(out, json.c_str());
    return out;
}

// Simple JSON helper
static std::string cfEscapeJson(const std::string& str) {
    std::string result;
    for (char c : str) {
        if (c == '"') result += "\\\"";
        else if (c == '\\') result += "\\\\";
        else if (c == '\b') result += "\\b";
        else if (c == '\f') result += "\\f";
        else if (c == '\n') result += "\\n";
        else if (c == '\r') result += "\\r";
        else if (c == '\t') result += "\\t";
        else result += c;
    }
    return result;
}

FFI_EXPORT char* cf_evaluateVisibleCells(const char* sheetId, const char* visibleCellsJson) {
    if (!g_cfManager || !sheetId || !visibleCellsJson) {
        char* err = (char*)malloc(3);
        strcpy(err, "{}");
        return err;
    }
    
    // Parse JSON string array manually: ["A1", "A2", "B1"]
    std::string json(visibleCellsJson);
    std::vector<std::string> cells;
    size_t pos = 0;
    while ((pos = json.find('"', pos)) != std::string::npos) {
        pos++;
        size_t endPos = json.find('"', pos);
        if (endPos == std::string::npos) break;
        cells.push_back(json.substr(pos, endPos - pos));
        pos = endPos + 1;
    }
    
    auto rules = g_cfManager->getRulesForSheet(sheetId);
    if (rules.empty()) {
        char* err = (char*)malloc(3);
        strcpy(err, "{}");
        return err;
    }
    
    std::string resultJson = "{";
    bool firstEntry = true;
    
    for (const auto& cellRef : cells) {
        ConditionalFormatting::CFManager::EvalContext ctx;
        ctx.cellRef = cellRef;
        ctx.row = 0;
        ctx.col = 0;
        if (!Evaluator::parseCellCoordinates(cellRef, ctx.row, ctx.col)) {
            size_t colon = cellRef.find(':');
            if (colon != std::string::npos) {
                try {
                    ctx.row = std::stoi(cellRef.substr(0, colon));
                    ctx.col = std::stoi(cellRef.substr(colon + 1));
                } catch(...) {}
            }
        }
        EvalResult val = GridManager::getInstance().evaluateCell(cellRef);
        if (std::holds_alternative<std::string>(val)) {
            ctx.cellValue = std::get<std::string>(val);
            try { ctx.numericValue = std::stod(ctx.cellValue); } catch(...) { ctx.numericValue = NAN; }
            ctx.isBlank = ctx.cellValue.empty();
        } else if (std::holds_alternative<double>(val)) {
            ctx.numericValue = std::get<double>(val);
            ctx.cellValue = std::to_string(ctx.numericValue);
            ctx.isBlank = false;
        } else if (std::holds_alternative<bool>(val)) {
            bool b = std::get<bool>(val);
            ctx.numericValue = b ? 1.0 : 0.0;
            ctx.cellValue = b ? "TRUE" : "FALSE";
            ctx.isBlank = false;
        } else if (std::holds_alternative<Blank>(val)) {
            ctx.numericValue = 0;
            ctx.cellValue = "";
            ctx.isBlank = true;
        }
        
        ctx.evaluateBooleanFormula = [&ctx](const std::string& formula) {
            try {
                std::string form = formula;
                if (!form.empty() && form[0] != '=') {
                    form = "=" + form;
                }
                
                Tokenizer tokenizer(form);
                auto tokens = tokenizer.tokenize();
                
                Parser parser(tokens);
                auto ast = parser.parse();
                
                Evaluator evaluator;
                evaluator.currentRow = ctx.row;
                evaluator.currentCol = ctx.col;
                evaluator.globalEnvironment = &g_namedRanges;
                evaluator.progressCallback = nullptr;
                
                evaluator.getCell = [](const std::string& ref) {
                    return GridManager::getInstance().evaluateCell(ref);
                };
                
                evaluator.getRange = [](const std::string& topLeft, const std::string& bottomRight, const std::string&) -> ArrayVal {
                    int r1 = 0, c1 = 0, r2 = 0, c2 = 0;
                    bool topIsRow = false, topIsCol = false;
                    bool botIsRow = false, botIsCol = false;
                    if (!Evaluator::parseCellCoordinates(topLeft, r1, c1, &topIsRow, &topIsCol) || 
                        !Evaluator::parseCellCoordinates(bottomRight, r2, c2, &botIsRow, &botIsCol)) {
                        return ArrayVal{{{CellError{"#REF!"}}}};
                    }
                    if (topIsCol || botIsCol) { r1 = std::min(r1, r2); r2 = 9999; }
                    if (topIsRow || botIsRow) { c1 = std::min(c1, c2); c2 = 255; }

                    int minR = std::min(r1, r2), maxR = std::max(r1, r2);
                    int minC = std::min(c1, c2), maxC = std::max(c1, c2);
                    ArrayVal res;
                    for (int r = minR; r <= maxR; r++) {
                        std::vector<EvalResult> rowVals;
                        for (int c = minC; c <= maxC; c++) {
                            std::string ref = Evaluator::indexToColumn(c) + std::to_string(r + 1);
                            rowVals.push_back(GridManager::getInstance().evaluateCell(ref));
                        }
                        res.matrix.push_back(rowVals);
                    }
                    return res;
                };

                EvalResult result = evaluator.evaluate(ast.get());
                
                if (std::holds_alternative<bool>(result)) return std::get<bool>(result);
                if (std::holds_alternative<double>(result)) return std::get<double>(result) != 0.0;
                if (std::holds_alternative<std::string>(result)) {
                    std::string str = std::get<std::string>(result);
                    return !str.empty() && str != "0" && str != "FALSE";
                }
                return false;
            } catch (const std::exception& e) {
                LOGE("CF Formula exception: %s", e.what());
                return false;
            } catch (...) {
                LOGE("CF Formula exception: Unknown error");
                return false;
            }
        };
        
        // Range evaluation helpers for TopBottom, Avg, Duplicates, DataBar
        struct RangeStats {
            double minVal = 1e308;
            double maxVal = -1e308;
            double sumVal = 0.0;
            int count = 0;
            std::vector<double> numValues;
            std::vector<std::string> strValues;
        };

        auto getStats = [](const std::string& rangeStr) -> RangeStats {
            RangeStats stats;
            std::string topLeft = rangeStr;
            std::string bottomRight = rangeStr;
            size_t colon = rangeStr.find(':');
            if (colon != std::string::npos) {
                topLeft = rangeStr.substr(0, colon);
                bottomRight = rangeStr.substr(colon + 1);
            }
            int r1 = 0, c1 = 0, r2 = 0, c2 = 0;
            bool topIsRow = false, topIsCol = false;
            bool botIsRow = false, botIsCol = false;
            if (!Evaluator::parseCellCoordinates(topLeft, r1, c1, &topIsRow, &topIsCol) || 
                !Evaluator::parseCellCoordinates(bottomRight, r2, c2, &botIsRow, &botIsCol)) {
                return stats;
            }
            if (topIsCol || botIsCol) { r1 = std::min(r1, r2); r2 = 9999; }
            if (topIsRow || botIsRow) { c1 = std::min(c1, c2); c2 = 255; }

            int minR = std::min(r1, r2), maxR = std::max(r1, r2);
            int minC = std::min(c1, c2), maxC = std::max(c1, c2);
            for (int r = minR; r <= maxR; r++) {
                for (int c = minC; c <= maxC; c++) {
                    std::string ref = Evaluator::indexToColumn(c) + std::to_string(r + 1);
                    EvalResult val = GridManager::getInstance().evaluateCell(ref);
                    if (std::holds_alternative<double>(val)) {
                        double d = std::get<double>(val);
                        stats.numValues.push_back(d);
                        stats.minVal = std::min(stats.minVal, d);
                        stats.maxVal = std::max(stats.maxVal, d);
                        stats.sumVal += d;
                        stats.count++;
                        stats.strValues.push_back(std::to_string(d));
                    } else if (std::holds_alternative<std::string>(val)) {
                        std::string s = std::get<std::string>(val);
                        stats.strValues.push_back(s);
                        try {
                            double d = std::stod(s);
                            stats.numValues.push_back(d);
                            stats.minVal = std::min(stats.minVal, d);
                            stats.maxVal = std::max(stats.maxVal, d);
                            stats.sumVal += d;
                            stats.count++;
                        } catch(...) {}
                    }
                }
            }
            return stats;
        };

        ctx.getRangeMin = [&getStats](const std::string& range) {
            auto s = getStats(range);
            return s.count > 0 ? s.minVal : 0.0;
        };
        ctx.getRangeMax = [&getStats](const std::string& range) {
            auto s = getStats(range);
            return s.count > 0 ? s.maxVal : 100.0;
        };
        ctx.getRangeAvg = [&getStats](const std::string& range) {
            auto s = getStats(range);
            return s.count > 0 ? (s.sumVal / s.count) : 0.0;
        };
        ctx.isDuplicate = [&getStats, &ctx](const std::string& range) {
            auto s = getStats(range);
            int occurrences = 0;
            for (const auto& str : s.strValues) {
                if (str == ctx.cellValue) occurrences++;
            }
            return occurrences > 1;
        };
        ctx.isInTopBottom = [&getStats, &ctx](const std::string& range, int rank, bool isPercent, bool isTop) {
            auto s = getStats(range);
            if (s.numValues.empty() || std::isnan(ctx.numericValue)) return false;
            std::vector<double> sorted = s.numValues;
            std::sort(sorted.begin(), sorted.end());
            int total = sorted.size();
            int countNeeded = isPercent ? (int)std::ceil(total * (rank / 100.0)) : rank;
            if (countNeeded < 1) countNeeded = 1;
            if (countNeeded > total) countNeeded = total;
            if (isTop) {
                return ctx.numericValue >= sorted[total - countNeeded];
            } else {
                return ctx.numericValue <= sorted[countNeeded - 1];
            }
        };
        
        ConditionalFormatting::CFComputedStyle style = ConditionalFormatting::RuleEvaluator::resolveStyles(rules, ctx);
        
        if (style.style.hasFormatting() || style.dataBar.has_value() || style.colorScaleColor.has_value() || style.iconName.has_value()) {
            if (!firstEntry) resultJson += ",";
            resultJson += "\"" + cellRef + "\":{";
            
            bool firstStyle = true;
            if (style.style.bgColor.has_value()) {
                resultJson += "\"bgColor\":\"" + cfEscapeJson(*style.style.bgColor) + "\"";
                firstStyle = false;
            }
            if (style.style.textColor.has_value()) {
                if (!firstStyle) resultJson += ",";
                resultJson += "\"textColor\":\"" + cfEscapeJson(*style.style.textColor) + "\"";
                firstStyle = false;
            }
            if (style.style.bold.has_value()) {
                if (!firstStyle) resultJson += ",";
                resultJson += "\"bold\":" + std::string(*style.style.bold ? "true" : "false");
                firstStyle = false;
            }
            if (style.style.italic.has_value()) {
                if (!firstStyle) resultJson += ",";
                resultJson += "\"italic\":" + std::string(*style.style.italic ? "true" : "false");
                firstStyle = false;
            }
            if (style.style.underline.has_value()) {
                if (!firstStyle) resultJson += ",";
                resultJson += "\"underline\":" + std::string(*style.style.underline ? "true" : "false");
                firstStyle = false;
            }
            if (style.style.strike.has_value()) {
                if (!firstStyle) resultJson += ",";
                resultJson += "\"strike\":" + std::string(*style.style.strike ? "true" : "false");
                firstStyle = false;
            }
            if (style.dataBar.has_value()) {
                if (!firstStyle) resultJson += ",";
                resultJson += "\"dataBarFill\":\"" + cfEscapeJson(style.dataBar->positiveColor) + "\",";
                resultJson += "\"dataBarPercent\":" + std::to_string(style.dataBarPercent.value_or(0.0));
                firstStyle = false;
            }
            
            resultJson += "}";
            firstEntry = false;
        }
    }
    resultJson += "}";
    
    char* out = (char*)malloc(resultJson.size() + 1);
    strcpy(out, resultJson.c_str());
    return out;
}

FFI_EXPORT char* native_calculateAll() {
    std::string res = GridManager::getInstance().calculateAll();
    return allocFfiString(res);
}

FFI_EXPORT char* native_getRawGrid() {
    std::string res = GridManager::getInstance().getRawGrid();
    return allocFfiString(res);
}

// -------------------------------------------------------------
// Data Tools Endpoints
// -------------------------------------------------------------

#include "json.hpp"

FFI_EXPORT char* splitTextToColumns(const char* text, const char* delimiters, int ignoreEmpty, const char* textQualifiers) {
    if (!text || !delimiters || !textQualifiers) {
        return allocFfiString("[]");
    }
    
    std::string s_text(text);
    std::string s_delims(delimiters);
    std::string s_quals(textQualifiers);
    bool b_ignore = ignoreEmpty != 0;

    std::vector<std::vector<std::string>> result;
    std::vector<std::string> currentRow;
    
    std::string currentCell = "";
    bool inQualifier = false;
    char currentQualifier = '\0';
    
    auto isDelimiter = [&](char c) {
        return s_delims.find(c) != std::string::npos;
    };
    auto isQualifier = [&](char c) {
        return s_quals.find(c) != std::string::npos;
    };

    bool lastWasDelimiter = true;
    bool cellHadContent = false;

    for (size_t i = 0; i < s_text.length(); i++) {
        char c = s_text[i];
        
        if (inQualifier) {
            if (c == currentQualifier) {
                if (i + 1 < s_text.length() && s_text[i+1] == currentQualifier) {
                    currentCell += currentQualifier;
                    i++;
                } else {
                    inQualifier = false;
                }
            } else {
                currentCell += c;
            }
            cellHadContent = true;
            lastWasDelimiter = false;
        } else {
            if (isQualifier(c)) {
                inQualifier = true;
                currentQualifier = c;
                cellHadContent = true;
                lastWasDelimiter = false;
            } else if (c == '\r') {
                if (i + 1 < s_text.length() && s_text[i+1] == '\n') {
                    // Handled by \n
                } else {
                    if (!b_ignore || cellHadContent || !lastWasDelimiter) {
                        currentRow.push_back(currentCell);
                    }
                    if (!b_ignore || !currentRow.empty()) {
                        result.push_back(currentRow);
                    }
                    currentRow.clear();
                    currentCell = "";
                    cellHadContent = false;
                    lastWasDelimiter = true; 
                }
            } else if (c == '\n') {
                if (!b_ignore || cellHadContent || !lastWasDelimiter) {
                    currentRow.push_back(currentCell);
                }
                if (!b_ignore || !currentRow.empty()) {
                    result.push_back(currentRow);
                }
                currentRow.clear();
                currentCell = "";
                cellHadContent = false;
                lastWasDelimiter = true;
            } else if (isDelimiter(c)) {
                if (!b_ignore || cellHadContent || !lastWasDelimiter) {
                    currentRow.push_back(currentCell);
                }
                currentCell = "";
                cellHadContent = false;
                lastWasDelimiter = true;
            } else {
                currentCell += c;
                cellHadContent = true;
                lastWasDelimiter = false;
            }
        }
    }
    
    bool endsWithNewline = (!s_text.empty() && (s_text.back() == '\n' || s_text.back() == '\r'));
    if (!endsWithNewline) {
        if (!b_ignore || cellHadContent || !lastWasDelimiter) {
            currentRow.push_back(currentCell);
        }
        if (!b_ignore || !currentRow.empty()) {
            result.push_back(currentRow);
        }
    }
    
    nlohmann::json j = result;
    return allocFfiString(j.dump());
}

// -------------------------------------------------------------
// FFI Exports for QuickJS JavaScript Engine
// -------------------------------------------------------------

FFI_EXPORT void initJsEngine() {
    JsEngine::getInstance().init();
}

FFI_EXPORT void cleanupJsEngine() {
    JsEngine::getInstance().cleanup();
}

FFI_EXPORT char* evalJsScript(const char* code) {
    if (!code) return nullptr;
    std::string res = JsEngine::getInstance().evalScript(code);
    return allocFfiString(res);
}

FFI_EXPORT char* callJsFunction(const char* funcName, const char* jsonArgs) {
    if (!funcName) return nullptr;
    std::vector<std::string> args;
    if (jsonArgs && strlen(jsonArgs) > 0) {
        args.push_back(jsonArgs);
    }
    std::string res = JsEngine::getInstance().callJsFunction(funcName, args);
    return allocFfiString(res);
}

FFI_EXPORT void registerJsMacro(const char* name, const char* code) {
    if (name && code) {
        JsEngine::getInstance().registerMacro(name, code);
    }
}

FFI_EXPORT char* getJsMacroNames() {
    auto names = JsEngine::getInstance().getMacroNames();
    std::string json = "[";
    for (size_t i = 0; i < names.size(); i++) {
        json += "\"" + names[i] + "\"";
        if (i < names.size() - 1) json += ",";
    }
    json += "]";
    return allocFfiString(json);
}

FFI_EXPORT void setDartFetchCallback(DartFetchCallbackFn callback) {
    JsEngine::getInstance().setFetchCallback(callback);
}

FFI_EXPORT void triggerJsOnEdit(const char* sheetName, const char* cellRef, const char* oldValue, const char* newValue) {
    JsEngine::getInstance().triggerOnEdit(
        sheetName ? sheetName : "Sheet1",
        cellRef ? cellRef : "",
        oldValue ? oldValue : "",
        newValue ? newValue : ""
    );
}

// -------------------------------------------------------------
// Data Filter Engine Bindings
// -------------------------------------------------------------

FFI_EXPORT void filter_addRuleFromJson(const char* sheetId, int col, const char* jsonRule) {
    if (!sheetId || !jsonRule) return;
    Filters::FilterEngine::getInstance().addRuleFromJson(sheetId, col, jsonRule);
}

FFI_EXPORT void filter_clear(const char* sheetId) {
    if (sheetId) Filters::FilterEngine::getInstance().clearRules(sheetId);
}

FFI_EXPORT const char* filter_getPreviewStats(const char* sheetId, int col, const char* jsonRule, int totalRows) {
    if (!sheetId || !jsonRule) return allocFfiString("{}");
    
    std::string statsJson = Filters::FilterEngine::getInstance().getPreviewStats(sheetId, col, jsonRule, totalRows, [](int r, int c) {
        std::string colStr;
        int tempC = c;
        while (tempC >= 0) { colStr = char('A' + (tempC % 26)) + colStr; tempC = tempC / 26 - 1; }
        std::string ref = colStr + std::to_string(r + 1);
        
        auto res = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<double>(res)) return std::to_string(std::get<double>(res));
        if (std::holds_alternative<std::string>(res)) return std::get<std::string>(res);
        return std::string("");
    });
    
    return allocFfiString(statsJson);
}

FFI_EXPORT const char* filter_getHiddenRows(const char* sheetId, int maxRows) {
    if (!sheetId) return allocFfiString("[]");
    
    std::string jsonResult = Filters::FilterEngine::getInstance().getHiddenRowsJson(sheetId, maxRows, [](int r, int c) {
        std::string colStr;
        int tempC = c;
        while (tempC >= 0) { colStr = char('A' + (tempC % 26)) + colStr; tempC = tempC / 26 - 1; }
        std::string ref = colStr + std::to_string(r + 1);
        
        auto res = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<double>(res)) return std::to_string(std::get<double>(res));
        if (std::holds_alternative<std::string>(res)) return std::get<std::string>(res);
        return std::string("");
    });
    
    return allocFfiString(jsonResult);
}

FFI_EXPORT const uint8_t* filter_getVisibleRowsBitmap(const char* sheetId, int maxRows, int* outLength) {
    if (!sheetId || !outLength) return nullptr;
    
    int len = 0;
    const uint8_t* ptr = Filters::FilterEngine::getInstance().getVisibleRowsBitmap(sheetId, maxRows, [](int r, int c) {
        std::string colStr;
        int tempC = c;
        while (tempC >= 0) { colStr = char('A' + (tempC % 26)) + colStr; tempC = tempC / 26 - 1; }
        std::string ref = colStr + std::to_string(r + 1);
        
        auto res = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<double>(res)) return std::to_string(std::get<double>(res));
        if (std::holds_alternative<std::string>(res)) return std::get<std::string>(res);
        return std::string("");
    }, len);
    
    *outLength = len;
    return ptr;
}

FFI_EXPORT void filter_evaluateSingleRow(const char* sheetId, int row) {
    if (!sheetId) return;
    Filters::FilterEngine::getInstance().evaluateSingleRow(sheetId, row, [](int r, int c) {
        std::string colStr;
        int tempC = c;
        while (tempC >= 0) { colStr = char('A' + (tempC % 26)) + colStr; tempC = tempC / 26 - 1; }
        std::string ref = colStr + std::to_string(r + 1);
        
        auto res = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<double>(res)) return std::to_string(std::get<double>(res));
        if (std::holds_alternative<std::string>(res)) return std::get<std::string>(res);
        return std::string("");
    });
}

// -------------------------------------------------------------
// [FROZEN API] ETL Pipeline Engine
// -------------------------------------------------------------

/**
 * @brief [FROZEN API] Executes a JSON data pipeline on the current grid
 * 
 * @param sheetId ID of the sheet to run against
 * @param pipelineJson Valid JSON string representing the pipeline
 * @return JSON string of the PipelineResult
 */
FFI_EXPORT const char* pipeline_execute(const char* sheetId, const char* pipelineJson) {
    if (!sheetId || !pipelineJson) return allocFfiString("{\"status\":\"FATAL_ERROR\", \"code\":500, \"message\":\"Null arguments\"}");
    
    DataPipeline::PipelineContext ctx;
    ctx.sheetId = sheetId;
    ctx.totalRows = GridManager::getInstance().getLastRow(); 
    if (ctx.totalRows < 1000) ctx.totalRows = 1000;
    ctx.totalCols = 26;
    
    ctx.getCellVal = [](int r, int c) {
        std::string colStr;
        int tempC = c;
        while (tempC >= 0) { colStr = char('A' + (tempC % 26)) + colStr; tempC = tempC / 26 - 1; }
        std::string ref = colStr + std::to_string(r + 1);
        
        auto res = GridManager::getInstance().evaluateCell(ref);
        if (std::holds_alternative<double>(res)) return std::to_string(std::get<double>(res));
        if (std::holds_alternative<std::string>(res)) return std::get<std::string>(res);
        return std::string("");
    };
    
    ctx.setCellVal = [](int r, int c, const std::string& val) {
        std::string colStr;
        int tempC = c;
        while (tempC >= 0) { colStr = char('A' + (tempC % 26)) + colStr; tempC = tempC / 26 - 1; }
        std::string ref = colStr + std::to_string(r + 1);

        std::string trimmed = val;
        while (!trimmed.empty() && std::isspace((unsigned char)trimmed.front())) trimmed.erase(0, 1);
        while (!trimmed.empty() && std::isspace((unsigned char)trimmed.back())) trimmed.pop_back();

        if (!trimmed.empty() && trimmed[0] == '=') {
            GridManager::getInstance().setCellFormula(ref, trimmed);
        } else {
            // Check if string contains only digits/signs/dot and symbols (no other letters)
            bool isNumericFormatted = false;
            int digitCount = 0;
            int letterCount = 0;
            for (char ch : trimmed) {
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
                for (char ch : trimmed) {
                    if (std::isdigit(ch) || ch == '-' || ch == '+' || ch == 'e' || ch == 'E') {
                        clean += ch;
                    } else if (ch == '.' && !hasDot) {
                        clean += ch;
                        hasDot = true;
                    }
                }
                double d = 0.0;
                try {
                    if (!clean.empty()) {
                        size_t idx = 0;
                        d = std::stod(clean, &idx);
                        if (idx == clean.length()) {
                            GridManager::getInstance().setCellConstant(ref, d);
                            return;
                        }
                    }
                } catch (...) {}
            }
            GridManager::getInstance().setCellConstantString(ref, val);
        }
    };
    
    DataPipeline::PipelineResult res = DataPipeline::PipelineExecutor::getInstance().executePipeline(ctx, pipelineJson);
    
    std::string statusStr = "SUCCESS";
    if (res.status == DataPipeline::ExecutionStatus::WARNING) statusStr = "WARNING";
    if (res.status == DataPipeline::ExecutionStatus::RETRYABLE_ERROR) statusStr = "RETRYABLE_ERROR";
    if (res.status == DataPipeline::ExecutionStatus::FATAL_ERROR) statusStr = "FATAL_ERROR";
    
    std::string jsonStr = "{\"status\":\"" + statusStr + "\", \"code\":" + std::to_string(res.errorCode) + ", \"message\":\"" + res.message + "\"}";
    return allocFfiString(jsonStr);
}

// -------------------------------------------------------------
// Data Intelligence Engine — Column Analysis & Auto-Clean API
// See: data_engine/analyzer/column_analyzer.h
//      data_engine/analyzer/sheet_summarizer.h
//      data_engine/cleaning/data_cleaner.h
// -------------------------------------------------------------

/**
 * @brief Analyze a column's data types, quality, and issues.
 * @param columnLetter  Column letter e.g. "A", "B", "AB"
 * @return JSON string with detected_type, confidence, issues, suggested_action, samples
 * @see data_engine/analyzer/column_analyzer.h  for ColumnAnalysisResult struct
 * @see local_agent_service.dart analyze_column tool  for AI usage
 */
FFI_EXPORT const char* native_analyzeColumn(const char* columnLetter) {
    if (!columnLetter || strlen(columnLetter) == 0) {
        return allocFfiString("{\"error\":\"No column specified\"}");
    }
    try {
        Filters::ColumnAnalysisResult result =
            Filters::ColumnAnalyzer::getInstance().analyze(std::string(columnLetter), true);
        return allocFfiString(result.toJson());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

/**
 * @brief Generate a full smart summary of the entire sheet.
 * @return JSON string with total_rows, total_columns, quality_score,
 *         smart_summary (human-readable), and per-column reports array.
 * @see data_engine/analyzer/sheet_summarizer.h  for SheetSummary struct
 * @see local_agent_service.dart summarize_sheet tool  for AI usage
 */
FFI_EXPORT const char* native_summarizeSheet() {
    try {
        Filters::SheetSummary summary =
            Filters::SheetSummarizer::getInstance().summarize(26);
        return allocFfiString(summary.toJson());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

/**
 * @brief Auto-detect the data type of a single value and return the cleaned version.
 * @param rawValue  The raw cell value string
 * @return Cleaned string (e.g. phone normalized, currency extracted, text trimmed)
 * @see data_engine/cleaning/data_cleaner.h  for DataCleaner::autoClean()
 */
FFI_EXPORT const char* native_autoCleanValue(const char* rawValue) {
    if (!rawValue) return allocFfiString("");
    try {
        std::string cleaned = Filters::DataCleaner::getInstance().autoClean(rawValue);
        return allocFfiString(cleaned);
    } catch (...) {
        return allocFfiString(rawValue); // safe fallback: return original
    }
}

/**
 * @brief Auto-clean an entire column in-place (detect type per cell, then clean).
 * Skips row 1 (header). Writes cleaned values back to GridManager.
 * @param columnLetter  Column letter e.g. "A", "B"
 * @return JSON with {cleaned_count, skipped_count, errors}
 * @see data_engine/cleaning/data_cleaner.h
 * @see data_engine/analyzer/column_analyzer.h  for column type detection first
 */
FFI_EXPORT const char* native_cleanColumn(const char* columnLetter) {
    if (!columnLetter || strlen(columnLetter) == 0) {
        return allocFfiString("{\"error\":\"No column specified\"}");
    }
    try {
        std::string col(columnLetter);
        // Convert col letter to 0-indexed int
        int colIdx = 0;
        for (char c : col) colIdx = colIdx * 26 + (std::toupper((unsigned char)c) - 'A' + 1);
        colIdx -= 1;

        // Build col letter (uppercase)
        std::string colUpper;
        for (char c : col) colUpper += std::toupper((unsigned char)c);

        int cleanedCount = 0, skippedCount = 0;
        int lastRow = GridManager::getInstance().getLastRow();
        Filters::DataCleaner& cleaner = Filters::DataCleaner::getInstance();

        // Determine dominant type for this column first
        Filters::ColumnAnalysisResult analysis =
            Filters::ColumnAnalyzer::getInstance().analyze(colUpper, true);
        Filters::DataType colType = analysis.dominantType;

        // Clean each row from 2 to lastRow
        for (int row = 2; row <= lastRow; row++) {
            std::string cellRef = colUpper + std::to_string(row);

            // Skip formula cells
            if (!GridManager::getInstance().isCellEmpty(cellRef)) {
                std::string formula = GridManager::getInstance().getCellFormula(cellRef);
                if (!formula.empty()) { skippedCount++; continue; }
            } else {
                skippedCount++; continue;
            }

            // Evaluate current value
            EvalResult evalRes = GridManager::getInstance().evaluateCell(cellRef);
            std::string rawVal;
            if (std::holds_alternative<std::string>(evalRes)) {
                rawVal = std::get<std::string>(evalRes);
            } else if (std::holds_alternative<double>(evalRes)) {
                double d = std::get<double>(evalRes);
                if (std::isnan(d) || std::isinf(d)) {
                    skippedCount++; continue;
                }
                if (d == std::floor(d)) {
                    rawVal = std::to_string(static_cast<long long>(d));
                } else {
                    std::ostringstream ss;
                    ss << d;
                    rawVal = ss.str();
                }
            } else {
                skippedCount++; continue;
            }

            if (rawVal.empty()) { skippedCount++; continue; }

            // Clean using column's dominant type
            std::string cleaned = cleaner.clean(rawVal, colType);

            if (!cleaned.empty() && cleaned != rawVal) {
                GridManager::getInstance().setCellConstantString(cellRef, cleaned);
                cleanedCount++;
            } else {
                skippedCount++;
            }

        }

        std::string resultJson = "{\"cleaned_count\":" + std::to_string(cleanedCount) +
                                  ",\"skipped_count\":" + std::to_string(skippedCount) +
                                  ",\"column\":\"" + colUpper + "\"" +
                                  ",\"detected_type\":\"" + analysis.dominantTypeName + "\"" +
                                  "}";
        return allocFfiString(resultJson);
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

/**
 * native_analyzeEmail
 * Analyzes raw email, extracts email from surrounding text/garbage,
 * applies provider rules (Gmail dot/plus alias), and returns full EmailMetadata JSON.
 */
char* native_analyzeEmail(const char* rawEmail) {
    if (!rawEmail) return allocFfiString("{}");
    try {
        Filters::EmailMetadata meta = Filters::EmailCleaner::analyzeAndNormalize(rawEmail);
        std::string json = "{"
            "\"original_email\":\"" + cfEscapeJson(meta.originalEmail) + "\","
            "\"raw_cleaned_email\":\"" + cfEscapeJson(meta.rawCleanedEmail) + "\","
            "\"normalized_email\":\"" + cfEscapeJson(meta.normalizedEmail) + "\","
            "\"local_part\":\"" + cfEscapeJson(meta.localPart) + "\","
            "\"domain\":\"" + cfEscapeJson(meta.domain) + "\","
            "\"tld\":\"" + cfEscapeJson(meta.tld) + "\","
            "\"provider\":\"" + cfEscapeJson(meta.provider) + "\","
            "\"is_valid\":" + (meta.isValid ? "true" : "false") + ","
            "\"has_plus_alias\":" + (meta.hasPlusAlias ? "true" : "false") + ","
            "\"has_dots\":" + (meta.hasDots ? "true" : "false") + ","
            "\"is_disposable\":" + (meta.isDisposable ? "true" : "false") + ","
            "\"confidence_score\":" + std::to_string(meta.confidenceScore) + ","
            "\"validation_message\":\"" + cfEscapeJson(meta.validationMessage) + "\""
        "}";
        return allocFfiString(json);
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}




// ─────────────────────────────────────────────────────────────────────────────
// Phase 3: Sheet Brain FFI Exports
// ─────────────────────────────────────────────────────────────────────────────

/**
 * native_understandSheet
 * Compresses entire sheet into 300-token AI context JSON.
 * Output: {sheetType, totalRows, totalColumns, overallQuality, columns[], topIssues[], suggestedActions[], smartSummary}
 * C++: data_engine/brain/context_compressor.cpp
 * Dart: NativeEngine.understandSheet()
 * AI Agent tool: understand_sheet
 */
char* native_understandSheet() {
    try {
        Filters::AIContext ctx = Filters::ContextCompressor::getInstance().compress();
        return allocFfiString(ctx.toJson());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

/**
 * native_findClusters
 * Finds fuzzy clusters in a column (OpenRefine-style).
 * @param columnLetter  Column letter e.g. "A"
 * @param threshold     Min similarity 0.0-1.0 (default 0.85)
 * Output: {column, clusters:[{canonical,variants[],avgSimilarity,algorithm}], totalValues, clusteredCount}
 * C++: data_engine/cluster/cluster_engine.cpp
 * Dart: NativeEngine.findClusters(columnLetter)
 * AI Agent tool: find_clusters
 */
char* native_findClusters(const char* columnLetter, double threshold) {
    if (!columnLetter) return nullptr;
    try {
        std::string colStr(columnLetter);
        // Convert to uppercase
        for (char& c : colStr) c = std::toupper((unsigned char)c);

        // Collect all non-empty values in this column (skipping header row 1)
        int lastRow = GridManager::getInstance().getLastRow();
        std::map<std::string, int> valueFreq;

        for (int r = 2; r <= lastRow; r++) {
            std::string cellRef = colStr + std::to_string(r);
            // Evaluate or get cell value
            EvalResult evalRes = GridManager::getInstance().evaluateCell(cellRef);
            std::string val;
            if (std::holds_alternative<std::string>(evalRes)) {
                val = std::get<std::string>(evalRes);
            } else if (std::holds_alternative<double>(evalRes)) {
                char buf[32];
                snprintf(buf, sizeof(buf), "%g", std::get<double>(evalRes));
                val = buf;
            }
            if (!val.empty()) valueFreq[val]++;
        }


        std::vector<std::string> uniqueValues;
        for (auto& [v, _] : valueFreq) uniqueValues.push_back(v);

        Filters::ClusterResult result = Filters::ClusterEngine::getInstance().cluster(
            uniqueValues, colStr, (float)threshold);

        return allocFfiString(result.toJson());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

// --- BI Analytics: Pivot & Group Engine ---
#include "json.hpp"
using json = nlohmann::json;

FFI_EXPORT char* executePivot(const char* requestJson) {
    try {
        if (!requestJson) return allocFfiString("{\"error\":\"Empty request\"}");
        auto req = json::parse(requestJson);
        
        std::string sheetId = req.value("sheetId", "");
        auto rowFields = req.value("rowFields", std::vector<std::string>());
        auto colFields = req.value("colFields", std::vector<std::string>());
        auto dataFields = req.value("dataFields", std::vector<std::string>());
        std::string aggType = req.value("aggType", "SUM");

        if (rowFields.empty() || dataFields.empty()) {
            return allocFfiString("{\"error\":\"Missing rowFields or dataFields\"}");
        }

        // We assume headers are on Row 1.
        int lastRow = GridManager::getInstance().getLastRow();
        int lastCol = GridManager::getInstance().getLastColumn();

        // 1. Map column names to column letters (A, B, C...)
        std::map<std::string, std::string> colNameToLetter;
        for (int c = 0; c <= lastCol; c++) {
            std::string colLetter = "";
            int temp = c;
            while (temp >= 0) { colLetter = char('A' + (temp % 26)) + colLetter; temp = temp / 26 - 1; }
            std::string headerRef = colLetter + "1";
            EvalResult headerEval = GridManager::getInstance().evaluateCell(headerRef);
            std::string headerStr = "";
            if (std::holds_alternative<std::string>(headerEval)) {
                headerStr = std::get<std::string>(headerEval);
            } else if (std::holds_alternative<double>(headerEval)) {
                // If it's a number (e.g. 2024), convert to string without trailing zeroes
                double d = std::get<double>(headerEval);
                if (d == (int)d) headerStr = std::to_string((int)d);
                else headerStr = std::to_string(d);
            }

            if (!headerStr.empty()) {
                colNameToLetter[headerStr] = colLetter;
            } else {
                colNameToLetter[colLetter] = colLetter; // Fallback to letter A, B, C...
            }
        }

        // 2. Iterate data rows and group
        std::map<std::string, std::vector<double>> groups;
        
        for (int r = 2; r <= lastRow; r++) {
            std::string rowKey = "";
            for (const auto& rf : rowFields) {
                std::string colLetter = colNameToLetter[rf];
                if (colLetter.empty()) continue;
                EvalResult eval = GridManager::getInstance().evaluateCell(colLetter + std::to_string(r));
                if (!rowKey.empty()) rowKey += "|";
                if (std::holds_alternative<std::string>(eval)) rowKey += std::get<std::string>(eval);
                else if (std::holds_alternative<double>(eval)) rowKey += std::to_string(std::get<double>(eval));
            }

            std::string colKey = "";
            for (const auto& cf : colFields) {
                std::string colLetter = colNameToLetter[cf];
                if (colLetter.empty()) continue;
                EvalResult eval = GridManager::getInstance().evaluateCell(colLetter + std::to_string(r));
                if (!colKey.empty()) colKey += "|";
                if (std::holds_alternative<std::string>(eval)) colKey += std::get<std::string>(eval);
                else if (std::holds_alternative<double>(eval)) colKey += std::to_string(std::get<double>(eval));
            }

            std::string dataColLetter = colNameToLetter[dataFields[0]];
            if (dataColLetter.empty()) continue;
            EvalResult dataEval = GridManager::getInstance().evaluateCell(dataColLetter + std::to_string(r));
            double dataVal = 0.0;
            if (std::holds_alternative<double>(dataEval)) dataVal = std::get<double>(dataEval);

            std::string combinedKey = rowKey;
            if (!colKey.empty()) combinedKey += "||" + colKey;
            
            groups[combinedKey].push_back(dataVal);
        }

        // 3. Aggregate
        json groupedData = json::object();
        json flatData = json::array();

        for (auto const& [key, vals] : groups) {
            double aggVal = 0;
            if (aggType == "SUM") { for(double v : vals) aggVal += v; }
            else if (aggType == "AVERAGE") { double sum = 0; for(double v : vals) sum += v; aggVal = vals.empty() ? 0 : sum / vals.size(); }
            else if (aggType == "COUNT") { aggVal = vals.size(); }
            else if (aggType == "MIN") { aggVal = vals.empty() ? 0 : vals[0]; for(double v : vals) if(v < aggVal) aggVal = v; }
            else if (aggType == "MAX") { aggVal = vals.empty() ? 0 : vals[0]; for(double v : vals) if(v > aggVal) aggVal = v; }
            else { for(double v : vals) aggVal += v; }

            // Extract rowKey and colKey
            std::string rowKey = key;
            std::string colKey = "";
            size_t pos = key.find("||");
            if (pos != std::string::npos) {
                rowKey = key.substr(0, pos);
                colKey = key.substr(pos + 2);
            }

            // Create flat map
            json rowJson = json::object();
            if (!rowFields.empty()) rowJson[rowFields[0]] = rowKey;
            if (!colFields.empty()) rowJson[colFields[0]] = colKey;
            rowJson[dataFields[0]] = aggVal;
            flatData.push_back(rowJson);

            // Create grouped map
            if (groupedData.find(rowKey) == groupedData.end()) {
                groupedData[rowKey] = json::object();
            }
            if (colKey.empty()) {
                groupedData[rowKey][dataFields[0]] = aggVal;
            } else {
                groupedData[rowKey][colKey] = aggVal;
            }
        }

        json finalResult = json::object();
        finalResult["groupedData"] = groupedData;
        finalResult["flatData"] = flatData;
        finalResult["rowFields"] = rowFields;
        finalResult["colFields"] = colFields;
        finalResult["dataFields"] = dataFields;

        return allocFfiString(finalResult.dump());
    } catch (const std::exception& e) {
         return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

// --- BI Analytics: Big Data Chart Downsampling Engine ---
FFI_EXPORT char* getChartData(const char* requestJson) {
    try {
        if (!requestJson) return allocFfiString("{\"error\":\"Empty request\"}");
        auto req = json::parse(requestJson);
        
        std::string xField = req.value("xField", "");
        std::string yField = req.value("yField", "");
        int maxPoints = req.value("maxPoints", 500);

        int lastRow = GridManager::getInstance().getLastRow();
        int lastCol = GridManager::getInstance().getLastColumn();

        // Map column names
        std::map<std::string, std::string> colNameToLetter;
        for (int c = 0; c <= lastCol; c++) {
            std::string colLetter = "";
            int temp = c;
            while (temp >= 0) { colLetter = char('A' + (temp % 26)) + colLetter; temp = temp / 26 - 1; }
            std::string headerRef = colLetter + "1";
            EvalResult headerEval = GridManager::getInstance().evaluateCell(headerRef);
            if (std::holds_alternative<std::string>(headerEval)) {
                colNameToLetter[std::get<std::string>(headerEval)] = colLetter;
            } else {
                colNameToLetter[colLetter] = colLetter; 
            }
        }

        std::string xCol = colNameToLetter[xField];
        std::string yCol = colNameToLetter[yField];

        if (yCol.empty()) return allocFfiString("{\"error\":\"Y Field not found\"}");

        // Gather raw data
        struct Point { std::string xStr; double yVal; };
        std::vector<Point> rawData;

        for (int r = 2; r <= lastRow; r++) {
            Point p;
            if (!xCol.empty()) {
                EvalResult xEval = GridManager::getInstance().evaluateCell(xCol + std::to_string(r));
                if (std::holds_alternative<std::string>(xEval)) p.xStr = std::get<std::string>(xEval);
                else if (std::holds_alternative<double>(xEval)) p.xStr = std::to_string(std::get<double>(xEval));
                else p.xStr = "Row " + std::to_string(r);
            } else {
                p.xStr = "Row " + std::to_string(r);
            }

            EvalResult yEval = GridManager::getInstance().evaluateCell(yCol + std::to_string(r));
            if (std::holds_alternative<double>(yEval)) p.yVal = std::get<double>(yEval);
            else continue; // Skip non-numeric Y values

            rawData.push_back(p);
        }

        // Downsample using Min-Max chunking
        json resultData = json::array();
        if (rawData.size() <= (size_t)maxPoints) {
            for (const auto& p : rawData) {
                resultData.push_back({{"x", p.xStr}, {"y", p.yVal}});
            }
        } else {
            int chunkSize = rawData.size() / (maxPoints / 2);
            for (size_t i = 0; i < rawData.size(); i += chunkSize) {
                size_t end = std::min(i + chunkSize, rawData.size());
                
                size_t minIdx = i, maxIdx = i;
                for (size_t j = i + 1; j < end; j++) {
                    if (rawData[j].yVal < rawData[minIdx].yVal) minIdx = j;
                    if (rawData[j].yVal > rawData[maxIdx].yVal) maxIdx = j;
                }
                
                // Add min and max in order of appearance
                if (minIdx <= maxIdx) {
                    resultData.push_back({{"x", rawData[minIdx].xStr}, {"y", rawData[minIdx].yVal}});
                    if (minIdx != maxIdx) resultData.push_back({{"x", rawData[maxIdx].xStr}, {"y", rawData[maxIdx].yVal}});
                } else {
                    resultData.push_back({{"x", rawData[maxIdx].xStr}, {"y", rawData[maxIdx].yVal}});
                    resultData.push_back({{"x", rawData[minIdx].xStr}, {"y", rawData[minIdx].yVal}});
                }
            }
        }

        json finalResult = json::object();
        finalResult["data"] = resultData;
        finalResult["downsampled"] = (rawData.size() > (size_t)maxPoints);
        finalResult["originalCount"] = rawData.size();
        
        return allocFfiString(finalResult.dump());
    } catch (const std::exception& e) {
         return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

// ── SOTA Data Cleaning & Row Alignment FFI Exports ─────────────────────────────

char* detect_shifted_rows() {
    try {
        std::string rawGrid = GridManager::getInstance().getRawGrid();
        if (rawGrid.empty() || rawGrid == "{}") {
            return allocFfiString("[]");
        }

        auto gridMap = nlohmann::json::parse(rawGrid);
        int lastRow = GridManager::getInstance().getLastRow();
        int maxCol = 0;

        for (auto it = gridMap.begin(); it != gridMap.end(); ++it) {
            std::string key = it.key();
            std::string colLetter;
            for (char c : key) if (std::isalpha((unsigned char)c)) colLetter += c;
            int idx = 0;
            for (char c : colLetter) idx = idx * 26 + (std::toupper((unsigned char)c) - 'A' + 1);
            if (idx > maxCol) maxCol = idx;
        }

        std::vector<std::vector<std::string>> matrix(lastRow + 1, std::vector<std::string>(maxCol, ""));
        for (int r = 1; r <= lastRow; ++r) {
            for (int c = 1; c <= maxCol; ++c) {
                std::string colName = "";
                int temp = c;
                while (temp > 0) {
                    int rem = (temp - 1) % 26;
                    colName = char('A' + rem) + colName;
                    temp = (temp - 1) / 26;
                }
                std::string ref = colName + std::to_string(r);
                if (gridMap.contains(ref)) {
                    matrix[r][c - 1] = gridMap[ref].get<std::string>();
                }
            }
        }

        std::vector<Filters::ShiftedRowReport> reports = Filters::RowAligner::getInstance().detectShiftedRows(matrix, true);
        nlohmann::json out = nlohmann::json::array();
        for (const auto& rep : reports) {
            out.push_back({
                {"rowIndex", rep.rowIndex},
                {"detectedShift", rep.detectedShift},
                {"confidence", rep.confidence},
                {"reason", rep.reason},
                {"originalRow", rep.originalRow},
                {"alignedRow", rep.alignedRow}
            });
        }
        return allocFfiString(out.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* apply_grid_row_alignment() {
    try {
        std::string rawGrid = GridManager::getInstance().getRawGrid();
        if (rawGrid.empty() || rawGrid == "{}") {
            return allocFfiString("{\"alignedRows\":0}");
        }

        auto gridMap = nlohmann::json::parse(rawGrid);
        int lastRow = GridManager::getInstance().getLastRow();
        int maxCol = 0;

        for (auto it = gridMap.begin(); it != gridMap.end(); ++it) {
            std::string key = it.key();
            std::string colLetter;
            for (char c : key) if (std::isalpha((unsigned char)c)) colLetter += c;
            int idx = 0;
            for (char c : colLetter) idx = idx * 26 + (std::toupper((unsigned char)c) - 'A' + 1);
            if (idx > maxCol) maxCol = idx;
        }

        std::vector<std::vector<std::string>> matrix(lastRow + 1, std::vector<std::string>(maxCol, ""));
        for (int r = 1; r <= lastRow; ++r) {
            for (int c = 1; c <= maxCol; ++c) {
                std::string colName = "";
                int temp = c;
                while (temp > 0) {
                    int rem = (temp - 1) % 26;
                    colName = char('A' + rem) + colName;
                    temp = (temp - 1) / 26;
                }
                std::string ref = colName + std::to_string(r);
                if (gridMap.contains(ref)) {
                    matrix[r][c - 1] = gridMap[ref].get<std::string>();
                }
            }
        }

        auto reports = Filters::RowAligner::getInstance().detectShiftedRows(matrix, true);
        auto aligned = Filters::RowAligner::getInstance().alignGrid(matrix, true);

        // Update grid manager
        for (size_t r = 1; r < aligned.size(); ++r) {
            for (size_t c = 0; c < aligned[r].size(); ++c) {
                std::string colName = "";
                int temp = static_cast<int>(c) + 1;
                while (temp > 0) {
                    int rem = (temp - 1) % 26;
                    colName = char('A' + rem) + colName;
                    temp = (temp - 1) / 26;
                }
                std::string ref = colName + std::to_string(r);
                GridManager::getInstance().setCellConstantString(ref, aligned[r][c]);
            }
        }

        nlohmann::json res;
        res["status"] = "success";
        res["realignedRowsCount"] = reports.size();
        return allocFfiString(res.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* split_delimited_cell_ffi(const char* cellValue, const char* delimiters) {
    if (!cellValue) return allocFfiString("[]");
    std::string delims = (delimiters && strlen(delimiters) > 0) ? delimiters : ",|;\t/";
    std::vector<std::string> tokens = Filters::RowAligner::splitDelimitedCell(cellValue, delims);
    nlohmann::json j = tokens;
    return allocFfiString(j.dump());
}

char* clean_currency_number_ffi(const char* rawCurrency) {
    if (!rawCurrency) return allocFfiString("");
    std::string cleaned = Filters::ExtremeCleaningEngine::cleanNumericString(rawCurrency, true);
    return allocFfiString(cleaned);
}

char* clean_column_dates_ffi(const char* colLetter, int targetFormat) {
    if (!colLetter) return allocFfiString("{\"status\":\"error\",\"message\":\"Column letter is null\"}");
    try {
        std::string colUpper = colLetter;
        for (char& c : colUpper) c = std::toupper((unsigned char)c);

        std::string rawGrid = GridManager::getInstance().getRawGrid();
        if (rawGrid.empty() || rawGrid == "{}") {
            return allocFfiString("{\"status\":\"success\",\"cleanedCount\":0}");
        }

        auto gridMap = nlohmann::json::parse(rawGrid);
        int lastRow = GridManager::getInstance().getLastRow();

        std::vector<std::string> rawValues;
        std::vector<std::string> cellRefs;

        for (int r = 2; r <= lastRow; ++r) {
            std::string ref = colUpper + std::to_string(r);
            if (gridMap.contains(ref)) {
                rawValues.push_back(gridMap[ref].get<std::string>());
            } else {
                rawValues.push_back("");
            }
            cellRefs.push_back(ref);
        }

        Filters::DateOutputFormat outFmt = static_cast<Filters::DateOutputFormat>(targetFormat);
        auto cleaned = Filters::DateCleaner::getInstance().cleanColumn(rawValues, outFmt);

        int count = 0;
        for (size_t i = 0; i < cleaned.size(); ++i) {
            if (!cleaned[i].empty() && cleaned[i] != rawValues[i]) {
                GridManager::getInstance().setCellConstantString(cellRefs[i], cleaned[i]);
                count++;
            }
        }

        nlohmann::json res;
        res["status"] = "success";
        res["cleanedCount"] = count;
        return allocFfiString(res.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* stitch_multi_line_records_ffi() {
    try {
        std::string rawGrid = GridManager::getInstance().getRawGrid();
        if (rawGrid.empty() || rawGrid == "{}") {
            return allocFfiString("{\"status\":\"success\",\"stitchedRows\":0,\"eliminatedRows\":0}");
        }

        auto gridMap = nlohmann::json::parse(rawGrid);
        int lastRow = GridManager::getInstance().getLastRow();
        int maxCol = 0;

        for (auto it = gridMap.begin(); it != gridMap.end(); ++it) {
            std::string key = it.key();
            std::string colLetter;
            for (char c : key) if (std::isalpha((unsigned char)c)) colLetter += c;
            int idx = 0;
            for (char c : colLetter) idx = idx * 26 + (std::toupper((unsigned char)c) - 'A' + 1);
            if (idx > maxCol) maxCol = idx;
        }

        std::vector<std::vector<std::string>> matrix(lastRow + 1, std::vector<std::string>(maxCol, ""));
        for (int r = 1; r <= lastRow; ++r) {
            for (int c = 1; c <= maxCol; ++c) {
                std::string colName = "";
                int temp = c;
                while (temp > 0) {
                    int rem = (temp - 1) % 26;
                    colName = char('A' + rem) + colName;
                    temp = (temp - 1) / 26;
                }
                std::string ref = colName + std::to_string(r);
                if (gridMap.contains(ref)) {
                    matrix[r][c - 1] = gridMap[ref].get<std::string>();
                }
            }
        }

        // Stitch records
        auto stitchRes = Filters::RecordStitcher::getInstance().stitchGrid(matrix, true);

        // Clear grid and repopulate with stitched matrix
        GridManager::getInstance().clearGrid();
        for (size_t r = 1; r < stitchRes.cleanGrid.size(); ++r) {
            for (size_t c = 0; c < stitchRes.cleanGrid[r].size(); ++c) {
                if (!stitchRes.cleanGrid[r][c].empty()) {
                    std::string colName = "";
                    int temp = static_cast<int>(c) + 1;
                    while (temp > 0) {
                        int rem = (temp - 1) % 26;
                        colName = char('A' + rem) + colName;
                        temp = (temp - 1) / 26;
                    }
                    std::string ref = colName + std::to_string(r);
                    GridManager::getInstance().setCellConstantString(ref, stitchRes.cleanGrid[r][c]);
                }
            }
        }

        nlohmann::json res;
        res["status"] = "success";
        res["stitchedRows"] = stitchRes.report.stitchedRowsCount;
        res["eliminatedChildRows"] = stitchRes.report.eliminatedChildRows;
        res["detectedAnchorCol"] = stitchRes.report.detectedAnchorCol;
        return allocFfiString(res.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* demix_column_entities_ffi(const char* colLetter) {
    if (!colLetter) return allocFfiString("{\"status\":\"error\",\"message\":\"Column is null\"}");
    try {
        std::string colUpper = colLetter;
        for (char& c : colUpper) c = std::toupper((unsigned char)c);

        std::string rawGrid = GridManager::getInstance().getRawGrid();
        if (rawGrid.empty() || rawGrid == "{}") {
            return allocFfiString("{\"status\":\"success\",\"extracted\":0}");
        }

        auto gridMap = nlohmann::json::parse(rawGrid);
        int lastRow = GridManager::getInstance().getLastRow();

        std::vector<std::string> rawValues;
        for (int r = 2; r <= lastRow; ++r) {
            std::string ref = colUpper + std::to_string(r);
            if (gridMap.contains(ref)) {
                rawValues.push_back(gridMap[ref].get<std::string>());
            } else {
                rawValues.push_back("");
            }
        }

        auto demixRes = Filters::MixedCellDeMixer::getInstance().demixColumn(rawValues);

        // Calculate target column starting index
        int srcColIdx = 0;
        for (char c : colUpper) srcColIdx = srcColIdx * 26 + (c - 'A' + 1);

        // Write header and extracted columns to the right of the table
        for (size_t colOffset = 0; colOffset < demixRes.columnHeaders.size(); ++colOffset) {
            int targetColNum = srcColIdx + 1 + static_cast<int>(colOffset);
            std::string colName = "";
            int temp = targetColNum;
            while (temp > 0) {
                int rem = (temp - 1) % 26;
                colName = char('A' + rem) + colName;
                temp = (temp - 1) / 26;
            }

            // Set Header in Row 1
            GridManager::getInstance().setCellConstantString(colName + "1", demixRes.columnHeaders[colOffset]);

            // Set Data in Row 2..N
            for (size_t r = 0; r < demixRes.matrix.size(); ++r) {
                if (!demixRes.matrix[r][colOffset].empty()) {
                    GridManager::getInstance().setCellConstantString(colName + std::to_string(r + 2), demixRes.matrix[r][colOffset]);
                }
            }
        }

        nlohmann::json res;
        res["status"] = "success";
        res["extractedCount"] = demixRes.successfullyExtractedCount;
        res["createdColumns"] = demixRes.columnHeaders;
        return allocFfiString(res.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* isolate_subtotals_and_clean_ffi() {
    try {
        std::string rawGrid = GridManager::getInstance().getRawGrid();
        if (rawGrid.empty() || rawGrid == "{}") {
            return allocFfiString("{\"status\":\"success\",\"removedNoiseRows\":0}");
        }

        auto gridMap = nlohmann::json::parse(rawGrid);
        int lastRow = GridManager::getInstance().getLastRow();
        int maxCol = 0;

        for (auto it = gridMap.begin(); it != gridMap.end(); ++it) {
            std::string key = it.key();
            std::string colLetter;
            for (char c : key) if (std::isalpha((unsigned char)c)) colLetter += c;
            int idx = 0;
            for (char c : colLetter) idx = idx * 26 + (std::toupper((unsigned char)c) - 'A' + 1);
            if (idx > maxCol) maxCol = idx;
        }

        std::vector<std::vector<std::string>> matrix(lastRow + 1, std::vector<std::string>(maxCol, ""));
        for (int r = 1; r <= lastRow; ++r) {
            for (int c = 1; c <= maxCol; ++c) {
                std::string colName = "";
                int temp = c;
                while (temp > 0) {
                    int rem = (temp - 1) % 26;
                    colName = char('A' + rem) + colName;
                    temp = (temp - 1) / 26;
                }
                std::string ref = colName + std::to_string(r);
                if (gridMap.contains(ref)) {
                    matrix[r][c - 1] = gridMap[ref].get<std::string>();
                }
            }
        }

        auto isoRes = Filters::SubtotalIsolator::getInstance().isolateSubtotals(matrix, true);

        // Repopulate grid with isolated pure data matrix
        GridManager::getInstance().clearGrid();
        for (size_t r = 1; r < isoRes.cleanGrid.size(); ++r) {
            for (size_t c = 0; c < isoRes.cleanGrid[r].size(); ++c) {
                if (!isoRes.cleanGrid[r][c].empty()) {
                    std::string colName = "";
                    int temp = static_cast<int>(c) + 1;
                    while (temp > 0) {
                        int rem = (temp - 1) % 26;
                        colName = char('A' + rem) + colName;
                        temp = (temp - 1) / 26;
                    }
                    std::string ref = colName + std::to_string(r);
                    GridManager::getInstance().setCellConstantString(ref, isoRes.cleanGrid[r][c]);
                }
            }
        }

        nlohmann::json res;
        res["status"] = "success";
        res["removedNoiseRowsCount"] = isoRes.removedNoiseRowsCount;
        res["isolatedSubtotalsCount"] = isoRes.isolatedSubtotals.size();
        return allocFfiString(res.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* run_data_pipeline_tests_ffi() {
    try {
        DataPipeline::TestRunner::runAllTests();
        return allocFfiString("{\"status\":\"success\",\"message\":\"All SOTA cleaning and pipeline tests passed!\"}");
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"status\":\"error\",\"message\":\"") + e.what() + "\"}");
    }
}

static std::pair<std::string, std::string> detectNameAndEmailCols(const char* nameColInput, const char* emailColInput) {
    std::string nameCol = nameColInput ? nameColInput : "";
    std::string emailCol = emailColInput ? emailColInput : "";

    while (!nameCol.empty() && std::isspace((unsigned char)nameCol.front())) nameCol.erase(0, 1);
    while (!nameCol.empty() && std::isspace((unsigned char)nameCol.back())) nameCol.pop_back();
    while (!emailCol.empty() && std::isspace((unsigned char)emailCol.front())) emailCol.erase(0, 1);
    while (!emailCol.empty() && std::isspace((unsigned char)emailCol.back())) emailCol.pop_back();

    if (!nameCol.empty() && !emailCol.empty()) {
        std::transform(nameCol.begin(), nameCol.end(), nameCol.begin(), ::toupper);
        std::transform(emailCol.begin(), emailCol.end(), emailCol.begin(), ::toupper);
        return {nameCol, emailCol};
    }

    // Auto-detect from Row 1 headers
    int maxCols = 26;
    for (int c = 0; c < maxCols; c++) {
        std::string colLetter(1, 'A' + c);
        std::string headerCell = colLetter + "1";
        if (GridManager::getInstance().isCellEmpty(headerCell)) continue;

        EvalResult res = GridManager::getInstance().evaluateCell(headerCell);
        std::string h;
        if (std::holds_alternative<std::string>(res)) h = std::get<std::string>(res);
        std::string lowerH = h;
        std::transform(lowerH.begin(), lowerH.end(), lowerH.begin(), ::tolower);

        if (emailCol.empty()) {
            if (lowerH.find("email") != std::string::npos || lowerH.find("mail") != std::string::npos) {
                emailCol = colLetter;
            }
        }
        if (nameCol.empty()) {
            if (lowerH.find("name") != std::string::npos || lowerH.find("customer") != std::string::npos ||
                lowerH.find("person") != std::string::npos || lowerH.find("client") != std::string::npos ||
                lowerH.find("user") != std::string::npos) {
                nameCol = colLetter;
            }
        }
    }

    // Fallback detection via ColumnAnalyzer if headers didn't match
    if (emailCol.empty() || nameCol.empty()) {
        for (int c = 0; c < maxCols; c++) {
            std::string colLetter(1, 'A' + c);
            if (colLetter == emailCol || colLetter == nameCol) continue;
            auto analysis = Filters::ColumnAnalyzer::getInstance().analyze(colLetter, false);
            if (emailCol.empty() && analysis.dominantType == Filters::DataType::EMAIL) {
                emailCol = colLetter;
            } else if (nameCol.empty() && analysis.dominantType == Filters::DataType::TEXT) {
                nameCol = colLetter;
            }
        }
    }

    return {nameCol, emailCol};
}

char* native_extractNamesFromEmails(const char* nameColLetter, const char* emailColLetter) {
    try {
        auto [nameCol, emailCol] = detectNameAndEmailCols(nameColLetter, emailColLetter);

        if (emailCol.empty()) {
            return allocFfiString("{\"status\":\"INACTIVE\",\"message\":\"No Email column detected. Engine is OFF.\",\"candidates\":[]}");
        }
        if (nameCol.empty()) {
            return allocFfiString("{\"status\":\"INACTIVE\",\"message\":\"No Name column detected. Engine is OFF.\",\"candidates\":[]}");
        }

        int lastRow = GridManager::getInstance().getLastRow();
        nlohmann::json candidates = nlohmann::json::array();
        int totalMissingNames = 0;
        int dismissedCount = 0;

        for (int r = 2; r <= lastRow; r++) {
            std::string nameRef = nameCol + std::to_string(r);
            std::string emailRef = emailCol + std::to_string(r);

            // Check if name cell is empty
            bool nameIsEmpty = true;
            if (!GridManager::getInstance().isCellEmpty(nameRef)) {
                EvalResult nRes = GridManager::getInstance().evaluateCell(nameRef);
                std::string nVal;
                if (std::holds_alternative<std::string>(nRes)) nVal = std::get<std::string>(nRes);
                while (!nVal.empty() && std::isspace((unsigned char)nVal.front())) nVal.erase(0, 1);
                while (!nVal.empty() && std::isspace((unsigned char)nVal.back())) nVal.pop_back();
                if (!nVal.empty()) nameIsEmpty = false;
            }

            if (!nameIsEmpty) continue; // Existing name is intact! Do not touch!
            totalMissingNames++;

            if (GridManager::getInstance().isCellEmpty(emailRef)) continue;
            EvalResult eRes = GridManager::getInstance().evaluateCell(emailRef);
            std::string emailVal;
            if (std::holds_alternative<std::string>(eRes)) emailVal = std::get<std::string>(eRes);
            if (emailVal.empty()) continue;

            auto extracted = Filters::NameFromEmailCleaner::extractName(emailVal);
            if (extracted.isValidHumanName) {
                nlohmann::json cand;
                cand["row"] = r;
                cand["name_cell"] = nameRef;
                cand["email_cell"] = emailRef;
                cand["email"] = emailVal;
                cand["extracted_name"] = extracted.fullName;
                cand["first_name"] = extracted.firstName;
                cand["last_name"] = extracted.lastName;
                cand["confidence"] = extracted.confidence;
                candidates.push_back(cand);
            } else {
                dismissedCount++;
            }
        }

        nlohmann::json res;
        res["status"] = "SUCCESS";
        res["name_column"] = nameCol;
        res["email_column"] = emailCol;
        res["total_missing_names"] = totalMissingNames;
        res["extracted_count"] = candidates.size();
        res["dismissed_count"] = dismissedCount;
        res["candidates"] = candidates;
        return allocFfiString(res.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* native_imputeNamesFromEmails(const char* nameColLetter, const char* emailColLetter) {
    try {
        auto [nameCol, emailCol] = detectNameAndEmailCols(nameColLetter, emailColLetter);

        if (emailCol.empty() || nameCol.empty()) {
            return allocFfiString("{\"status\":\"INACTIVE\",\"message\":\"Email or Name column missing. Engine is OFF.\",\"imputed_count\":0}");
        }

        int lastRow = GridManager::getInstance().getLastRow();
        nlohmann::json imputedList = nlohmann::json::array();
        int imputedCount = 0;
        int dismissedCount = 0;

        for (int r = 2; r <= lastRow; r++) {
            std::string nameRef = nameCol + std::to_string(r);
            std::string emailRef = emailCol + std::to_string(r);

            // Check if name cell is empty
            bool nameIsEmpty = true;
            if (!GridManager::getInstance().isCellEmpty(nameRef)) {
                EvalResult nRes = GridManager::getInstance().evaluateCell(nameRef);
                std::string nVal;
                if (std::holds_alternative<std::string>(nRes)) nVal = std::get<std::string>(nRes);
                while (!nVal.empty() && std::isspace((unsigned char)nVal.front())) nVal.erase(0, 1);
                while (!nVal.empty() && std::isspace((unsigned char)nVal.back())) nVal.pop_back();
                if (!nVal.empty()) nameIsEmpty = false;
            }

            if (!nameIsEmpty) continue; // Preserve existing names!

            if (GridManager::getInstance().isCellEmpty(emailRef)) continue;
            EvalResult eRes = GridManager::getInstance().evaluateCell(emailRef);
            std::string emailVal;
            if (std::holds_alternative<std::string>(eRes)) emailVal = std::get<std::string>(eRes);
            if (emailVal.empty()) continue;

            auto extracted = Filters::NameFromEmailCleaner::extractName(emailVal);
            if (extracted.isValidHumanName && !extracted.fullName.empty()) {
                GridManager::getInstance().setCellConstantString(nameRef, extracted.fullName);
                imputedCount++;

                nlohmann::json item;
                item["cell"] = nameRef;
                item["name"] = extracted.fullName;
                item["email"] = emailVal;
                imputedList.push_back(item);
            } else {
                dismissedCount++;
            }
        }

        nlohmann::json res;
        res["status"] = "SUCCESS";
        res["imputed_count"] = imputedCount;
        res["dismissed_count"] = dismissedCount;
        res["name_column"] = nameCol;
        res["email_column"] = emailCol;
        res["imputations"] = imputedList;
        return allocFfiString(res.dump());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

char* native_guardedFillDown(const char* groupColLetter, const char* anchorColLetter) {
    try {
        std::string gCol = groupColLetter ? groupColLetter : "A";
        std::string aCol = anchorColLetter ? anchorColLetter : "B";
        while (!gCol.empty() && std::isspace((unsigned char)gCol.front())) gCol.erase(0, 1);
        while (!gCol.empty() && std::isspace((unsigned char)gCol.back())) gCol.pop_back();
        while (!aCol.empty() && std::isspace((unsigned char)aCol.front())) aCol.erase(0, 1);
        while (!aCol.empty() && std::isspace((unsigned char)aCol.back())) aCol.pop_back();

        auto res = Filters::GuardedFillDown::getInstance().execute(gCol, aCol);
        return allocFfiString(res.toJson());
    } catch (const std::exception& e) {
        return allocFfiString(std::string("{\"error\":\"") + e.what() + "\"}");
    }
}

#ifdef __cplusplus
}
#endif

