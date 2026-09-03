#include "transaction_engine.h"
#include <iostream>

namespace DataPipeline {

void TransactionEngine::beginTransaction(const PipelineContext& ctx) {
    if (inTransaction) {
        std::cerr << "Warning: Transaction already in progress!" << std::endl;
        return;
    }
    
    // Snapshot the current state
    snapshot.originalRowVisibility = ctx.rowVisibility;
    snapshot.cellDeltas.clear();
    
    inTransaction = true;
}

void TransactionEngine::commit() {
    if (!inTransaction) return;
    
    // Clear snapshot
    snapshot.originalRowVisibility.clear();
    snapshot.cellDeltas.clear();
    
    inTransaction = false;
}

void TransactionEngine::rollback(PipelineContext& ctx) {
    if (!inTransaction) return;
    
    // Revert visibility
    ctx.rowVisibility = snapshot.originalRowVisibility;
    
    // Revert all changed cells using the context's callback
    if (ctx.setCellVal) {
        for (const auto& rowPair : snapshot.cellDeltas) {
            int row = rowPair.first;
            for (const auto& colPair : rowPair.second) {
                int col = colPair.first;
                ctx.setCellVal(row, col, colPair.second.originalValue);
            }
        }
    }
    
    // Clean up
    commit(); 
}

void TransactionEngine::trackCellChange(int row, int col, const std::string& originalVal) {
    if (!inTransaction) return;
    
    // Only save the FIRST time it is changed in this transaction
    auto& rowMap = snapshot.cellDeltas[row];
    if (rowMap.find(col) == rowMap.end()) {
        rowMap[col] = {originalVal};
    }
}

} // namespace DataPipeline
