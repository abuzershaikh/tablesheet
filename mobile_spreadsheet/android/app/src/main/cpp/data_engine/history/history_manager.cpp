#include "history_manager.h"

namespace DataPipeline {

void HistoryManager::executeCommand(std::shared_ptr<ICommand> command) {
    if (command) {
        command->execute();
        undoStack.push_back(command);
        redoStack.clear(); // Executing a new command clears redo history
    }
}

bool HistoryManager::undo() {
    if (undoStack.empty()) return false;
    
    auto command = undoStack.back();
    undoStack.pop_back();
    command->undo();
    redoStack.push_back(command);
    return true;
}

bool HistoryManager::redo() {
    if (redoStack.empty()) return false;
    
    auto command = redoStack.back();
    redoStack.pop_back();
    command->execute();
    undoStack.push_back(command);
    return true;
}

void HistoryManager::clear() {
    undoStack.clear();
    redoStack.clear();
}

} // namespace DataPipeline
