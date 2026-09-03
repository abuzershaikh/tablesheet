import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Native render engine for Vulkan graphics rendering
class NativeRenderEngine {
  static DynamicLibrary? _dylib;
  static bool _initialized = false;

  // Native function signatures
  late final int Function() _getVulkanVersion;
  late final int Function() _initVulkan;
  late final void Function() _cleanupVulkan;
  late final int Function(int, int) _createSurface;
  late final void Function() _destroySurface;
  late final void Function() _renderFrame;

  /// Initialize the native library
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load the native library
      if (Platform.isAndroid) {
        _dylib = DynamicLibrary.open('libnative_lib.so');
      } else {
        throw UnsupportedError('Unsupported platform');
      }

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize native library: $e');
    }
  }

  /// Create instance of NativeRenderEngine
  NativeRenderEngine() {
    if (!_initialized || _dylib == null) {
      throw StateError('Native library not initialized. Call initialize() first.');
    }

    // Bind native functions
    _getVulkanVersion = _dylib!
        .lookup<NativeFunction<Int32 Function()>>('getVulkanVersion')
        .asFunction();

    _initVulkan = _dylib!
        .lookup<NativeFunction<Int32 Function()>>('initVulkan')
        .asFunction();

    _cleanupVulkan = _dylib!
        .lookup<NativeFunction<Void Function()>>('cleanupVulkan')
        .asFunction();

    _createSurface = _dylib!
        .lookup<NativeFunction<Int32 Function(Int32, Int32)>>('createSurface')
        .asFunction();

    _destroySurface = _dylib!
        .lookup<NativeFunction<Void Function()>>('destroySurface')
        .asFunction();

    _renderFrame = _dylib!
        .lookup<NativeFunction<Void Function()>>('renderFrame')
        .asFunction();
  }

  /// Get Vulkan API version
  int getVulkanVersion() {
    try {
      return _getVulkanVersion();
    } catch (e) {
      throw Exception('Failed to get Vulkan version: $e');
    }
  }

  /// Initialize Vulkan graphics
  Future<bool> initializeVulkan() async {
    try {
      final result = _initVulkan();
      return result == 1; // 1 = success, 0 = failure
    } catch (e) {
      throw Exception('Failed to initialize Vulkan: $e');
    }
  }

  /// Create rendering surface
  Future<bool> createSurface(int width, int height) async {
    try {
      final result = _createSurface(width, height);
      return result == 1; // 1 = success, 0 = failure
    } catch (e) {
      throw Exception('Failed to create surface: $e');
    }
  }

  /// Render a frame
  void renderFrame() {
    try {
      _renderFrame();
    } catch (e) {
      throw Exception('Failed to render frame: $e');
    }
  }

  /// Cleanup Vulkan resources
  void cleanup() {
    try {
      _destroySurface();
      _cleanupVulkan();
    } catch (e) {
      throw Exception('Failed to cleanup Vulkan: $e');
    }
  }

  /// Check if Vulkan is supported on device
  static Future<bool> isVulkanSupported() async {
    try {
      await initialize();
      final engine = NativeRenderEngine();
      final version = engine.getVulkanVersion();
      return version > 0;
    } catch (e) {
      return false; // Vulkan not supported
    }
  }
}