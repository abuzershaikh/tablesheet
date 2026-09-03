#ifndef SPREADSHEET_COMPUTE_H
#define SPREADSHEET_COMPUTE_H

#ifdef USE_VULKAN
#include <vulkan/vulkan.h>
#endif

#include <android/log.h>
#include <vector>
#include <string>

#ifndef LOGI
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "SpreadsheetCompute", __VA_ARGS__)
#endif
#ifndef LOGE
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "SpreadsheetCompute", __VA_ARGS__)
#endif

class SpreadsheetCompute {
public:
    SpreadsheetCompute();
    ~SpreadsheetCompute();
    
    // High-performance calculations
    double sumRange(const std::vector<double>& values);
    double averageRange(const std::vector<double>& values);
    std::vector<double> matrixMultiply(const std::vector<double>& a, const std::vector<double>& b, int size);
    
    // GPU-accelerated calculations (when Vulkan available)
    void enableGPUCompute(bool enable);
    bool isGPUComputeEnabled();
    
    // Bulk operations for large datasets
    std::vector<double> bulkCalculate(const std::vector<double>& data, const std::string& formula);
    std::vector<double> bulkMultiply(const std::vector<double>& prices, const std::vector<double>& quantities);
    
    // Statistical functions
    double standardDeviation(const std::vector<double>& values);
    double median(std::vector<double> values);
    
private:
    bool gpuComputeEnabled = false;
    
#ifdef USE_VULKAN
    VkDevice device = VK_NULL_HANDLE;
    VkQueue computeQueue = VK_NULL_HANDLE;
#endif
};

#endif // SPREADSHEET_COMPUTE_H
