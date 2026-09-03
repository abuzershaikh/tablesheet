/*
 * mixed_cell_demixer.h  —  Universal Multi-Entity Cell De-Mixer
 *
 * Unpacks chaotic cells containing Name, Phone, Email, GSTIN, Amount, and Address
 * into separate structured columns.
 *
 * Folder: android/app/src/main/cpp/data_engine/cleaning/
 */
#ifndef MIXED_CELL_DEMIXER_H
#define MIXED_CELL_DEMIXER_H

#include <string>
#include <vector>

namespace Filters {

struct DeMixedRecord {
    std::string name;
    std::string phone;
    std::string email;
    std::string gstin;
    std::string amount;
    std::string addressOrNotes;
    bool isValid = false;
};

struct DeMixColumnResult {
    std::vector<std::string> columnHeaders;
    std::vector<std::vector<std::string>> matrix;
    int successfullyExtractedCount = 0;
};

class MixedCellDeMixer {
public:
    static MixedCellDeMixer& getInstance() {
        static MixedCellDeMixer instance;
        return instance;
    }

    // De-mix single text string into structured entities
    DeMixedRecord demixCell(const std::string& rawText) const;

    // De-mix an entire column into a multi-column structured grid
    DeMixColumnResult demixColumn(const std::vector<std::string>& columnValues) const;

private:
    MixedCellDeMixer() = default;
};

} // namespace Filters

#endif // MIXED_CELL_DEMIXER_H
