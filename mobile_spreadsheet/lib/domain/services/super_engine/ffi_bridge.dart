import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../ui_action_dispatcher.dart' as import_ui_dispatcher;

typedef InitComputeEngineC = Void Function();
typedef InitComputeEngineDart = void Function();

typedef CleanupComputeEngineC = Void Function();
typedef CleanupComputeEngineDart = void Function();

typedef EnableGPUComputeC = Void Function(Int32 enable);
typedef EnableGPUComputeDart = void Function(int enable);

typedef CalculateSumC = Double Function(Pointer<Double> values, Int32 count);
typedef CalculateSumDart = double Function(Pointer<Double> values, int count);

typedef CalculateAverageC = Double Function(Pointer<Double> values, Int32 count);
typedef CalculateAverageDart = double Function(Pointer<Double> values, int count);

typedef CalculateMedianC = Double Function(Pointer<Double> values, Int32 count);
typedef CalculateMedianDart = double Function(Pointer<Double> values, int count);

typedef CalculateStdDevC = Double Function(Pointer<Double> values, Int32 count);
typedef CalculateStdDevDart = double Function(Pointer<Double> values, int count);

typedef EvaluateFormulaStringC = Pointer<Utf8> Function(Pointer<Utf8> formula, Int32 currentRow, Int32 currentCol);
typedef EvaluateFormulaStringDart = Pointer<Utf8> Function(Pointer<Utf8> formula, int currentRow, int currentCol);

typedef SetNamedRangeC = Void Function(Pointer<Utf8> name, Double value);
typedef SetNamedRangeDart = void Function(Pointer<Utf8> name, double value);

typedef SetNamedRangeStringC = Void Function(Pointer<Utf8> name, Pointer<Utf8> value);
typedef SetNamedRangeStringDart = void Function(Pointer<Utf8> name, Pointer<Utf8> value);

typedef ClearNamedRangesC = Void Function();
typedef ClearNamedRangesDart = void Function();

typedef FreeStringC = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

typedef SetCellFormulaC = Void Function(Pointer<Utf8> cellRef, Pointer<Utf8> formula);
typedef SetCellFormulaDart = void Function(Pointer<Utf8> cellRef, Pointer<Utf8> formula);

typedef SetCellConstantC = Void Function(Pointer<Utf8> cellRef, Double value);
typedef SetCellConstantDart = void Function(Pointer<Utf8> cellRef, double value);

typedef SetCellConstantStringC = Void Function(Pointer<Utf8> cellRef, Pointer<Utf8> value);
typedef SetCellConstantStringDart = void Function(Pointer<Utf8> cellRef, Pointer<Utf8> value);

typedef ClearGridC = Void Function();
typedef ClearGridDart = void Function();

typedef GetLastRowC = Int32 Function();
typedef GetLastRowDart = int Function();

typedef NativeCalculateAll = Pointer<Utf8> Function();
typedef CalculateAllDart = Pointer<Utf8> Function();

typedef NativeGetRawGrid = Pointer<Utf8> Function();
typedef GetRawGridDart = Pointer<Utf8> Function();

typedef PasteDataBlockC = Pointer<Utf8> Function(Int32 startRow, Int32 startCol, Pointer<Utf8> csvText);
typedef PasteDataBlockDart = Pointer<Utf8> Function(int startRow, int startCol, Pointer<Utf8> csvText);

typedef CopyDataBlockC = Pointer<Utf8> Function(Int32 startRow, Int32 startCol, Int32 endRow, Int32 endCol);
typedef CopyDataBlockDart = Pointer<Utf8> Function(int startRow, int startCol, int endRow, int endCol);

typedef ResetFormulaProgressC = Void Function();
typedef ResetFormulaProgressDart = void Function();

typedef GetFormulaProgressCurrentC = Int32 Function();
typedef GetFormulaProgressCurrentDart = int Function();

typedef GetFormulaProgressTotalC = Int32 Function();
typedef GetFormulaProgressTotalDart = int Function();

typedef IsFormulaProgressActiveC = Int32 Function();
typedef IsFormulaProgressActiveDart = int Function();

// Conditional Formatting FFI
typedef CFAddRuleC = Void Function(Pointer<Utf8> sheetId, Pointer<Utf8> ruleJson);
typedef CFAddRuleDart = void Function(Pointer<Utf8> sheetId, Pointer<Utf8> ruleJson);

typedef CFRemoveRuleC = Void Function(Pointer<Utf8> sheetId, Pointer<Utf8> ruleId);
typedef CFRemoveRuleDart = void Function(Pointer<Utf8> sheetId, Pointer<Utf8> ruleId);

typedef CFReorderRuleC = Void Function(Pointer<Utf8> sheetId, Pointer<Utf8> ruleId, Int32 newPriority);
typedef CFReorderRuleDart = void Function(Pointer<Utf8> sheetId, Pointer<Utf8> ruleId, int newPriority);

typedef CFClearRulesC = Void Function(Pointer<Utf8> sheetId);
typedef CFClearRulesDart = void Function(Pointer<Utf8> sheetId);

typedef CFGetRulesC = Pointer<Utf8> Function(Pointer<Utf8> sheetId);
typedef CFGetRulesDart = Pointer<Utf8> Function(Pointer<Utf8> sheetId);

typedef CFEvaluateVisibleCellsC = Pointer<Utf8> Function(Pointer<Utf8> sheetId, Pointer<Utf8> visibleCellsJson);
typedef CFEvaluateVisibleCellsDart = Pointer<Utf8> Function(Pointer<Utf8> sheetId, Pointer<Utf8> visibleCellsJson);

// JS Engine FFI
typedef InitJsEngineC = Void Function();
typedef InitJsEngineDart = void Function();

typedef CleanupJsEngineC = Void Function();
typedef CleanupJsEngineDart = void Function();

