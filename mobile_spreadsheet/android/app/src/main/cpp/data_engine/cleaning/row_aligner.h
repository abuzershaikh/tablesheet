/*
 * row_aligner.h  —  Enterprise Shifted Row Alignment & Multi-Value Splitter
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 *
 * Solves:
 *   1. Right-Shifted Rows: unescaped commas in CSV push entries 1-2 columns right
 *   2. Left-Shifted Rows: missing values causing early collapse
 *   3. Multi-Value Unpacking: splits "Item1, Item2" or "Name | Phone | City"
 */
#pragma once
#include <string>
#include <vector>
#include "../detector/data_detector.h"

namespace Filters {

struct ShiftedRowReport {
    int rowIndex = 0;
    int detectedShift = 0; // +1 = right shifted, -1 = left shifted
    float confidence = 0.0f;
    std::string reason = "";
    std::vector<std::string> originalRow;
    std::vector<std::string> alignedRow;
};

class RowAligner {
public:
    static RowAligner& getInstance() {
        static RowAligner inst;
        return inst;
    }

    /// Detect expected column types for each column across the grid
    std::vector<DataType> profileColumnTypes(const std::vector<std::vector<std::string>>& grid,
                                             bool hasHeader = true) const;

    /// Scan grid and identify rows that are shifted or misaligned
    std::vector<ShiftedRowReport> detectShiftedRows(
        const std::vector<std::vector<std::string>>& grid,
        bool hasHeader = true) const;

    /// Auto-align a single row based on expected column signature
    std::vector<std::string> alignRow(
        const std::vector<std::string>& row,
        const std::vector<DataType>& expectedTypes,
        int* detectedShift = nullptr) const;

    /// Auto-align entire grid (repairs shifted rows in-place)
    std::vector<std::vector<std::string>> alignGrid(
        const std::vector<std::vector<std::string>>& grid,
        bool hasHeader = true) const;

    /// Split multi-value delimited cell into parts
    static std::vector<std::string> splitDelimitedCell(const std::string& cell,
                                                        const std::string& customDelimiters = ",|;\t/");

private:
    RowAligner() = default;
    static float computeRowTypeMatch(const std::vector<std::string>& row,
                                     const std::vector<DataType>& types,
                                     int offset);
};

} // namespace Filters
