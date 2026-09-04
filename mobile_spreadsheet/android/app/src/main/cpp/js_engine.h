#ifndef JS_ENGINE_H
#define JS_ENGINE_H

#include <string>
#include <vector>
#include <unordered_map>
#include <functional>
#include <mutex>
#include <algorithm>

extern "C" {
#include "quickjs/quickjs.h"
}

#include <chrono>

// Function signature for Dart fetch callback: (const char* url, const char* options_json) -> char* response_json
typedef char* (*DartFetchCallbackFn)(const char* url, const char* options_json);

struct TimeoutContext {
    std::chrono::steady_clock::time_point deadline;
    bool timedOut{false};
};

class JsEngine {
public:
    static JsEngine& getInstance();

    // Initialization & Destruction
    bool init();
    void cleanup();

    // Execution Timeout Configuration (default: 5000ms)
    void setTimeoutMs(int ms) { m_timeoutMs = ms; }
    int getTimeoutMs() const { return m_timeoutMs; }

    // Script Execution
    std::string evalScript(const std::string& code);
    std::string callJsFunction(const std::string& funcName, const std::vector<std::string>& jsonArgs);

    // User Custom Functions / Macros
    bool registerMacro(const std::string& name, const std::string& code);
    std::vector<std::string> getMacroNames();
    std::string getMacroCode(const std::string& name);

    // Trigger System
    void triggerOnEdit(const std::string& sheetName, const std::string& cellRef, const std::string& oldValue, const std::string& newValue);
    void triggerOnChange(const std::string& changeType);

    // Fetch API Callback (Dart Bridge for External APIs)
    void setFetchCallback(DartFetchCallbackFn callback);
    DartFetchCallbackFn getFetchCallback() const { return m_fetchCallback; }

    // QuickJS Helpers
    JSContext* getContext() const { return m_ctx; }
    JSRuntime* getRuntime() const { return m_rt; }

    // Console output buffer for IDE
    void appendConsole(const std::string& text);
    std::string popConsoleOutput();

    // UI Action Queue for Charts, Pivot Tables, and Selections
    void enqueueUiAction(const std::string& actionJson);
    std::vector<std::string> flushUiActions();

    // Static QuickJS Callbacks
    static int jsInterruptHandler(JSRuntime *rt, void *opaque);
    static JSModuleDef* jsModuleLoader(JSContext *ctx, const char *module_name, void *opaque);

private:
    JsEngine();
    ~JsEngine();

    void bindNativeApis();
    void bindConsole();
    void bindSpreadsheetApp();
    void bindFetch();
    void bindBundledLibraries();

    int m_timeoutMs{5000};

    JSRuntime* m_rt{nullptr};
    JSContext* m_ctx{nullptr};
    bool m_initialized{false};
    std::recursive_mutex m_mutex;
    std::string m_consoleBuffer;
    std::vector<std::string> m_uiActionQueue;

    DartFetchCallbackFn m_fetchCallback{nullptr};
    std::unordered_map<std::string, std::string> m_userMacros;
    std::vector<std::string> m_sheetNames{"Sheet1"};
    std::string m_activeSheet{"Sheet1"};

public:
    const std::vector<std::string>& getSheetNames() const { return m_sheetNames; }
    const std::string& getActiveSheetName() const { return m_activeSheet; }
    void addSheet(const std::string& name) {
        if (std::find(m_sheetNames.begin(), m_sheetNames.end(), name) == m_sheetNames.end()) {
            m_sheetNames.push_back(name);
        }
    }
    void renameActiveSheet(const std::string& newName) {
        for (auto& s : m_sheetNames) {
            if (s == m_activeSheet) {
                s = newName;
                break;
            }
        }
        m_activeSheet = newName;
    }
};

#endif // JS_ENGINE_H
