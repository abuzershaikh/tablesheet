#ifndef PIPELINE_STEP_H
#define PIPELINE_STEP_H

#include <string>
#include <vector>
#include <memory>
#include "../../json.hpp"
#include <functional>

namespace DataPipeline {

enum class ExecutionStatus {
    SUCCESS,
    WARNING,
    RETRYABLE_ERROR,
    FATAL_ERROR
};

struct PipelineResult {
    ExecutionStatus status = ExecutionStatus::SUCCESS;
    int errorCode = 0;
    std::string message;
    int rowNumber = -1; // -1 if not applicable
    
    bool isSuccess() const { return status == ExecutionStatus::SUCCESS || status == ExecutionStatus::WARNING; }
};

// Data payload passed between steps
struct PipelineContext {
    std::string sheetId;
    int totalRows;
    int totalCols;
    
    // Callback to read original data
    std::function<std::string(int row, int col)> getCellVal;
    
    // Callback to write transformed data
    std::function<void(int row, int col, const std::string& val)> setCellVal;

    // Bitmaps and state
    std::vector<uint8_t> rowVisibility;
    nlohmann::json metadata;

    // Streaming / Chunking support
    int chunkStartIndex = 0;
    int chunkRowCount = 0;
    bool isLastChunk = true;
};

/**
 * @brief [FROZEN API] IPipelineStep
 * 
 * This interface is frozen and guaranteed not to change. It serves as the
 * core contract for all data pipeline plugins. Third-party developers and
 * internal modules can safely implement this interface.
 */
class IPipelineStep {
public:
    virtual ~IPipelineStep() = default;
    
    // Step Name (e.g. "DetectType", "Filter", "Clean")
    virtual std::string getName() const = 0;
    
    // Execute step on the context
    virtual PipelineResult execute(PipelineContext& ctx) = 0;
    
    // Initialize step with config
    virtual void configure(const nlohmann::json& config) = 0;
};

} // namespace DataPipeline

#endif // PIPELINE_STEP_H