typedef EvalJsScriptC = Pointer<Utf8> Function(Pointer<Utf8> code);
typedef EvalJsScriptDart = Pointer<Utf8> Function(Pointer<Utf8> code);

typedef CallJsFunctionC = Pointer<Utf8> Function(Pointer<Utf8> funcName, Pointer<Utf8> jsonArgs);
typedef CallJsFunctionDart = Pointer<Utf8> Function(Pointer<Utf8> funcName, Pointer<Utf8> jsonArgs);

typedef RegisterJsMacroC = Void Function(Pointer<Utf8> name, Pointer<Utf8> code);
typedef RegisterJsMacroDart = void Function(Pointer<Utf8> name, Pointer<Utf8> code);

typedef GetJsMacroNamesC = Pointer<Utf8> Function();
typedef GetJsMacroNamesDart = Pointer<Utf8> Function();

typedef TriggerJsOnEditC = Void Function(Pointer<Utf8> sheetName, Pointer<Utf8> cellRef, Pointer<Utf8> oldValue, Pointer<Utf8> newValue);
typedef TriggerJsOnEditDart = void Function(Pointer<Utf8> sheetName, Pointer<Utf8> cellRef, Pointer<Utf8> oldValue, Pointer<Utf8> newValue);

// Filter Engine
typedef FilterAddRuleFromJsonC = Void Function(Pointer<Utf8> sheetId, Int32 col, Pointer<Utf8> jsonRule);
typedef FilterAddRuleFromJsonDart = void Function(Pointer<Utf8> sheetId, int col, Pointer<Utf8> jsonRule);
typedef FilterClearC = Void Function(Pointer<Utf8> sheetId);
typedef FilterClearDart = void Function(Pointer<Utf8> sheetId);
typedef FilterGetPreviewStatsC = Pointer<Utf8> Function(Pointer<Utf8> sheetId, Int32 col, Pointer<Utf8> jsonRule, Int32 totalRows);
typedef FilterGetPreviewStatsDart = Pointer<Utf8> Function(Pointer<Utf8> sheetId, int col, Pointer<Utf8> jsonRule, int totalRows);
typedef FilterGetHiddenRowsC = Pointer<Utf8> Function(Pointer<Utf8> sheetId, Int32 maxRows);
typedef FilterGetHiddenRowsDart = Pointer<Utf8> Function(Pointer<Utf8> sheetId, int maxRows);

typedef FilterGetVisibleRowsBitmapC = Pointer<Uint8> Function(Pointer<Utf8> sheetId, Int32 maxRows, Pointer<Int32> outLength);
typedef FilterGetVisibleRowsBitmapDart = Pointer<Uint8> Function(Pointer<Utf8> sheetId, int maxRows, Pointer<Int32> outLength);

typedef FilterEvaluateSingleRowC = Void Function(Pointer<Utf8> sheetId, Int32 row);
typedef FilterEvaluateSingleRowDart = void Function(Pointer<Utf8> sheetId, int row);

typedef PipelineExecuteC = Pointer<Utf8> Function(Pointer<Utf8> sheetId, Pointer<Utf8> pipelineJson);
typedef PipelineExecuteDart = Pointer<Utf8> Function(Pointer<Utf8> sheetId, Pointer<Utf8> pipelineJson);

typedef ExecutePivotC = Pointer<Utf8> Function(Pointer<Utf8> requestJson);
typedef ExecutePivotDart = Pointer<Utf8> Function(Pointer<Utf8> requestJson);

typedef GetChartDataC = Pointer<Utf8> Function(Pointer<Utf8> requestJson);
typedef GetChartDataDart = Pointer<Utf8> Function(Pointer<Utf8> requestJson);

typedef SplitTextToColumnsC = Pointer<Utf8> Function(Pointer<Utf8> text, Pointer<Utf8> delimiters, Int32 ignoreEmpty, Pointer<Utf8> textQualifiers);
typedef SplitTextToColumnsDart = Pointer<Utf8> Function(Pointer<Utf8> text, Pointer<Utf8> delimiters, int ignoreEmpty, Pointer<Utf8> textQualifiers);

// Data Intelligence Engine typedefs
// C++ exports in: ffi_bridge.cpp (native_analyzeColumn, native_summarizeSheet, etc.)
// C++ implementations: data_engine/analyzer/ + data_engine/cleaning/
typedef NativeAnalyzeColumnC = Pointer<Utf8> Function(Pointer<Utf8> columnLetter);
typedef NativeAnalyzeColumnDart = Pointer<Utf8> Function(Pointer<Utf8> columnLetter);

typedef NativeSummarizeSheetC = Pointer<Utf8> Function();
typedef NativeSummarizeSheetDart = Pointer<Utf8> Function();

typedef NativeAutoCleanValueC = Pointer<Utf8> Function(Pointer<Utf8> rawValue);
typedef NativeAutoCleanValueDart = Pointer<Utf8> Function(Pointer<Utf8> rawValue);

typedef NativeCleanColumnC = Pointer<Utf8> Function(Pointer<Utf8> columnLetter);
typedef NativeCleanColumnDart = Pointer<Utf8> Function(Pointer<Utf8> columnLetter);

typedef NativeAnalyzeEmailC = Pointer<Utf8> Function(Pointer<Utf8> rawEmail);
typedef NativeAnalyzeEmailDart = Pointer<Utf8> Function(Pointer<Utf8> rawEmail);


// Phase 3: Sheet Brain typedefs
// C++: data_engine/brain/context_compressor.cpp → native_understandSheet
// C++: data_engine/cluster/cluster_engine.cpp  → native_findClusters
typedef _UnderstandSheetC = Pointer<Utf8> Function();
typedef _UnderstandSheetDart = Pointer<Utf8> Function();

typedef _FindClustersC = Pointer<Utf8> Function(Pointer<Utf8> columnLetter, Double threshold);
typedef _FindClustersDart = Pointer<Utf8> Function(Pointer<Utf8> columnLetter, double threshold);

