#ifndef VULKAN_RENDERER_H
#define VULKAN_RENDERER_H

#ifdef USE_VULKAN

#include <vulkan/vulkan.h>
#include <android/log.h>
#include <vector>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "VulkanRenderer", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "VulkanRenderer", __VA_ARGS__)

class VulkanRenderer {
public:
    VulkanRenderer();
    ~VulkanRenderer();
    
    bool initialize();
    void cleanup();
    bool isVulkanSupported();
    
    // JNI bridge functions
    int getVulkanVersion();
    bool createSurface(int width, int height);
    void destroySurface();
    void renderFrame();
    
    // Spreadsheet specific functions
    void renderSpreadsheetGrid(int rows, int cols);
    void optimizeScrolling();
    
private:
    VkInstance instance = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    VkQueue queue = VK_NULL_HANDLE;
    
    bool createInstance();
    bool pickPhysicalDevice();
    bool createLogicalDevice();
    
    bool vulkanSupported = false;
};

#endif // USE_VULKAN

#endif // VULKAN_RENDERER_H
