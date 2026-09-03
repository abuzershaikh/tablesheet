#ifndef TRANSACTION_ENGINE_H
#define TRANSACTION_ENGINE_H

#include "../pipeline/pipeline_step.h"
#include <vector>
#include <string>
#include <unordered_map>

namespace DataPipeline {

// Delta tracker saves only modified states to save memory on 10M rows.
struct CellDelta {
    std::string originalValue;
};

class TransactionSnapshot {
public:
    std::vector<uint8_t> originalRowVisibility;
    // Map of row -> (col -> cell delta)
    std::unordered_map<int, std::unordered_map<int, CellDelta>> cellDeltas;
};

class TransactionEngine {
public:
    static TransactionEngine& getInstance() {
        static TransactionEngine instance;
        return instance;
    }
    
    // Begins a transaction. Copies visibility bitmap and initializes delta tracking.
    void beginTransaction(const PipelineContext& ctx);
    
    // Commits changes. Flushes the delta tracker.
    void commit();
    
    // Rolls back changes using the snapshot and the context callbacks.
    void rollback(PipelineContext& ctx);
    
    // Track a cell change before it happens.
    void trackCellChange(int row, int col, const std::string& originalVal);

private:
    TransactionEngine() = default;
    
    bool inTransaction = false;
    TransactionSnapshot snapshot;
};

} // namespace DataPipeline

#endif // TRANSACTION_ENGINE_H