// AI Agent Super-Tools: Multi-Line Stitcher, Entity De-Mixer, Subtotal Isolator
typedef _StitchRecordsC = Pointer<Utf8> Function();
typedef _StitchRecordsDart = Pointer<Utf8> Function();

typedef _DemixColumnC = Pointer<Utf8> Function(Pointer<Utf8> colLetter);
typedef _DemixColumnDart = Pointer<Utf8> Function(Pointer<Utf8> colLetter);

typedef _IsolateSubtotalsC = Pointer<Utf8> Function();
typedef _IsolateSubtotalsDart = Pointer<Utf8> Function();

// Name from Email Imputation Engine
typedef _ExtractNamesFromEmailsC = Pointer<Utf8> Function(Pointer<Utf8> nameCol, Pointer<Utf8> emailCol);
typedef _ExtractNamesFromEmailsDart = Pointer<Utf8> Function(Pointer<Utf8> nameCol, Pointer<Utf8> emailCol);

typedef _ImputeNamesFromEmailsC = Pointer<Utf8> Function(Pointer<Utf8> nameCol, Pointer<Utf8> emailCol);
typedef _ImputeNamesFromEmailsDart = Pointer<Utf8> Function(Pointer<Utf8> nameCol, Pointer<Utf8> emailCol);


String _calculateAllTask(void _) {
  NativeEngine.initialize();
  return NativeEngine.calculateAll();
}

String _pasteDataBlockTask((int, int, String) args) {
  NativeEngine.initialize();
  return NativeEngine.pasteDataBlock(args.$1, args.$2, args.$3);
}

String _copyDataBlockTask((int, int, int, int) args) {
  NativeEngine.initialize();
  return NativeEngine.copyDataBlock(args.$1, args.$2, args.$3, args.$4);
}

String _evalJsScriptTask(String code) {
  NativeEngine.initialize();
  return NativeEngine.evalJsScript(code);
}

String _splitTextToColumnsTask((String, String, bool, String) args) {
  NativeEngine.initialize();
  return NativeEngine.splitTextToColumnsSync(args.$1, args.$2, args.$3, args.$4);
}

class NativeEngine {
  static late final DynamicLibrary _lib;
  static bool _initialized = false;

  static late final InitComputeEngineDart _initComputeEngine;
  static late final CleanupComputeEngineDart _cleanupComputeEngine;
  static late final EnableGPUComputeDart _enableGPUCompute;
  static late final CalculateSumDart _calculateSum;
  static late final CalculateAverageDart _calculateAverage;
  static late final CalculateMedianDart _calculateMedian;
  static late final CalculateStdDevDart _calculateStdDev;
  static late final EvaluateFormulaStringDart _evaluateFormulaString;
  static late final SetNamedRangeDart _setNamedRange;
  static late final SetNamedRangeStringDart _setNamedRangeString;
  static late final ClearNamedRangesDart _clearNamedRanges;
  static late final FreeStringDart _freeString;

  static late final SetCellFormulaDart _setCellFormula;
  static late final SetCellConstantDart _setCellConstant;
  static late final SetCellConstantStringDart _setCellConstantString;
  static late final ClearGridDart _clearGrid;
  static late final GetLastRowDart _getLastRow;
  static late final CalculateAllDart _calculateAll;
  static late final GetRawGridDart _getRawGrid;
  static late final PasteDataBlockDart _pasteDataBlock;
  static late final CopyDataBlockDart _copyDataBlock;
  static late final ResetFormulaProgressDart _resetFormulaProgress;
  static late final GetFormulaProgressCurrentDart _getFormulaProgressCurrent;
  static late final GetFormulaProgressTotalDart _getFormulaProgressTotal;
  static late final IsFormulaProgressActiveDart _isFormulaProgressActive;

  static late final CFAddRuleDart _cfAddRule;
  static late final CFRemoveRuleDart _cfRemoveRule;
  static late final CFReorderRuleDart _cfReorderRule;
  static late final CFClearRulesDart _cfClearRules;
  static late final CFGetRulesDart _cfGetRules;
  static late final CFEvaluateVisibleCellsDart _cfEvaluateVisibleCells;

  static late final InitJsEngineDart _initJsEngine;
  static late final CleanupJsEngineDart _cleanupJsEngine;
  static late final EvalJsScriptDart _evalJsScript;
  static late final CallJsFunctionDart _callJsFunction;
  static late final RegisterJsMacroDart _registerJsMacro;
  static late final GetJsMacroNamesDart _getJsMacroNames;
  static late final TriggerJsOnEditDart _triggerJsOnEdit;
  
  static late final FilterAddRuleFromJsonDart _filterAddRuleFromJson;
  static late final FilterClearDart _filterClear;
  static late final FilterGetPreviewStatsDart _filterGetPreviewStats;
  static late final FilterGetHiddenRowsDart _filterGetHiddenRows;
  static late final FilterGetVisibleRowsBitmapDart _filterGetVisibleRowsBitmap;
  static late final FilterEvaluateSingleRowDart _filterEvaluateSingleRow;
  static late final PipelineExecuteDart _pipelineExecute;
  static late final ExecutePivotDart _executePivot;
  static late final GetChartDataDart _getChartData;
  static late final SplitTextToColumnsDart _splitTextToColumns;

  // --- Data Intelligence Engine bindings ---
  // See: data_engine/analyzer/column_analyzer.h (C++)
  //      data_engine/analyzer/sheet_summarizer.h (C++)
  //      data_engine/cleaning/data_cleaner.h (C++)
  static late final NativeAnalyzeColumnDart _analyzeColumn;
  static late final NativeSummarizeSheetDart _summarizeSheet;
  static late final NativeAutoCleanValueDart _autoCleanValue;
  static late final NativeCleanColumnDart _cleanColumn;
  static late final NativeAnalyzeEmailDart _analyzeEmail;

