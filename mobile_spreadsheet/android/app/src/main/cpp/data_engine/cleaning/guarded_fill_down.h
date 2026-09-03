#pragma once
#include <string>
#include <vector>

namespace Filters {

struct GuardedFillDownResult {
    int filledCount = 0;
    int skippedRows = 0;
    std::string groupColumn;
    std::string anchorColumn;
    std::vector<std::string> modifiedCells;
    std::string toJson() const;
};

class GuardedFillDown {
public:
    static GuardedFillDown& getInstance() {
        static GuardedFillDown instance;
        return instance;
    }

    /**
     * Executes guarded fill-down on groupCol using anchorCol as the child presence proof.
     * Stops at Total/Subtotal rows. Skips empty spacer rows.
     */
    GuardedFillDownResult execute(const std::string& groupCol, const std::string& anchorCol);

    /**
     * Checks if a string represents a subtotal/summary boundary.
     */
    static bool isSubtotalBoundary(const std::string& text);

private:
    GuardedFillDown() = default;
};

} // namespace Filters
