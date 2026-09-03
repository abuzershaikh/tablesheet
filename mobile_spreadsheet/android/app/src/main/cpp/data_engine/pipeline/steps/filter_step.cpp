#include "filter_step.h"
#include "../../rules/rule_parser.h"

namespace DataPipeline {

void FilterStep::configure(const nlohmann::json& config) {
    if (config.contains("column") && config["column"].is_number()) {
        targetColumn = config["column"].get<int>();
    }
    if (config.contains("rule")) {
        rule = Filters::parseRuleNode(config["rule"]); // Need to expose parseRuleNode or use RuleParser::parse
    }
}

PipelineResult FilterStep::execute(PipelineContext& ctx) {
    if (!rule || targetColumn < 0) return {ExecutionStatus::SUCCESS, 0, "", -1};
    
    // Ensure visibility bitmap is initialized
    if (ctx.rowVisibility.empty() && ctx.totalRows > 0) {
        ctx.rowVisibility.assign(ctx.totalRows, 1);
    }
    
    int endRow = ctx.chunkStartIndex + ctx.chunkRowCount;
    if (endRow > ctx.totalRows) endRow = ctx.totalRows;
    
    for (int r = ctx.chunkStartIndex; r < endRow; ++r) {
        if (r < ctx.rowVisibility.size() && ctx.rowVisibility[r] == 0) continue; // Already hidden
        
        Filters::FilterContext fCtx;
        fCtx.row = r;
        fCtx.col = targetColumn;
        fCtx.cellValue = ctx.getCellVal(r, targetColumn);
        try {
            fCtx.numericValue = std::stod(fCtx.cellValue);
        } catch (...) {
            fCtx.numericValue = __builtin_nan("");
        }
        
        if (!rule->evaluate(fCtx)) {
            if (r < ctx.rowVisibility.size()) ctx.rowVisibility[r] = 0;
        }
    }
    
    return {ExecutionStatus::SUCCESS, 0, "", -1};
}

} // namespace DataPipeline