  static void initialize() {
    if (_initialized) return;

    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libnative_lib.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform for native engine');
    }

    _initComputeEngine = _lib.lookupFunction<InitComputeEngineC, InitComputeEngineDart>('initComputeEngine');
    _cleanupComputeEngine = _lib.lookupFunction<CleanupComputeEngineC, CleanupComputeEngineDart>('cleanupComputeEngine');
    _enableGPUCompute = _lib.lookupFunction<EnableGPUComputeC, EnableGPUComputeDart>('enableGPUCompute');
    _calculateSum = _lib.lookupFunction<CalculateSumC, CalculateSumDart>('calculateSum');
    _calculateAverage = _lib.lookupFunction<CalculateAverageC, CalculateAverageDart>('calculateAverage');
    _calculateMedian = _lib.lookupFunction<CalculateMedianC, CalculateMedianDart>('calculateMedian');
    _calculateStdDev = _lib.lookupFunction<CalculateStdDevC, CalculateStdDevDart>('calculateStandardDeviation');
    _evaluateFormulaString = _lib.lookupFunction<EvaluateFormulaStringC, EvaluateFormulaStringDart>('evaluateFormulaString');
    _setNamedRange = _lib.lookupFunction<SetNamedRangeC, SetNamedRangeDart>('setNamedRange');
    _setNamedRangeString = _lib.lookupFunction<SetNamedRangeStringC, SetNamedRangeStringDart>('setNamedRangeString');
    _clearNamedRanges = _lib.lookupFunction<ClearNamedRangesC, ClearNamedRangesDart>('clearNamedRanges');
    
    _setCellFormula = _lib.lookupFunction<SetCellFormulaC, SetCellFormulaDart>('setCellFormula');
    _setCellConstant = _lib.lookupFunction<SetCellConstantC, SetCellConstantDart>('setCellConstant');
    _setCellConstantString = _lib.lookupFunction<SetCellConstantStringC, SetCellConstantStringDart>('setCellConstantString');
    _clearGrid = _lib.lookupFunction<ClearGridC, ClearGridDart>('clearGrid');
    _getLastRow = _lib.lookupFunction<GetLastRowC, GetLastRowDart>('native_getLastRow');
    _calculateAll = _lib.lookup<NativeFunction<NativeCalculateAll>>('native_calculateAll').asFunction();
    _getRawGrid = _lib.lookup<NativeFunction<NativeGetRawGrid>>('native_getRawGrid').asFunction();
    _freeString = _lib.lookupFunction<FreeStringC, FreeStringDart>('freeString');
    
    _pasteDataBlock = _lib.lookupFunction<PasteDataBlockC, PasteDataBlockDart>('pasteDataBlock');
    _copyDataBlock = _lib.lookupFunction<CopyDataBlockC, CopyDataBlockDart>('copyDataBlock');
    _resetFormulaProgress = _lib.lookupFunction<ResetFormulaProgressC, ResetFormulaProgressDart>('resetFormulaProgress');
    _getFormulaProgressCurrent = _lib.lookupFunction<GetFormulaProgressCurrentC, GetFormulaProgressCurrentDart>('getFormulaProgressCurrent');
    _getFormulaProgressTotal = _lib.lookupFunction<GetFormulaProgressTotalC, GetFormulaProgressTotalDart>('getFormulaProgressTotal');
    _isFormulaProgressActive = _lib.lookupFunction<IsFormulaProgressActiveC, IsFormulaProgressActiveDart>('isFormulaProgressActive');
    
    _cfAddRule = _lib.lookupFunction<CFAddRuleC, CFAddRuleDart>('cf_addRule');
    _cfRemoveRule = _lib.lookupFunction<CFRemoveRuleC, CFRemoveRuleDart>('cf_removeRule');
    _cfReorderRule = _lib.lookupFunction<CFReorderRuleC, CFReorderRuleDart>('cf_reorderRule');
    _cfClearRules = _lib.lookupFunction<CFClearRulesC, CFClearRulesDart>('cf_clearRules');
    _cfGetRules = _lib.lookupFunction<CFGetRulesC, CFGetRulesDart>('cf_getRules');
    _cfEvaluateVisibleCells = _lib.lookupFunction<CFEvaluateVisibleCellsC, CFEvaluateVisibleCellsDart>('cf_evaluateVisibleCells');
    
