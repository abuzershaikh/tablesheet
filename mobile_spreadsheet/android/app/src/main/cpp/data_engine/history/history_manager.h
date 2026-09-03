#ifndef HISTORY_MANAGER_H
#define HISTORY_MANAGER_H

#include <vector>
#include <memory>
#include <string>

namespace DataPipeline {

class ICommand {
public:
    virtual ~ICommand() = default;
    virtual void execute() = 0;
    virtual void undo() = 0;
    virtual std::string getDescription() const = 0;
};

class HistoryManager {
public:
    static HistoryManager& getInstance() {
        static HistoryManager instance;
        return instance;
    }

    void executeCommand(std::shared_ptr<ICommand> command);
    
    bool undo();
    bool redo();
    
    void clear();

private:
    HistoryManager() = default;
    
    std::vector<std::shared_ptr<ICommand>> undoStack;
    std::vector<std::shared_ptr<ICommand>> redoStack;
};

} // namespace DataPipeline

#endif // HISTORY_MANAGER_H
