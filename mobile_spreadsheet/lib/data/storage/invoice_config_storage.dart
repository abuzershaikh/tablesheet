import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/invoice_template_config.dart';

class InvoiceConfigStorage {
  InvoiceConfigStorage._();

  static const String _key = 'user_invoice_template_config';

  /// Save user's customized invoice configuration
  static Future<void> saveConfig(InvoiceTemplateConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(config.toJson());
    await prefs.setString(_key, jsonStr);
  }

  /// Load user's saved invoice configuration
  static Future<InvoiceTemplateConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return InvoiceTemplateConfig.fromJson(map);
      } catch (_) {}
    }
    return const InvoiceTemplateConfig(); // default template
  }
}
