#include <jni.h>
#include <string>
#include <android/log.h>
#include "vulkan_renderer.h"
#include "spreadsheet_compute.h"

#define LOG_TAG "MobileSpreadsheet"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global instances
static VulkanRenderer* vulkanRenderer = nullptr;
static SpreadsheetCompute* computeEngine = nullptr;

extern "C" JNIEXPORT jstring JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_stringFromJNI(
        JNIEnv* env,
        jobject /* this */) {
    std::string message = "Mobile Spreadsheet - Native C++ Library with Vulkan Support Initialized";
    LOGI("Native C++ library loaded successfully");
    return env->NewStringUTF(message.c_str());
}

// Initialize Vulkan Renderer
extern "C" JNIEXPORT jboolean JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_initializeVulkan(
        JNIEnv* env,
        jobject /* this */) {
    
    LOGI("Initializing Vulkan...");
    
    if (vulkanRenderer == nullptr) {
        vulkanRenderer = new VulkanRenderer();
    }
    
    bool success = vulkanRenderer->initialize();
    
    if (success) {
        LOGI("Vulkan initialized successfully - GPU acceleration enabled");
        
        // Initialize compute engine with GPU support
        if (computeEngine == nullptr) {
            computeEngine = new SpreadsheetCompute();
        }
        computeEngine->enableGPUCompute(true);
    } else {
        LOGE("Vulkan initialization failed - falling back to CPU rendering");
    }
    
    return success ? JNI_TRUE : JNI_FALSE;
}

// Check Vulkan support
extern "C" JNIEXPORT jboolean JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_isVulkanSupported(
        JNIEnv* env,
        jobject /* this */) {
    
    if (vulkanRenderer != nullptr) {
        return vulkanRenderer->isVulkanSupported() ? JNI_TRUE : JNI_FALSE;
    }
    return JNI_FALSE;
}

// Example function for spreadsheet calculations
extern "C" JNIEXPORT jdouble JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_calculateSum(
        JNIEnv* env,
        jobject /* this */,
        jdoubleArray numbers) {
    
    jsize length = env->GetArrayLength(numbers);
    jdouble* elements = env->GetDoubleArrayElements(numbers, nullptr);
    
    std::vector<double> values(elements, elements + length);
    
    double sum = 0.0;
    if (computeEngine != nullptr) {
        sum = computeEngine->sumRange(values);
    } else {
        // Fallback calculation
        for (int i = 0; i < length; i++) {
            sum += elements[i];
        }
    }
    
    env->ReleaseDoubleArrayElements(numbers, elements, 0);
    
    LOGI("Calculated sum: %f", sum);
    return sum;
}

// GPU-accelerated average calculation
extern "C" JNIEXPORT jdouble JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_calculateAverage(
        JNIEnv* env,
        jobject /* this */,
        jdoubleArray numbers) {
    
    jsize length = env->GetArrayLength(numbers);
    if (length == 0) return 0.0;
    
    jdouble* elements = env->GetDoubleArrayElements(numbers, nullptr);
    std::vector<double> values(elements, elements + length);
    env->ReleaseDoubleArrayElements(numbers, elements, 0);
    
    if (computeEngine != nullptr) {
        return computeEngine->averageRange(values);
    }
    
    return 0.0;
}

// Render spreadsheet grid with Vulkan
extern "C" JNIEXPORT void JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_renderGrid(
        JNIEnv* env,
        jobject /* this */,
        jint rows,
        jint cols) {
    
    if (vulkanRenderer != nullptr) {
        vulkanRenderer->renderSpreadsheetGrid(rows, cols);
    } else {
        LOGE("Vulkan renderer not initialized");
    }
}

// Optimize scrolling performance
extern "C" JNIEXPORT void JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_optimizeScrolling(
        JNIEnv* env,
        jobject /* this */) {
    
    if (vulkanRenderer != nullptr) {
        vulkanRenderer->optimizeScrolling();
    }
}

// Cleanup on app close
extern "C" JNIEXPORT void JNICALL
Java_com_tablenotes_sheets_excelsheet_spreadsheet_MainActivity_cleanupNative(
        JNIEnv* env,
        jobject /* this */) {
    
    LOGI("Cleaning up native resources...");
    
    if (computeEngine != nullptr) {
        delete computeEngine;
        computeEngine = nullptr;
    }
    
    if (vulkanRenderer != nullptr) {
        delete vulkanRenderer;
        vulkanRenderer = nullptr;
    }
    
    LOGI("Native cleanup complete");
}