    _initJsEngine = _lib.lookupFunction<InitJsEngineC, InitJsEngineDart>('initJsEngine');
    _cleanupJsEngine = _lib.lookupFunction<CleanupJsEngineC, CleanupJsEngineDart>('cleanupJsEngine');
    _evalJsScript = _lib.lookupFunction<EvalJsScriptC, EvalJsScriptDart>('evalJsScript');
    _callJsFunction = _lib.lookupFunction<CallJsFunctionC, CallJsFunctionDart>('callJsFunction');
    _registerJsMacro = _lib.lookupFunction<RegisterJsMacroC, RegisterJsMacroDart>('registerJsMacro');
    _getJsMacroNames = _lib.lookupFunction<GetJsMacroNamesC, GetJsMacroNamesDart>('getJsMacroNames');
    _triggerJsOnEdit = _lib.lookupFunction<TriggerJsOnEditC, TriggerJsOnEditDart>('triggerJsOnEdit');
    _filterAddRuleFromJson = _lib.lookupFunction<FilterAddRuleFromJsonC, FilterAddRuleFromJsonDart>('filter_addRuleFromJson');
    _filterClear = _lib.lookupFunction<FilterClearC, FilterClearDart>('filter_clear');
    _filterGetPreviewStats = _lib.lookupFunction<FilterGetPreviewStatsC, FilterGetPreviewStatsDart>('filter_getPreviewStats');
    _filterGetHiddenRows = _lib.lookupFunction<FilterGetHiddenRowsC, FilterGetHiddenRowsDart>('filter_getHiddenRows');
    _filterGetVisibleRowsBitmap = _lib.lookupFunction<FilterGetVisibleRowsBitmapC, FilterGetVisibleRowsBitmapDart>('filter_getVisibleRowsBitmap');
    _filterEvaluateSingleRow = _lib.lookupFunction<FilterEvaluateSingleRowC, FilterEvaluateSingleRowDart>('filter_evaluateSingleRow');
    _pipelineExecute = _lib.lookupFunction<PipelineExecuteC, PipelineExecuteDart>('pipeline_execute');
    _executePivot = _lib.lookupFunction<ExecutePivotC, ExecutePivotDart>('executePivot');
    _getChartData = _lib.lookupFunction<GetChartDataC, GetChartDataDart>('getChartData');
    _splitTextToColumns = _lib.lookupFunction<SplitTextToColumnsC, SplitTextToColumnsDart>('splitTextToColumns');
    // Data Intelligence Engine bindings
    _analyzeColumn   = _lib.lookup<NativeFunction<NativeAnalyzeColumnC>>('native_analyzeColumn').asFunction();
    _summarizeSheet  = _lib.lookup<NativeFunction<NativeSummarizeSheetC>>('native_summarizeSheet').asFunction();
    _autoCleanValue  = _lib.lookup<NativeFunction<NativeAutoCleanValueC>>('native_autoCleanValue').asFunction();
    _cleanColumn     = _lib.lookup<NativeFunction<NativeCleanColumnC>>('native_cleanColumn').asFunction();
    _analyzeEmail    = _lib.lookup<NativeFunction<NativeAnalyzeEmailC>>('native_analyzeEmail').asFunction();
    // Phase 3: Sheet Brain bindings

    _understandSheet = _lib.lookup<NativeFunction<_UnderstandSheetC>>('native_understandSheet').asFunction();
    _findClusters    = _lib.lookup<NativeFunction<_FindClustersC>>('native_findClusters').asFunction();

    _stitchRecords   = _lib.lookup<NativeFunction<_StitchRecordsC>>('stitch_multi_line_records_ffi').asFunction();
    _demixColumn     = _lib.lookup<NativeFunction<_DemixColumnC>>('demix_column_entities_ffi').asFunction();
    _isolateSubtotals = _lib.lookup<NativeFunction<_IsolateSubtotalsC>>('isolate_subtotals_and_clean_ffi').asFunction();
    _extractNamesFromEmails = _lib.lookup<NativeFunction<_ExtractNamesFromEmailsC>>('native_extractNamesFromEmails').asFunction();
    _imputeNamesFromEmails  = _lib.lookup<NativeFunction<_ImputeNamesFromEmailsC>>('native_imputeNamesFromEmails').asFunction();


