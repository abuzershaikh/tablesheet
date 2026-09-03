abstract class CopilotTool {
  /// The name of the tool, matching the function name in Gemini
  String get name;

  /// The JSON declaration of the tool parameters and description for Gemini
  Map<String, dynamic> get declaration;

  /// Executes the tool. 
  /// Returns a CopilotResponse-like map, or a map with a 'pipeline' key if it generates an action.
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args);
}
