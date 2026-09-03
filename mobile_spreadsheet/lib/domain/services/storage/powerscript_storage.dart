import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PowerScriptModel {
  final String id;
  final String name;
  final String code;
  final String spreadsheetId;
  final DateTime createdAt;
  final DateTime? lastRunAt;

  PowerScriptModel({
    required this.id,
    required this.name,
    required this.code,
    required this.spreadsheetId,
    required this.createdAt,
    this.lastRunAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'spreadsheetId': spreadsheetId,
        'createdAt': createdAt.toIso8601String(),
        'lastRunAt': lastRunAt?.toIso8601String(),
      };

  factory PowerScriptModel.fromJson(Map<String, dynamic> json) => PowerScriptModel(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Untitled Script',
        code: json['code'] ?? '',
        spreadsheetId: json['spreadsheetId'] ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        lastRunAt: json['lastRunAt'] != null
            ? DateTime.parse(json['lastRunAt'])
            : null,
      );

  PowerScriptModel copyWith({
    String? name,
    String? code,
    DateTime? lastRunAt,
  }) =>
      PowerScriptModel(
        id: id,
        name: name ?? this.name,
        code: code ?? this.code,
        spreadsheetId: spreadsheetId,
        createdAt: createdAt,
        lastRunAt: lastRunAt ?? this.lastRunAt,
      );
}

class PowerScriptStorage {
  static String _getKey(String spreadsheetId) => 'powerscripts_$spreadsheetId';

  static Future<List<PowerScriptModel>> getScripts(String spreadsheetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_getKey(spreadsheetId));
      if (jsonStr == null || jsonStr.isEmpty) {
        return _getDefaultTemplates(spreadsheetId);
      }
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => PowerScriptModel.fromJson(e)).toList();
    } catch (e) {
      return _getDefaultTemplates(spreadsheetId);
    }
  }

  static Future<void> saveScripts(String spreadsheetId, List<PowerScriptModel> scripts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = scripts.map((e) => e.toJson()).toList();
      await prefs.setString(_getKey(spreadsheetId), jsonEncode(list));
    } catch (e) {
      // Ignore
    }
  }

  static Future<void> saveScript(String spreadsheetId, PowerScriptModel script) async {
    final scripts = await getScripts(spreadsheetId);
    final index = scripts.indexWhere((s) => s.id == script.id);
    if (index >= 0) {
      scripts[index] = script;
    } else {
      scripts.insert(0, script);
    }
    await saveScripts(spreadsheetId, scripts);
  }

  static Future<void> deleteScript(String spreadsheetId, String scriptId) async {
    final scripts = await getScripts(spreadsheetId);
    scripts.removeWhere((s) => s.id == scriptId);
    await saveScripts(spreadsheetId, scripts);
  }

  static List<PowerScriptModel> _getDefaultTemplates(String spreadsheetId) {
    final now = DateTime.now();
    return [
      PowerScriptModel(
        id: 'tpl_hello',
        name: '1. Hello World Macro',
        spreadsheetId: spreadsheetId,
        createdAt: now,
        code: '''// Welcome to PowerScript Studio!
// Automatically writes "Hello PowerScript!" into cell A1 and colors it.

function main() {
    var sheet = SpreadsheetApp.getActiveSheet();
    sheet.getRange("A1").setValue("Hello PowerScript!");
    sheet.getRange("A1").setBackground("#107C41");
    console.log("Macro executed successfully on cell A1");
}

main();''',
      ),
      PowerScriptModel(
        id: 'tpl_highlight',
        name: '2. Auto Highlight Values',
        spreadsheetId: spreadsheetId,
        createdAt: now,
        code: '''// Auto Highlight Sales > 100 in Column A
function highlightHighValues() {
    var sheet = SpreadsheetApp.getActiveSheet();
    for (var i = 1; i <= 10; i++) {
        var ref = "A" + i;
        var val = sheet.getRange(ref).getValue();
        if (typeof val === 'number' && val > 100) {
            sheet.getRange(ref).setBackground("#22C55E"); // Light Green
            console.log("Highlighted " + ref + ": " + val);
        }
    }
}

highlightHighValues();''',
      ),
      PowerScriptModel(
        id: 'tpl_fetch',
        name: '3. Fetch Live Crypto Price (API)',
        spreadsheetId: spreadsheetId,
        createdAt: now,
        code: '''// Fetches live Bitcoin price from Binance API and writes to cell B1
function fetchBtcPrice() {
    console.log("Fetching live BTC price...");
    var res = fetch("https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT");
    if (res && res.json) {
        var price = res.json.price;
        var sheet = SpreadsheetApp.getActiveSheet();
        sheet.getRange("A1").setValue("BTC Price (USD)");
        sheet.getRange("B1").setValue(parseFloat(price));
        sheet.getRange("B1").setBackground("#F59E0B");
        console.log("Updated BTC Price: \$" + price);
    } else {
        console.log("Failed to fetch price");
    }
}

fetchBtcPrice();''',
      ),
    ];
  }
}
