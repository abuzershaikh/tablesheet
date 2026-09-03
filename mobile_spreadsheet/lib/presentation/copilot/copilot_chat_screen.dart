import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/services/copilot/copilot_service.dart';
import '../../domain/services/copilot/copilot_session_service.dart';
import '../../domain/services/copilot/whisper_service.dart';
import '../settings/agent_settings_screen.dart';

class CopilotFullScreenChatScreen extends StatefulWidget {
  final String sheetId;
  final Function(Map<String, dynamic>)? onPipelineApplied;

  const CopilotFullScreenChatScreen({
    Key? key,
    required this.sheetId,
    this.onPipelineApplied,
  }) : super(key: key);

  static Future<void> open(
    BuildContext context, {
    required String sheetId,
    Function(Map<String, dynamic>)? onPipelineApplied,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CopilotFullScreenChatScreen(
          sheetId: sheetId,
          onPipelineApplied: onPipelineApplied,
        ),
      ),
    );
  }

  @override
  State<CopilotFullScreenChatScreen> createState() => _CopilotFullScreenChatScreenState();
}

class _CopilotFullScreenChatScreenState extends State<CopilotFullScreenChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isLoading = false;
  bool _isRecording = false;
  bool _autoExecutePipeline = true;
  String _selectedProvider = 'gemini';
  late AnimationController _micPulseController;

  List<CopilotSessionMessage> get _messages => CopilotSessionService.instance.taskMessages;

  final List<String> _quickSuggestions = [
    '🧹 Clean and sanitize this sheet',
    '📧 Impute missing names from emails',
    '📊 Summarize sheet quality & issues',
    '🔍 Find and cluster duplicate rows',
    '📅 Normalize all dates to standard format',
  ];

  @override
  void initState() {
    super.initState();
    CopilotSessionService.instance.ensureInitialized();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoExecutePipeline = prefs.getBool('ai_agent_auto_execute_pipeline') ?? true;
        _selectedProvider = prefs.getString('ai_agent_provider') ?? 'gemini';
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _micPulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to clear this conversation?', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                CopilotSessionService.instance.clearTab('task');
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat cleared'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmStopAgent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('Stop Execution?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to stop the AI Agent loop execution?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              CopilotService.stopAgentLoop();
              setState(() {
                _isLoading = false;
              });
            },
            child: const Text('Stop Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openLogsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.list_alt_rounded, color: Colors.cyanAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Live Action Logs',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: ValueListenableBuilder<List<AgentActionLog>>(
                  valueListenable: CopilotService.actionLogsNotifier,
                  builder: (context, logs, _) {
                    if (logs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No action logs yet.\nLogs appear live as the agent performs actions!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.cyan[900],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.title,
                                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.detail,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _micPulseController.stop();
      _micPulseController.reset();
      setState(() {
        _isRecording = false;
        _isLoading = true;
      });

      final path = await _audioRecorder.stop();
      if (path != null && path.isNotEmpty) {
        CopilotService.updateStatus(AgentStatus.thinking);
        final transcribedText = await WhisperService.transcribeAudio(path);
        if (!mounted) return;

        if (transcribedText != null && transcribedText.trim().isNotEmpty) {
          _inputController.text = transcribedText;
          _handleSubmitted(transcribedText);
        } else {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Whisper voice transcription empty. Please speak again.')),
          );
        }
      } else {
        setState(() { _isLoading = false; });
      }
    } else {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isGranted) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/copilot_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
        _micPulseController.repeat(reverse: true);
        setState(() {
          _isRecording = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required for Voice Copilot')),
        );
      }
    }
  }

  Future<void> _handleSubmitted(String text) async {
    FocusScope.of(context).unfocus();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (_isLoading) {
      CopilotService.stopAgentLoop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _inputController.clear();
    setState(() {
      _messages.add(CopilotSessionMessage(sender: 'user', text: trimmed, mode: 'task'));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await CopilotService.sendPrompt(
      prompt: trimmed,
      sheetId: widget.sheetId,
      provider: _selectedProvider,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.success) {
        final pipeline = response.pipeline;
        final explanation = response.explanation.isNotEmpty ? response.explanation : 'Task completed successfully.';
        _messages.add(CopilotSessionMessage(
          sender: 'ai',
          text: explanation,
          mode: 'task',
          aiResponse: response,
          isExecuted: _autoExecutePipeline,
        ));

        if (pipeline != null && _autoExecutePipeline) {
          widget.onPipelineApplied?.call(pipeline);
        }
      } else {
        _messages.add(CopilotSessionMessage(
          sender: 'ai',
          text: response.error ?? 'Execution failed. Please try again.',
          mode: 'task',
          aiResponse: response,
        ));
      }
    });
    _scrollToBottom();
  }

  void _applyPipeline(CopilotSessionMessage msg) {
    if (msg.aiResponse?.pipeline != null) {
      widget.onPipelineApplied?.call(msg.aiResponse!.pipeline!);
      setState(() {
        final idx = _messages.indexOf(msg);
        if (idx != -1) {
          _messages[idx] = msg.copyWith(isExecuted: true);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pipeline applied to sheet!'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 8),
            foregroundColor: Colors.cyanAccent,
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          label: const Text('Sheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        leadingWidth: 90,
        title: ValueListenableBuilder<AgentStatus>(
          valueListenable: CopilotService.agentStatusNotifier,
          builder: (context, status, _) {
            Color dotColor = Colors.greenAccent;
            String statusText = 'Ready';

            switch (status) {
              case AgentStatus.thinking:
                dotColor = Colors.amberAccent;
                statusText = 'Thinking...';
                break;
              case AgentStatus.planning:
                dotColor = Colors.cyanAccent;
                statusText = 'Planning...';
                break;
              case AgentStatus.researching:
                dotColor = Colors.lightBlueAccent;
                statusText = 'Researching...';
                break;
              case AgentStatus.executing:
                dotColor = Colors.orangeAccent;
                statusText = 'Executing...';
                break;
              case AgentStatus.waiting:
                dotColor = Colors.purpleAccent;
                statusText = 'Waiting Choice';
                break;
              case AgentStatus.completed:
                dotColor = Colors.greenAccent;
                statusText = 'Completed';
                break;
              case AgentStatus.failed:
                dotColor = Colors.red;
                statusText = 'Failed';
                break;
              default:
                dotColor = Colors.greenAccent;
                statusText = 'Ready';
                break;
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'Sheet Copilot',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Text(
                  '($statusText)',
                  style: TextStyle(color: dotColor, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            );
          },
        ),
        centerTitle: true,
        actions: [
          // Model Switcher
          InkWell(
            onTap: () async {
              final newProv = _selectedProvider == 'gemini' ? 'deepseek' : 'gemini';
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('ai_agent_provider', newProv);
              setState(() {
                _selectedProvider = newProv;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to ${newProv == 'deepseek' ? 'DeepSeek' : 'Google Gemini'}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _selectedProvider == 'deepseek' ? Colors.blue.withOpacity(0.25) : Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _selectedProvider == 'deepseek' ? Colors.blueAccent : Colors.amberAccent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedProvider == 'deepseek' ? Icons.psychology : Icons.bolt,
                    color: _selectedProvider == 'deepseek' ? Colors.cyanAccent : Colors.amberAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedProvider == 'deepseek' ? 'DeepSeek' : 'Gemini',
                    style: TextStyle(
                      color: _selectedProvider == 'deepseek' ? Colors.cyanAccent : Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, color: Colors.amberAccent, size: 20),
            tooltip: 'Action Logs',
            onPressed: _openLogsModal,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 20),
            tooltip: 'Clear Chat',
            onPressed: _clearChat,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
            tooltip: 'AI Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AgentSettingsScreen()),
            ).then((_) => _loadPreferences()),
          ),
        ],
      ),
      body: Column(
        children: [
          // If Agent is Running, show a prominent progress bar with Stop button
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI is analyzing and modifying spreadsheet...',
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text('Stop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _confirmStopAgent,
                  ),
                ],
              ),
            ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index], index == _messages.length - 1);
              },
            ),
          ),

          // Quick Suggestion Chips when conversation is short
          if (_messages.length <= 2)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickSuggestions.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: const Color(0xFF1E293B),
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                      label: Text(
                        _quickSuggestions[index],
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      onPressed: () => _handleSubmitted(_quickSuggestions[index]),
                    ),
                  );
                },
              ),
            ),

          // Bottom Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? '🎙️ Listening... Tap mic to stop & send'
                            : 'Ask AI Copilot to clean, calculate, or format...',
                        hintStyle: TextStyle(
                          color: _isRecording ? Colors.redAccent : Colors.grey[500],
                          fontSize: 13,
                          fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Whisper Voice Mic
                AnimatedBuilder(
                  animation: _micPulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_micPulseController.value * 0.25);
                    return Transform.scale(
                      scale: _isRecording ? scale : 1.0,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.redAccent : const Color(0xFF0F172A),
                          border: Border.all(color: _isRecording ? Colors.redAccent : Colors.white10),
                          boxShadow: _isRecording
                              ? [BoxShadow(color: Colors.redAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)]
                              : null,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: _isRecording ? Colors.white : Colors.cyanAccent,
                            size: 20,
                          ),
                          onPressed: _toggleRecording,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Send Button
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                          )
                        : const Icon(Icons.send_rounded, color: Color(0xFF0F172A), size: 20),
                    onPressed: _isLoading ? null : () => _handleSubmitted(_inputController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CopilotSessionMessage msg, bool isLatest) {
    final isUser = msg.sender == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.cyan, Colors.blueAccent],
                ),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser ? Colors.transparent : Colors.white10,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender Header & Copy Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isUser ? 'You' : 'Sheet Copilot',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isUser ? Colors.white70 : Colors.cyanAccent,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.content_copy_rounded, size: 13, color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Message Content
                  SelectableText(
                    msg.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),

                  // Pipeline Execution Card
                  if (msg.aiResponse?.pipeline != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.aiResponse!.planSummary.isNotEmpty) ...[
                            Text(
                              'Plan: ${msg.aiResponse!.planSummary}',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: msg.isExecuted ? Colors.grey[700] : const Color(0xFF107C41),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: msg.isExecuted ? null : () => _applyPipeline(msg),
                              icon: Icon(msg.isExecuted ? Icons.check_circle : Icons.play_arrow_rounded, size: 16, color: Colors.white),
                              label: Text(
                                msg.isExecuted ? 'Applied to Sheet' : 'Execute Plan on Sheet',
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Interactive Choice Cards (ask_user_question e.g. Tally/ERP Confirmation)
                  if (msg.aiResponse?.questionPayload != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.help_outline_rounded, color: Colors.cyanAccent, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Select your choice:',
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: msg.aiResponse!.questionPayload!.options.map((opt) {
                              final isDefault = opt == msg.aiResponse!.questionPayload!.defaultOption;
                              return InkWell(
                                onTap: () => _handleSubmitted(opt),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDefault ? Colors.cyan[900] : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDefault ? Colors.cyanAccent : Colors.white24,
                                      width: isDefault ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      color: isDefault ? Colors.cyanAccent : Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 10, top: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3B82F6),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}
