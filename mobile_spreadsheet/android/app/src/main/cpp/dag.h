#ifndef SPREADSHEET_DAG_H
#define SPREADSHEET_DAG_H

#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

class DAGManager {
public:
    void clear();
    void addDependency(const std::string& dependent, const std::string& dependency);
    void setDependencies(const std::string& dependent, const std::unordered_set<std::string>& dependencies);
    void removeCell(const std::string& cell);
    
    // Returns topologically sorted list of cells that need recalculation
    std::vector<std::string> getCalculationOrder(const std::vector<std::string>& startCells);

private:
    std::unordered_map<std::string, std::unordered_set<std::string>> dependsOn;
    std::unordered_map<std::string, std::unordered_set<std::string>> dependentsOf;
};

#endif // SPREADSHEET_DAG_H
