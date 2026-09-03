#ifndef ERROR_CODES_H
#define ERROR_CODES_H

namespace DataPipeline {
namespace ErrorCodes {

// Core Pipeline Execution
constexpr int SUCCESS = 0;
constexpr int ERR_EXECUTION_EXCEPTION = 500;
constexpr int ERR_JSON_MALFORMED = 103;

// Validation & Security
constexpr int ERR_SCHEMA_MISSING_STEPS = 100;
constexpr int ERR_SCHEMA_MISSING_TYPE = 101;
constexpr int ERR_SECURITY_UNREGISTERED_STEP = 102;

// Data Step Errors
constexpr int ERR_INVALID_COLUMN = 200;
constexpr int ERR_TYPE_MISMATCH = 201;
constexpr int ERR_DEPENDENCY_MISSING = 202;

} // namespace ErrorCodes
} // namespace DataPipeline

#endif // ERROR_CODES_H
