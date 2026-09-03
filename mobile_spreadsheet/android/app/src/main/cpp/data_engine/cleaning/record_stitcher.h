/*
 * record_stitcher.h  —  Multi-Line Record Stitcher for Wrapped Spreadsheet Data
 *
 * Reconstructs broken / multi-row records (e.g. from PDF/OCR or Tally/ERP reports)
 * where a single transaction spans across 2-4 physical rows.
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#ifndef RECORD_STITCHER_H
#define RECORD_STITCHER_H

#include <string>
#include <vector>
#include "../detector/data_detector.h"

namespace Filters {

struct StitchReport {
    int totalOriginalRows = 0;
    int stitchedRowsCount = 0;
    int eliminatedChildRows = 0;
    int detectedAnchorCol = -1;
    std::string strategy = "ANCHOR_SPARSITY";
};

struct StitchResult {
    std::vector<std::vector<std::string>> cleanGrid;
    StitchReport report;
};

class RecordStitcher {
public:
    static RecordStitcher& getInstance() {
        static RecordStitcher instance;
        return instance;
    }

    // Automatically detect primary anchor column and stitch multi-line rows
    StitchResult stitchGrid(
        const std::vector<std::vector<std::string>>& grid,
        bool hasHeader = true,
        int explicitAnchorCol = -1) const;

    // Detect the best anchor column index (e.g. ID, Date, Serial #)
    int detectAnchorColumn(
        const std::vector<std::vector<std::string>>& grid,
        bool hasHeader = true) const;

private:
    RecordStitcher() = default;
};

} // namespace Filters

#endif // RECORD_STITCHER_H
