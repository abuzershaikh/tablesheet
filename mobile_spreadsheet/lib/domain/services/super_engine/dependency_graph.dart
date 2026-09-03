class DependencyGraph {
  // mapping from a cell to the cells it depends on
  final Map<String, Set<String>> _dependsOn = {};
  
  // mapping from a cell to the cells that depend on it
  final Map<String, Set<String>> _dependentsOf = {};

  void clear() {
    _dependsOn.clear();
    _dependentsOf.clear();
  }

  void addDependency(String dependent, String dependency) {
    _dependsOn.putIfAbsent(dependent, () => {}).add(dependency);
    _dependentsOf.putIfAbsent(dependency, () => {}).add(dependent);
  }

  void setDependencies(String dependent, Set<String> dependencies) {
    // Remove old dependencies
    final oldDeps = _dependsOn[dependent] ?? {};
    for (final oldDep in oldDeps) {
      _dependentsOf[oldDep]?.remove(dependent);
    }
    
    // Set new dependencies
    if (dependencies.isEmpty) {
      _dependsOn.remove(dependent);
    } else {
      _dependsOn[dependent] = Set.from(dependencies);
      for (final dep in dependencies) {
        _dependentsOf.putIfAbsent(dep, () => {}).add(dependent);
      }
    }
  }

  void removeCell(String cell) {
    setDependencies(cell, {});
    // Also remove from any cells depending on this, but we don't alter their formulas here
  }

  /// Returns a topologically sorted list of cells that need to be recalculated
  /// when the given [startCells] are modified.
  /// Throws an exception if a circular dependency is detected.
  List<String> getCalculationOrder(List<String> startCells) {
    final result = <String>[];
    final visited = <String>{};
    final visiting = <String>{}; // For cycle detection

    void visit(String cell) {
      if (visited.contains(cell)) return;
      if (visiting.contains(cell)) {
        throw const FormatException("Circular dependency detected!");
      }

      visiting.add(cell);

      // Visit all cells that depend on this one
      final dependents = _dependentsOf[cell] ?? {};
      for (final dep in dependents) {
        visit(dep);
      }

      visiting.remove(cell);
      visited.add(cell);
      result.add(cell); // Add to result after dependents are processed
    }

    for (final cell in startCells) {
      visit(cell);
    }

    return result.reversed.toList();
  }
}
