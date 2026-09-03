#include "dag.h"
#include <stdexcept>
#include <algorithm>

void DAGManager::clear() {
    dependsOn.clear();
    dependentsOf.clear();
}

void DAGManager::addDependency(const std::string& dependent, const std::string& dependency) {
    dependsOn[dependent].insert(dependency);
    dependentsOf[dependency].insert(dependent);
}

void DAGManager::setDependencies(const std::string& dependent, const std::unordered_set<std::string>& dependencies) {
    auto it = dependsOn.find(dependent);
    if (it != dependsOn.end()) {
        for (const auto& oldDep : it->second) {
            dependentsOf[oldDep].erase(dependent);
        }
    }
    
    if (dependencies.empty()) {
        dependsOn.erase(dependent);
    } else {
        dependsOn[dependent] = dependencies;
        for (const auto& dep : dependencies) {
            dependentsOf[dep].insert(dependent);
        }
    }
}

void DAGManager::removeCell(const std::string& cell) {
    setDependencies(cell, {});
}

std::vector<std::string> DAGManager::getCalculationOrder(const std::vector<std::string>& startCells) {
    std::vector<std::string> result;
    std::unordered_set<std::string> visited;
    std::unordered_set<std::string> visiting;

    // Use lambda for recursive DFS
    auto visit = [&](auto& self, const std::string& cell) -> void {
        if (visited.count(cell)) return;
        if (visiting.count(cell)) {
            throw std::runtime_error("Circular dependency detected!");
        }

        visiting.insert(cell);

        auto it = dependentsOf.find(cell);
        if (it != dependentsOf.end()) {
            for (const auto& dep : it->second) {
                self(self, dep);
            }
        }

        visiting.erase(cell);
        visited.insert(cell);
        result.push_back(cell);
    };

    for (const auto& cell : startCells) {
        visit(visit, cell);
    }

    std::reverse(result.begin(), result.end());
    return result;
}
