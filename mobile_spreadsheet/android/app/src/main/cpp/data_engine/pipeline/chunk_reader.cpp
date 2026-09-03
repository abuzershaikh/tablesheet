#include "chunk_reader.h"
#include <algorithm>

namespace DataPipeline {

bool GridChunkReader::init(PipelineContext& ctx) {
    currentRow = 0;
    // Total rows/cols are assumed to be already set in ctx before init
    return ctx.totalRows > 0;
}

bool GridChunkReader::readNextChunk(PipelineContext& ctx) {
    if (currentRow >= ctx.totalRows) {
        return false;
    }

    ctx.chunkStartIndex = currentRow;
    ctx.chunkRowCount = std::min(chunkSize, ctx.totalRows - currentRow);
    currentRow += ctx.chunkRowCount;
    
    ctx.isLastChunk = (currentRow >= ctx.totalRows);
    
    // Resize visibility bitmap to accommodate this chunk, keeping previous state if needed
    if (ctx.rowVisibility.size() < (size_t)currentRow) {
        ctx.rowVisibility.resize(currentRow, 1);
    }
    
    return true;
}

} // namespace DataPipeline
