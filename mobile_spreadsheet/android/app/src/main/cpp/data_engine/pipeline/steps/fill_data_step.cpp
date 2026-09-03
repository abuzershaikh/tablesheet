#include "fill_data_step.h"

namespace DataPipeline {

void FillDataStep::configure(const nlohmann::json& config) {
    if (config.contains("startRow") && config["startRow"].is_number()) {
        startRow = config["startRow"].get<int>();
    }
    if (config.contains("startColumn") && config["startColumn"].is_number()) {
        startColumn = config["startColumn"].get<int>();
    }
    if (config.contains("values") && config["values"].is_array()) {
        for (const auto& rowJson : config["values"]) {
            if (rowJson.is_array()) {
                std::vector<std::string> rowData;
                for (const auto& cellJson : rowJson) {
                    if (cellJson.is_string()) {
                        rowData.push_back(cellJson.get<std::string>());
                    } else if (cellJson.is_number()) {
                        if (cellJson.is_number_integer()) {
                            rowData.push_back(std::to_string(cellJson.get<long long>()));
                        } else {
                            rowData.push_back(std::to_string(cellJson.get<double>()));
                        }
                    } else if (cellJson.is_boolean()) {
                        rowData.push_back(cellJson.get<bool>() ? "TRUE" : "FALSE");
                    } else {
                        rowData.push_back("");
                    }
                }
                values.push_back(rowData);
            }
        }
    }
}

PipelineResult FillDataStep::execute(PipelineContext& ctx) {
    if (values.empty()) return {ExecutionStatus::SUCCESS, 0, "No data to fill", -1};
    
    for (size_t r = 0; r < values.size(); ++r) {
        for (size_t c = 0; c < values[r].size(); ++c) {
            if (ctx.setCellVal) {
                ctx.setCellVal(startRow + r, startColumn + c, values[r][c]);
            }
        }
    }
    
    return {ExecutionStatus::SUCCESS, 0, "Data filled successfully", -1};
}

} // namespace DataPipeline
