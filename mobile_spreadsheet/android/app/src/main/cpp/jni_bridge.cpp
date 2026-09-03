#include "jni_bridge.h"
#include "vulkan_renderer.h"
#include <android/log.h>

#define LOG_TAG "JNI_Bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global Vulkan renderer instance
static VulkanRenderer* g_renderer = nullptr;

// Global progress callback for JNI
static JavaVM* g_jvm = nullptr;
static jobject g_progress_listener = nullptr;

extern "C" {

// JNI callback for progress updates
void notifyJavaProgress(int current, int total) {
    if (g_jvm == nullptr || g_progress_listener == nullptr) return;
    
    JNIEnv* env = nullptr;
    if (g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK) return;
    
    jclass listenerClass = env->GetObjectClass(g_progress_listener);
    jmethodID method = env->GetMethodID(listenerClass, "onProgress", "(II)V");
    
    if (method != nullptr) {
        env->CallVoidMethod(g_progress_listener, method, current, total);
    }
}

// Set progress listener from Java
JNIEXPORT void JNICALL setProgressListener(JNIEnv* env, jobject thiz, jobject listener) {
    LOGI("setProgressListener called");
    
    // Get JavaVM for later use
    if (g_jvm == nullptr) {
        env->GetJavaVM(&g_jvm);
    }
    
    // Clean up old listener
    if (g_progress_listener != nullptr) {
        env->DeleteGlobalRef(g_progress_listener);
    }
    
    // Set new listener (create global reference)
    if (listener != nullptr) {
        g_progress_listener = env->NewGlobalRef(listener);
    } else {
        g_progress_listener = nullptr;
    }
}

JNIEXPORT jint JNICALL getVulkanVersion(JNIEnv* env, jobject thiz) {
    LOGI("getVulkanVersion called");
    
    if (g_renderer == nullptr) {
        g_renderer = new VulkanRenderer();
    }
    
    return g_renderer->getVulkanVersion();
}

JNIEXPORT jint JNICALL initVulkan(JNIEnv* env, jobject thiz) {
    LOGI("initVulkan called");
    
    try {
        if (g_renderer == nullptr) {
            g_renderer = new VulkanRenderer();
        }
        
        bool success = g_renderer->initialize();
        return success ? 1 : 0;
        
    } catch (const std::exception& e) {
        LOGE("Exception in initVulkan: %s", e.what());
        return 0;
    }
}

JNIEXPORT void JNICALL cleanupVulkan(JNIEnv* env, jobject thiz) {
    LOGI("cleanupVulkan called");
    
    if (g_renderer != nullptr) {
        g_renderer->cleanup();
        delete g_renderer;
        g_renderer = nullptr;
    }
}

JNIEXPORT jint JNICALL createSurface(JNIEnv* env, jobject thiz, jint width, jint height) {
    LOGI("createSurface called: width=%d, height=%d", width, height);
    
    if (g_renderer == nullptr) {
        LOGE("Renderer not initialized");
        return 0;
    }
    
    try {
        bool success = g_renderer->createSurface(width, height);
        return success ? 1 : 0;
        
    } catch (const std::exception& e) {
        LOGE("Exception in createSurface: %s", e.what());
        return 0;
    }
}

JNIEXPORT void JNICALL destroySurface(JNIEnv* env, jobject thiz) {
    LOGI("destroySurface called");
    
    if (g_renderer != nullptr) {
        g_renderer->destroySurface();
    }
}

JNIEXPORT void JNICALL renderFrame(JNIEnv* env, jobject thiz) {
    if (g_renderer != nullptr) {
        g_renderer->renderFrame();
    }
}

} // extern "C"