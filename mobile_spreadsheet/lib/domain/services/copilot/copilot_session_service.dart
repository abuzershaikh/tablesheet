import 'copilot_service.dart';

class CopilotSessionMessage {
  final String sender; // 'user' or 'ai'
  final String text;
  final CopilotResponse? aiResponse;
  final bool isExecuted;
  final String mode; // 'flash' or 'task'

  CopilotSessionMessage({
    required this.sender,
    required this.text,
    this.aiResponse,
    this.isExecuted = false,
    this.mode = 'flash',
  });

  CopilotSessionMessage copyWith({bool? isExecuted}) {
    return CopilotSessionMessage(
      sender: sender,
      text: text,
      aiResponse: aiResponse,
      isExecuted: isExecuted ?? this.isExecuted,
      mode: mode,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;
  final List<CopilotSessionMessage> flashMessages;
  final List<CopilotSessionMessage> taskMessages;

  ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.flashMessages,
    required this.taskMessages,
  });
}

class CopilotSessionService {
  static final CopilotSessionService instance = CopilotSessionService._internal();

  CopilotSessionService._internal();

  final List<CopilotSessionMessage> flashMessages = [];
  final List<CopilotSessionMessage> taskMessages = [];
  final List<ChatSession> sessionHistory = [];

  bool _initialized = false;

  void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    resetToInitial();
  }

  void resetToInitial() {
    flashMessages.clear();
    taskMessages.clear();

    taskMessages.add(CopilotSessionMessage(
      sender: 'ai',
      text: '🤖 Sheet Copilot Active (Task Mode)\nAsk questions, clean data, create formulas, or chat about your spreadsheet! Any instructions you provide will execute live on the sheet.',
      mode: 'task',
    ));
  }

  void clearTab(String mode) {
    taskMessages.clear();
    taskMessages.add(CopilotSessionMessage(
      sender: 'ai',
      text: '🤖 Sheet Copilot Active (Task Mode)\nAsk questions, clean data, create formulas, or chat about your spreadsheet! Any instructions you provide will execute live on the sheet.',
      mode: 'task',
    ));
  }

  void saveCurrentSession() {
    if (flashMessages.length <= 1 && taskMessages.length <= 1) return;
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final firstMsg = flashMessages.length > 1 ? flashMessages[1].text : (taskMessages.length > 1 ? taskMessages[1].text : 'Chat Session');
    final title = firstMsg.length > 30 ? '${firstMsg.substring(0, 30)}...' : firstMsg;

    sessionHistory.insert(
      0,
      ChatSession(
        id: id,
        title: title,
        timestamp: DateTime.now(),
        flashMessages: List.from(flashMessages),
        taskMessages: List.from(taskMessages),
      ),
    );
  }

  void loadSession(ChatSession session) {
    saveCurrentSession();
    flashMessages.clear();
    taskMessages.clear();
    flashMessages.addAll(session.flashMessages);
    taskMessages.addAll(session.taskMessages);
  }
}
