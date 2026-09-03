#ifndef JNI_BRIDGE_H
#define JNI_BRIDGE_H

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

// Vulkan functions
JNIEXPORT jint JNICALL getVulkanVersion(JNIEnv* env, jobject thiz);
JNIEXPORT jint JNICALL initVulkan(JNIEnv* env, jobject thiz);
JNIEXPORT void JNICALL cleanupVulkan(JNIEnv* env, jobject thiz);
JNIEXPORT jint JNICALL createSurface(JNIEnv* env, jobject thiz, jint width, jint height);
JNIEXPORT void JNICALL destroySurface(JNIEnv* env, jobject thiz);
JNIEXPORT void JNICALL renderFrame(JNIEnv* env, jobject thiz);

// Progress callback functions
JNIEXPORT void JNICALL setProgressListener(JNIEnv* env, jobject thiz, jobject listener);
void notifyJavaProgress(int current, int total);

#ifdef __cplusplus
}
#endif

#endif // JNI_BRIDGE_H