    _initComputeEngine();
    _initJsEngine();
    _resetFormulaProgress();
    _initialized = true;
  }

  static void dispose() {
    if (_initialized) {
      _resetFormulaProgress();
      _cleanupComputeEngine();
      _cleanupJsEngine();
      _initialized = false;
    }
  }

  static void enableGPU(bool enable) {
    if (!_initialized) initialize();
    _enableGPUCompute(enable ? 1 : 0);
  }

  static String executePivot(String requestJson) {
    if (!_initialized) initialize();
    final jsonPtr = requestJson.toNativeUtf8();
    final resultPtr = _executePivot(jsonPtr);
    final result = resultPtr.toDartString();
    calloc.free(jsonPtr);
    _freeString(resultPtr);
    return result;
  }

  static String getChartData(String requestJson) {
    if (!_initialized) initialize();
    final jsonPtr = requestJson.toNativeUtf8();
    final resultPtr = _getChartData(jsonPtr);
    final result = resultPtr.toDartString();
    calloc.free(jsonPtr);
    _freeString(resultPtr);
    return result;
  }

  static double sum(List<double> values) {
    if (!_initialized) initialize();
    if (values.isEmpty) return 0.0;

    final pointer = calloc<Double>(values.length);
    for (int i = 0; i < values.length; i++) {
      pointer[i] = values[i];
    }

    final result = _calculateSum(pointer, values.length);
    calloc.free(pointer);
    return result;
  }

  static double average(List<double> values) {
    if (!_initialized) initialize();
    if (values.isEmpty) return 0.0;

    final pointer = calloc<Double>(values.length);
    for (int i = 0; i < values.length; i++) {
      pointer[i] = values[i];
    }

    final result = _calculateAverage(pointer, values.length);
    calloc.free(pointer);
    return result;
  }
  
  static double median(List<double> values) {
    if (!_initialized) initialize();
    if (values.isEmpty) return 0.0;

    final pointer = calloc<Double>(values.length);
    for (int i = 0; i < values.length; i++) {
      pointer[i] = values[i];
    }

    final result = _calculateMedian(pointer, values.length);
    calloc.free(pointer);
    return result;
  }
  
  static double standardDeviation(List<double> values) {
    if (!_initialized) initialize();
    if (values.isEmpty) return 0.0;

    final pointer = calloc<Double>(values.length);
    for (int i = 0; i < values.length; i++) {
      pointer[i] = values[i];
    }

    final result = _calculateStdDev(pointer, values.length);
    calloc.free(pointer);
    return result;
  }
  
  static String evaluateFormula(String formula, {int currentRow = 0, int currentCol = 0}) {
    if (!_initialized) initialize();
    
    final formulaPtr = formula.toNativeUtf8();
    final resultPtr = _evaluateFormulaString(formulaPtr, currentRow, currentCol);
    
    if (resultPtr == nullptr) {
      calloc.free(formulaPtr);
      return "#ERROR";
    }
    
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    calloc.free(formulaPtr);
    
    return result;
  }
  
  static void setNamedRange(String name, double value) {
    if (!_initialized) initialize();
    final namePtr = name.toNativeUtf8();
    _setNamedRange(namePtr, value);
    calloc.free(namePtr);
  }

  static void setNamedRangeString(String name, String value) {
    if (!_initialized) initialize();
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    _setNamedRangeString(namePtr, valuePtr);
    calloc.free(namePtr);
    calloc.free(valuePtr);
  }

  static void clearNamedRanges() {
    if (!_initialized) initialize();
    _clearNamedRanges();
  }

  static void setCellFormula(String cellRef, String formula) {
    if (!_initialized) initialize();
    final cellPtr = cellRef.toNativeUtf8();
    final formulaPtr = formula.toNativeUtf8();
    _setCellFormula(cellPtr, formulaPtr);
    calloc.free(cellPtr);
    calloc.free(formulaPtr);
  }

  static void setCellConstant(String cellRef, double value) {
    if (!_initialized) initialize();
    final cellPtr = cellRef.toNativeUtf8();
    _setCellConstant(cellPtr, value);
    calloc.free(cellPtr);
  }

  static void setCellConstantString(String cellRef, String value) {
    if (!_initialized) initialize();
    final cellPtr = cellRef.toNativeUtf8();
    final valPtr = value.toNativeUtf8();
    _setCellConstantString(cellPtr, valPtr);
    calloc.free(cellPtr);
    calloc.free(valPtr);
  }

  static void clearGrid() {
    if (!_initialized) initialize();
    _clearGrid();
  }

  static int getLastRow() {
    if (!_initialized) initialize();
    return _getLastRow();
  }

  static String calculateAll() {
    if (!_initialized) initialize();
    final resultPtr = _calculateAll();
    if (resultPtr == nullptr) {
      return "{}";
    }
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }

  static String getRawGrid() {
    if (!_initialized) initialize();
    final resPtr = _getRawGrid();
    if (resPtr == nullptr) return "{}";
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  static Future<String> calculateAllAsync() async {
    return await compute(_calculateAllTask, null);
  }

  static String pasteDataBlock(int startRow, int startCol, String csvText) {
    if (!_initialized) initialize();
    final textPtr = csvText.toNativeUtf8();
    final resultPtr = _pasteDataBlock(startRow, startCol, textPtr);
    calloc.free(textPtr);
    if (resultPtr == nullptr) return "{}";
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }

  static Future<String> pasteDataBlockAsync(int startRow, int startCol, String csvText) async {
    return await compute(_pasteDataBlockTask, (startRow, startCol, csvText));
  }

  static String copyDataBlock(int startRow, int startCol, int endRow, int endCol) {
    if (!_initialized) initialize();
    final resultPtr = _copyDataBlock(startRow, startCol, endRow, endCol);
    if (resultPtr == nullptr) {
      return "";
    }
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }

  static Future<String> copyDataBlockAsync(int startRow, int startCol, int endRow, int endCol) async {
    return await compute(_copyDataBlockTask, (startRow, startCol, endRow, endCol));
  }

  static int get formulaProgressCurrent {
    if (!_initialized) initialize();
    return _getFormulaProgressCurrent();
  }

  static int get formulaProgressTotal {
    if (!_initialized) initialize();
    return _getFormulaProgressTotal();
  }

  static bool get isFormulaProgressActive {
    if (!_initialized) initialize();
    return _isFormulaProgressActive() != 0;
  }

  static double? get formulaProgressFraction {
    final total = formulaProgressTotal;
    if (!isFormulaProgressActive || total <= 0) return null;
    final current = formulaProgressCurrent.clamp(0, total);
    return current / total;
  }

  // --- Conditional Formatting API ---
  static void cfAddRule(String sheetId, String ruleJson) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final rPtr = ruleJson.toNativeUtf8();
    _cfAddRule(sPtr, rPtr);
    calloc.free(sPtr);
    calloc.free(rPtr);
  }

  static void cfRemoveRule(String sheetId, String ruleId) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final rPtr = ruleId.toNativeUtf8();
    _cfRemoveRule(sPtr, rPtr);
    calloc.free(sPtr);
    calloc.free(rPtr);
  }

  static void cfReorderRule(String sheetId, String ruleId, int newPriority) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final rPtr = ruleId.toNativeUtf8();
    _cfReorderRule(sPtr, rPtr, newPriority);
    calloc.free(sPtr);
    calloc.free(rPtr);
  }

  static void cfClearRules(String sheetId) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    _cfClearRules(sPtr);
    calloc.free(sPtr);
  }

  static String cfGetRules(String sheetId) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final resultPtr = _cfGetRules(sPtr);
    calloc.free(sPtr);
    if (resultPtr == nullptr) return "[]";
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }

  static String cfEvaluateVisibleCells(String sheetId, String visibleCellsJson) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final vPtr = visibleCellsJson.toNativeUtf8();
    final resultPtr = _cfEvaluateVisibleCells(sPtr, vPtr);
    calloc.free(sPtr);
    calloc.free(vPtr);
    if (resultPtr == nullptr) return "{}";
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }

  // --- JavaScript Engine API ---
  static Future<String> evalJsScriptAsync(String code) async {
    final rawRes = await compute(_evalJsScriptTask, code);
    return _parseJsResult(rawRes);
  }

  static String evalJsScript(String code) {
    if (!_initialized) initialize();
    final cPtr = code.toNativeUtf8();
    final resPtr = _evalJsScript(cPtr);
    calloc.free(cPtr);
    if (resPtr == nullptr) return "";
    final rawRes = resPtr.toDartString();
    _freeString(resPtr);
    return _parseJsResult(rawRes);
  }

  static String _parseJsResult(String rawJson) {
    try {
      if (rawJson.startsWith('{')) {
        final Map<String, dynamic> parsed = jsonDecode(rawJson);
        if (parsed.containsKey('ui_actions')) {
          final uiActions = parsed['ui_actions'] as List<dynamic>? ?? [];
          if (uiActions.isNotEmpty) {
            import_ui_dispatcher.UiActionDispatcher.instance.dispatch(uiActions);
          }
        }
        if (parsed.containsKey('result')) {
          return parsed['result'].toString();
        }
      }
    } catch (e) {
      debugPrint("[NativeEngine] Failed to parse JS result for ui_actions: $e");
    }
    return rawJson;
  }

  static String callJsFunction(String funcName, [String jsonArgs = ""]) {
    if (!_initialized) initialize();
    final fPtr = funcName.toNativeUtf8();
    final aPtr = jsonArgs.toNativeUtf8();
    final resPtr = _callJsFunction(fPtr, aPtr);
    calloc.free(fPtr);
    calloc.free(aPtr);
    if (resPtr == nullptr) return "";
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  static void registerJsMacro(String name, String code) {
    if (!_initialized) initialize();
    final nPtr = name.toNativeUtf8();
    final cPtr = code.toNativeUtf8();
    _registerJsMacro(nPtr, cPtr);
    calloc.free(nPtr);
    calloc.free(cPtr);
  }

  static String getJsMacroNames() {
    if (!_initialized) initialize();
    final resPtr = _getJsMacroNames();
    if (resPtr == nullptr) return "[]";
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  static void triggerJsOnEdit(String sheetName, String cellRef, String oldValue, String newValue) {
    if (!_initialized) initialize();
    final sPtr = sheetName.toNativeUtf8();
    final cPtr = cellRef.toNativeUtf8();
    final oPtr = oldValue.toNativeUtf8();
    final nPtr = newValue.toNativeUtf8();
    _triggerJsOnEdit(sPtr, cPtr, oPtr, nPtr);
    calloc.free(sPtr);
    calloc.free(cPtr);
    calloc.free(oPtr);
    calloc.free(nPtr);
  }

  // Filter Engine Bindings
  static void filterAddRuleFromJson(String sheetId, int col, String jsonRule) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final jPtr = jsonRule.toNativeUtf8();
    _filterAddRuleFromJson(sPtr, col, jPtr);
    calloc.free(sPtr);
    calloc.free(jPtr);
  }

  static void filterClear(String sheetId) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    _filterClear(sPtr);
    calloc.free(sPtr);
  }

  static String filterGetPreviewStats(String sheetId, int col, String jsonRule, int totalRows) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final jPtr = jsonRule.toNativeUtf8();
    final resPtr = _filterGetPreviewStats(sPtr, col, jPtr, totalRows);
    calloc.free(sPtr);
    calloc.free(jPtr);
    if (resPtr == nullptr) return "{}";
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  static String filterGetHiddenRows(String sheetId, int maxRows) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final resPtr = _filterGetHiddenRows(sPtr, maxRows);
    calloc.free(sPtr);
    if (resPtr == nullptr) return "[]";
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  static Uint8List filterGetVisibleRowsBitmap(String sheetId, int maxRows) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final lenPtr = calloc<Int32>();
    final ptr = _filterGetVisibleRowsBitmap(sPtr, maxRows, lenPtr);
    
    Uint8List result;
    if (ptr == nullptr) {
      result = Uint8List(0);
    } else {
      int len = lenPtr.value;
      result = Uint8List.fromList(ptr.asTypedList(len));
    }
    
    calloc.free(sPtr);
    calloc.free(lenPtr);
    return result;
  }

  static void filterEvaluateSingleRow(String sheetId, int row) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    _filterEvaluateSingleRow(sPtr, row);
    calloc.free(sPtr);
  }

  static String pipelineExecute(String sheetId, String pipelineJson) {
    if (!_initialized) initialize();
    final sPtr = sheetId.toNativeUtf8();
    final pPtr = pipelineJson.toNativeUtf8();
    final resPtr = _pipelineExecute(sPtr, pPtr);
    calloc.free(sPtr);
    calloc.free(pPtr);
    if (resPtr == nullptr) return "{}";
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  static String splitTextToColumnsSync(String text, String delimiters, bool ignoreEmpty, String textQualifiers) {
    if (!_initialized) initialize();
    final tPtr = text.toNativeUtf8();
    final dPtr = delimiters.toNativeUtf8();
    final qPtr = textQualifiers.toNativeUtf8();
    final resPtr = _splitTextToColumns(tPtr, dPtr, ignoreEmpty ? 1 : 0, qPtr);
    
    calloc.free(tPtr);
    calloc.free(dPtr);
    calloc.free(qPtr);
    
    if (resPtr == nullptr) return "[]";
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  static Future<List<List<String>>> splitTextToColumns(String text, String delimiters, bool ignoreEmpty, String textQualifiers) async {
    final jsonStr = await compute(_splitTextToColumnsTask, (text, delimiters, ignoreEmpty, textQualifiers));
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((row) => (row as List<dynamic>).map((e) => e.toString()).toList()).toList();
    } catch (e) {
      return [];
    }
  }

  // -----------------------------------------------------------------------
  // Data Intelligence Engine — Dart-callable API
  // C++ implementations: data_engine/analyzer/ + data_engine/cleaning/
  // FFI exports in: ffi_bridge.cpp (native_analyzeColumn etc.)
  // Used by AI Agent: local_agent_service.dart analyze_column tool
  // -----------------------------------------------------------------------

  /// Analyze a column's data types, quality issues, and suggested clean action.
  /// Returns JSON string. See data_engine/analyzer/column_analyzer.h
  static String analyzeColumn(String columnLetter) {
    if (!_initialized) initialize();
    final ptr = columnLetter.toNativeUtf8();
    final resPtr = _analyzeColumn(ptr);
    calloc.free(ptr);
    if (resPtr == nullptr) return '{}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Generate a smart full-sheet summary.
  /// Returns JSON string. See data_engine/analyzer/sheet_summarizer.h
  static String summarizeSheet() {
    if (!_initialized) initialize();
    final resPtr = _summarizeSheet();
    if (resPtr == nullptr) return '{}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Auto-detect data type of a value and return the cleaned version.
  /// See data_engine/cleaning/data_cleaner.h
  static String autoCleanValue(String rawValue) {
    if (!_initialized) initialize();
    final ptr = rawValue.toNativeUtf8();
    final resPtr = _autoCleanValue(ptr);
    calloc.free(ptr);
    if (resPtr == nullptr) return rawValue;
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Auto-clean an entire column in-place (rows 2..lastRow).
  /// Returns JSON: {cleaned_count, skipped_count, column, detected_type}
  /// See data_engine/cleaning/data_cleaner.h
  static String cleanColumn(String columnLetter) {
    if (!_initialized) initialize();
    final ptr = columnLetter.toNativeUtf8();
    final resPtr = _cleanColumn(ptr);
    calloc.free(ptr);
    if (resPtr == nullptr) return '{}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Enterprise Email Analyzer & Normalizer.
  /// Returns JSON: {original_email, raw_cleaned_email, normalized_email, local_part, domain, tld, provider, is_valid, has_plus_alias, has_dots, is_disposable, confidence_score, validation_message}
  static String analyzeEmail(String rawEmail) {
    if (!_initialized) initialize();
    final ptr = rawEmail.toNativeUtf8();
    final resPtr = _analyzeEmail(ptr);
    calloc.free(ptr);
    if (resPtr == nullptr) return '{}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }


  // -----------------------------------------------------------------------
  // Phase 3: Sheet Brain — Context Compressor + Fuzzy Cluster Engine
  // C++: data_engine/brain/context_compressor.cpp
  //      data_engine/cluster/cluster_engine.cpp
  //      data_engine/semantic/semantic_detector.cpp
  // FFI exports: ffi_bridge.cpp (native_understandSheet, native_findClusters)
  // AI Agent tools: understand_sheet, find_clusters
  // -----------------------------------------------------------------------

  static late final _UnderstandSheetDart _understandSheet;
  static late final _FindClustersDart _findClusters;

  /// Compress entire sheet into 300-token AI context.
  /// Returns rich JSON: sheetType, columns[], quality, topIssues, suggestedActions.
  /// See data_engine/brain/context_compressor.h
  static String understandSheet() {
    if (!_initialized) initialize();
    final resPtr = _understandSheet();
    if (resPtr == nullptr) return '{}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Find fuzzy clusters in a column (OpenRefine-style).
  /// Returns JSON: {clusters: [{canonical, variants[], similarity, algorithm}]}
  /// See data_engine/cluster/cluster_engine.h
  static String findClusters(String columnLetter, {double threshold = 0.85}) {
    if (!_initialized) initialize();
    final cPtr = columnLetter.toNativeUtf8();
    final resPtr = _findClusters(cPtr, threshold);
    calloc.free(cPtr);
    if (resPtr == nullptr) return '{"clusters":[]}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  // -----------------------------------------------------------------------
  // AI Agent Super-Tools (Multi-Line Stitcher, Entity De-Mixer, Subtotal Isolator)
  // C++: data_engine/cleaning/record_stitcher.cpp
  //      data_engine/cleaning/mixed_cell_demixer.cpp
  //      data_engine/analyzer/subtotal_isolator.cpp
  // -----------------------------------------------------------------------

  static late final _StitchRecordsDart _stitchRecords;
  static late final _DemixColumnDart _demixColumn;
  static late final _IsolateSubtotalsDart _isolateSubtotals;
  static late final _ExtractNamesFromEmailsDart _extractNamesFromEmails;
  static late final _ImputeNamesFromEmailsDart _imputeNamesFromEmails;

  /// Automatically stitches multi-line records (e.g. from PDF/OCR or Tally)
  /// where 1 transaction spans across 2-4 rows into unified clean rows.
  static String stitchMultiLineRecords() {
    if (!_initialized) initialize();
    final resPtr = _stitchRecords();
    if (resPtr == nullptr) return '{"status":"error"}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Disassembles a column with mixed text (Name, Phone, Email, GSTIN, Amount)
  /// into dedicated structured columns to the right of the sheet.
  static String demixColumnEntities(String columnLetter) {
    if (!_initialized) initialize();
    final cPtr = columnLetter.toNativeUtf8();
    final resPtr = _demixColumn(cPtr);
    calloc.free(cPtr);
    if (resPtr == nullptr) return '{"status":"error"}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Identifies and isolates repetitive header/footer artifacts, "Sub Total: ...",
  /// "Page X of Y", and decorative lines to prevent duplicate calculation errors.
  static String isolateSubtotals() {
    if (!_initialized) initialize();
    final resPtr = _isolateSubtotals();
    if (resPtr == nullptr) return '{"status":"error"}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Extracts candidate human names from email addresses where Name is blank.
  /// Only active if an Email column exists. Automatically discards bot/fuzzy emails.
  static String extractNamesFromEmails({String? nameColumn, String? emailColumn}) {
    if (!_initialized) initialize();
    final namePtr = (nameColumn ?? '').toNativeUtf8();
    final emailPtr = (emailColumn ?? '').toNativeUtf8();
    final resPtr = _extractNamesFromEmails(namePtr, emailPtr);
    calloc.free(namePtr);
    calloc.free(emailPtr);
    if (resPtr == nullptr) return '{"status":"error"}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }

  /// Bulk-imputes extracted human names into blank Name cells from corresponding Email cells.
  static String imputeNamesFromEmails({String? nameColumn, String? emailColumn}) {
    if (!_initialized) initialize();
    final namePtr = (nameColumn ?? '').toNativeUtf8();
    final emailPtr = (emailColumn ?? '').toNativeUtf8();
    final resPtr = _imputeNamesFromEmails(namePtr, emailPtr);
    calloc.free(namePtr);
    calloc.free(emailPtr);
    if (resPtr == nullptr) return '{"status":"error"}';
    final res = resPtr.toDartString();
    _freeString(resPtr);
    return res;
  }
}

