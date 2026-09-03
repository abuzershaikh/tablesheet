# CMakeLists.txt for Mobile Spreadsheet with Vulkan Support
cmake_minimum_required(VERSION 3.22.1)

project("mobile_spreadsheet")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fexceptions -frtti")

# Vulkan support
set(USE_VULKAN 1)

# QuickJS sources
set(QUICKJS_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/quickjs/quickjs.c
    ${CMAKE_CURRENT_SOURCE_DIR}/quickjs/cutils.c
    ${CMAKE_CURRENT_SOURCE_DIR}/quickjs/libregexp.c
    ${CMAKE_CURRENT_SOURCE_DIR}/quickjs/libunicode.c
    ${CMAKE_CURRENT_SOURCE_DIR}/quickjs/dtoa.c
)

set_source_files_properties(${QUICKJS_SOURCES} PROPERTIES COMPILE_FLAGS "-Wno-array-bounds -Wno-unused-parameter")

file(GLOB_RECURSE FUNCTION_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/functions/*.cpp" 
    "${CMAKE_CURRENT_SOURCE_DIR}/functions/*/*.cpp"
)

file(GLOB_RECURSE CF_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/conditional_formatting/*.cpp"
)

set(DATA_ENGINE_SOURCES
    data_engine/engine/filter_engine.cpp
    data_engine/detector/data_detector.cpp
    # Advanced Detector Plugins (data_engine/detector/plugins/)
    data_engine/detector/plugins/phone_plugin.cpp
    data_engine/detector/plugins/email_plugin.cpp
    data_engine/detector/plugins/currency_plugin.cpp
    data_engine/detector/plugins/name_plugin.cpp
    data_engine/detector/plugins/id_plugin.cpp
    data_engine/detector/plugins/url_plugin.cpp
    data_engine/detector/plugins/category_plugin.cpp
    # Plugin Registry (data_engine/detector/plugin_registry.cpp)
    data_engine/detector/plugin_registry.cpp
    # Validator Module (data_engine/validator/)  — Detect vs Validate
    # PhoneValidator: 9999999999 detected but INVALID (repeating)
    # GstValidator: 15-char structural validation
    # AadhaarValidator: Verhoeff D5 checksum
    data_engine/validator/phone_validator.cpp
    data_engine/validator/email_validator.cpp
    data_engine/validator/gst_validator.cpp
    data_engine/validator/aadhaar_validator.cpp
    data_engine/validator/date_validator.cpp
    # Data Cleaning Module (data_engine/cleaning/)
    data_engine/cleaning/data_cleaner.cpp
    data_engine/cleaning/phone_cleaner.cpp
    data_engine/cleaning/email_cleaner.cpp
    data_engine/cleaning/date_cleaner.cpp
    data_engine/cleaning/text_cleaner.cpp
    data_engine/cleaning/mojibake_cleaner.cpp
    data_engine/cleaning/unit_cleaner.cpp
    data_engine/cleaning/imputation_engine.cpp
    data_engine/cleaning/address_cleaner.cpp
    data_engine/cleaning/extreme_cleaning_engine.cpp
    data_engine/cleaning/row_aligner.cpp
    data_engine/cleaning/record_stitcher.cpp
    data_engine/cleaning/mixed_cell_demixer.cpp

    # Column & Sheet Analyzer (data_engine/analyzer/)
    data_engine/analyzer/column_analyzer.cpp
    data_engine/analyzer/sheet_summarizer.cpp
    data_engine/analyzer/header_flattener.cpp
    data_engine/analyzer/subtotal_isolator.cpp
    # ── Phase 3: Sheet Brain Modules ──────────────────────────────
    # Brain / Context Compressor (data_engine/brain/)
    # Compresses 100k cells → 300-token AI context
    data_engine/brain/context_compressor.cpp
    # Semantic Brain (data_engine/semantic/)
    # Paid/Pending → Status, Apple/Mango → Fruit (no regex!)
    data_engine/semantic/semantic_detector.cpp
    # Fuzzy Cluster Engine (data_engine/cluster/)
    # OpenRefine-style: Samsung/Samsng/SAMSUNG → cluster → Samsung
    data_engine/cluster/levenshtein.cpp
    data_engine/cluster/phonetic_matcher.cpp
    data_engine/cluster/cluster_engine.cpp
    # Column Profiler + Pattern Learner (data_engine/profiler/)
    # entropy, minLen, maxLen, ABC###-pattern learning
    data_engine/profiler/column_profiler.cpp
    # Quality Scorer (data_engine/quality/)
    # 6-dimension: Completeness, Consistency, Uniqueness, Validity, Accuracy, Integrity
    data_engine/quality/quality_scorer.cpp

    # Pattern Intelligence Engine (data_engine/pattern_intelligence/)
    data_engine/pattern_intelligence/sequence_pattern.cpp
    data_engine/pattern_intelligence/relational_pattern.cpp
    data_engine/pattern_intelligence/anomaly_detector.cpp
    data_engine/pattern_intelligence/repair_suggester.cpp

    # Enterprise Pivot Engine (data_engine/pivot/)
    data_engine/pivot/pivot_cache_engine.cpp
    data_engine/pivot/group_engine.cpp
    data_engine/pivot/aggregation_engine.cpp
    data_engine/pivot/slicer_engine.cpp

    # Existing modules
    data_engine/rules/phone_filter.cpp
    data_engine/rules/text_filter.cpp
    data_engine/rules/number_filter.cpp
    data_engine/rules/rule_group.cpp
    data_engine/rules/rule_parser.cpp
    data_engine/cache/type_cache.cpp
    data_engine/engine/preview_engine.cpp
    data_engine/engine/pipeline_executor.cpp
    data_engine/pipeline/steps/filter_step.cpp
    data_engine/pipeline/steps/fill_data_step.cpp
    data_engine/pipeline/steps/script_step.cpp
    data_engine/pipeline/pipeline_registry.cpp
    data_engine/pipeline/chunk_reader.cpp
    data_engine/stats/statistics_engine.cpp
    data_engine/validation/validation_engine.cpp
    data_engine/engine/pipeline_validator.cpp
    data_engine/engine/transaction_engine.cpp
    data_engine/tests/test_runner.cpp
    data_engine/history/history_manager.cpp
)

# Add your native library
add_library(
    native_lib
    SHARED
    native-lib.cpp
    jni_bridge.cpp
    vulkan_renderer.cpp
    spreadsheet_compute.cpp
    ffi_bridge.cpp
    ast.cpp
    parser.cpp
    dag.cpp
    evaluator.cpp
    function_registry.cpp
    grid_manager.cpp
    js_engine.cpp
    ${QUICKJS_SOURCES}
    ${FUNCTION_SOURCES}
    ${CF_SOURCES}
    ${DATA_ENGINE_SOURCES}
)

# Find required libraries
find_library(
    log-lib
    log
)

find_library(
    android-lib
    android
)

# Vulkan library (available on API 24+)
find_library(
    vulkan-lib
    vulkan
)

# Link libraries
target_link_libraries(
    native_lib
    ${log-lib}
    ${android-lib}
    ${vulkan-lib}
)

# Include Vulkan headers & C++ source directory
target_include_directories(
    native_lib PRIVATE
    ${ANDROID_NDK}/sources/third_party/vulkan/src/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Compile definitions
target_compile_definitions(
    native_lib PRIVATE
    USE_VULKAN=1
    VK_USE_PLATFORM_ANDROID_KHR
    CONFIG_VERSION="2024-01-13"
)
