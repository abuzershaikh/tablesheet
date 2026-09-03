import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearnedSkill {
  final String id;
  final String pattern;
  final String columnType;
  final String appliedTrick;
  final int rating;
  final int timestamp;

  LearnedSkill({
    required this.id,
    required this.pattern,
    required this.columnType,
    required this.appliedTrick,
    required this.rating,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'pattern': pattern,
    'column_type': columnType,
    'applied_trick': appliedTrick,
    'rating': rating,
    'timestamp': timestamp,
  };

  factory LearnedSkill.fromJson(Map<String, dynamic> json) {
    return LearnedSkill(
      id: json['id'] ?? '',
      pattern: json['pattern'] ?? '',
      columnType: json['column_type'] ?? '',
      appliedTrick: json['applied_trick'] ?? '',
      rating: json['rating'] ?? 5,
      timestamp: json['timestamp'] ?? 0,
    );
  }
}

class AgentLearningService {
  static const String _storageKey = 'ai_agent_learned_skills';

  /// Saves a successful data cleaning trick into persistent memory if rating >= 4 stars
  static Future<bool> saveLearnedSkill({
    required String pattern,
    required String columnType,
    required String appliedTrick,
    required int rating,
  }) async {
    if (rating < 4) {
      debugPrint('[AgentLearning] Rating is $rating stars (below 4 stars). Skipping memory save.');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_storageKey) ?? '[]';
      final List<dynamic> list = jsonDecode(existingJson);

      final skillId = 'skill_${DateTime.now().millisecondsSinceEpoch}';
      final newSkill = LearnedSkill(
        id: skillId,
        pattern: pattern,
        columnType: columnType,
        appliedTrick: appliedTrick,
        rating: rating,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      list.add(newSkill.toJson());
      await prefs.setString(_storageKey, jsonEncode(list));

      // Also back up to local documents file learned_skills.json
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/learned_skills.json');
      await file.writeAsString(jsonEncode(list));

      debugPrint('[AgentLearning] Successfully saved 5-Star learned trick to memory: $skillId');
      return true;
    } catch (e) {
      debugPrint('[AgentLearning] Error saving learned skill: $e');
      return false;
    }
  }

  /// Retrieves all 4-star and 5-star learned tricks from persistent memory
  static Future<List<LearnedSkill>> getLearnedSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_storageKey) ?? '[]';
      final List<dynamic> list = jsonDecode(existingJson);
      return list.map((item) => LearnedSkill.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      debugPrint('[AgentLearning] Error loading learned skills: $e');
      return [];
    }
  }

  /// Searches for the best matching trick in learned memory for a given data pattern & column type
  static Future<LearnedSkill?> findBestMatchingSkill(String pattern, String columnType) async {
    final skills = await getLearnedSkills();
    if (skills.isEmpty) return null;

    final pLower = pattern.toLowerCase();
    final cLower = columnType.toLowerCase();

    for (var skill in skills.reversed) {
      if (skill.rating >= 4) {
        if (skill.columnType.toLowerCase() == cLower || pLower.contains(skill.pattern.toLowerCase())) {
          debugPrint('[AgentLearning] Match found in learned memory: ${skill.id}');
          return skill;
        }
      }
    }
    return null;
  }
}
