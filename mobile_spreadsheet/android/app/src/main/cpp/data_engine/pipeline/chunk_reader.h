#ifndef CHUNK_READER_H
#define CHUNK_READER_H

#include "pipeline_step.h"
#include <memory>
#include <functional>

namespace DataPipeline {

class IChunkReader {
public:
    virtual ~IChunkReader() = default;
    
    // Setup the reader and populate the initial context (e.g. totalRows, totalCols if known)
    virtual bool init(PipelineContext& ctx) = 0;
    
    // Read the next chunk into ctx. Updates ctx.chunkStartIndex, chunkRowCount, isLastChunk
    // Returns true if a chunk was successfully read (even if it's the last one).
    virtual bool readNextChunk(PipelineContext& ctx) = 0;
};

// A concrete implementation for reading from our in-memory grid via callbacks
class GridChunkReader : public IChunkReader {
public:
    GridChunkReader(int chunkSize = 10000) : chunkSize(chunkSize) {}
    
    bool init(PipelineContext& ctx) override;
    bool readNextChunk(PipelineContext& ctx) override;

private:
    int chunkSize;
    int currentRow = 0;
};

} // namespace DataPipeline

#endif // CHUNK_READER_H
