import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'super_engine/ffi_bridge.dart';

class ConditionalFormattingService {
  
  static void addRule(String sheetId, dynamic ruleJson) {
    final String encoded = ruleJson is String ? ruleJson : jsonEncode(ruleJson);
    NativeEngine.cfAddRule(sheetId, encoded);
    saveRules(sheetId);
  }

  static void removeRule(String sheetId, String ruleId) {
    NativeEngine.cfRemoveRule(sheetId, ruleId);
    saveRules(sheetId);
  }

  static void reorderRule(String sheetId, String ruleId, int newPriority) {
    NativeEngine.cfReorderRule(sheetId, ruleId, newPriority);
    saveRules(sheetId);
  }

  static void clearRules(String sheetId) {
    NativeEngine.cfClearRules(sheetId);
    saveRules(sheetId);
  }

  static List<Map<String, dynamic>> getRules(String sheetId) {
    final resultJson = NativeEngine.cfGetRules(sheetId);
    if (resultJson.isEmpty || resultJson == "[]") return [];
    try {
      final List<dynamic> decoded = jsonDecode(resultJson);
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print("Error decoding CF rules: $e");
      return [];
    }
  }

  /// Evaluates CF rules for the given cell addresses and returns their computed styles.
  static Map<String, dynamic> evaluateVisibleCells(String sheetId, List<String> cellAddresses) {
    final visibleCellsJson = jsonEncode(cellAddresses);
    final resultJson = NativeEngine.cfEvaluateVisibleCells(sheetId, visibleCellsJson);
    if (resultJson.isEmpty || resultJson == "{}") return {};
    
    try {
      return jsonDecode(resultJson) as Map<String, dynamic>;
    } catch (e) {
      print("Error decoding CF results: $e");
      return {};
    }
  }

  /// Saves CF rules to disk & SharedPreferences so they survive app restarts
  static Future<void> saveRules(String sheetId) async {
    try {
      final rules = getRules(sheetId);
      final jsonStr = jsonEncode(rules);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cf_rules_$sheetId', jsonStr);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${sheetId}_cf_rules.json');
      await file.writeAsString(jsonStr);
    } catch (e) {
      print("Error saving CF rules: $e");
    }
  }

  /// Restores saved CF rules from disk & SharedPreferences into the C++ engine
  static Future<void> restoreRules(String sheetId) async {
    try {
      String? jsonStr;
      final prefs = await SharedPreferences.getInstance();
      jsonStr = prefs.getString('cf_rules_$sheetId');

      if (jsonStr == null || jsonStr.isEmpty || jsonStr == "[]") {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/${sheetId}_cf_rules.json');
        if (await file.exists()) {
          jsonStr = await file.readAsString();
        }
      }

      if (jsonStr != null && jsonStr.isNotEmpty && jsonStr != "[]") {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        for (final r in decoded) {
          final encoded = jsonEncode(r);
          NativeEngine.cfAddRule(sheetId, encoded);
        }
      }
    } catch (e) {
      print("Error restoring CF rules for sheet $sheetId: $e");
    }
  }
}
