#ifndef ASYNC_WORKER_H
#define ASYNC_WORKER_H

#include <thread>
#include <future>
#include <functional>
#include <memory>
#include <mutex>

namespace DataPipeline {

class AsyncWorker {
public:
    static AsyncWorker& getInstance() {
        static AsyncWorker instance;
        return instance;
    }

    // Run a task in the background
    template<typename T>
    std::future<T> runAsync(std::function<T()> task) {
        return std::async(std::launch::async, task);
    }
    
    // Fire and forget
    void runFireAndForget(std::function<void()> task) {
        std::thread(task).detach();
    }

private:
    AsyncWorker() = default;
};

} // namespace DataPipeline

#endif // ASYNC_WORKER_H
