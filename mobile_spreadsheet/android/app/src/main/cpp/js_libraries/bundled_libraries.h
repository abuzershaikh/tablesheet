#ifndef BUNDLED_LIBRARIES_H
#define BUNDLED_LIBRARIES_H

#include <string>
#include <unordered_map>

extern "C" {
#include "../quickjs/quickjs.h"
}

namespace JsLibraries {

// Returns the full JavaScript source code for a bundled library by module name
// (e.g., "dayjs", "formulajs", "fuse.js", "fuse", "currency.js", "currency", "regression", "papaparse")
std::string getLibrarySource(const std::string& name);

// Binds all bundled libraries to globalThis in the given JSContext
void bindAllGlobals(JSContext* ctx);

// QuickJS module loader hook for bundled libraries
JSModuleDef* loadModule(JSContext* ctx, const char* module_name);

// Checks if a module name is known as a bundled library
bool isBundledModule(const std::string& name);

} // namespace JsLibraries

#endif // BUNDLED_LIBRARIES_H
