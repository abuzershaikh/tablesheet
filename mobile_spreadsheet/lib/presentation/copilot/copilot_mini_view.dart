import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_spreadsheet/domain/services/copilot/whisper_service.dart';
import 'package:mobile_spreadsheet/domain/services/copilot/local_agent_service.dart';

import 'package:mobile_spreadsheet/domain/services/copilot/copilot_service.dart';
import 'package:mobile_spreadsheet/domain/services/copilot/copilot_session_service.dart';
import 'package:mobile_spreadsheet/presentation/settings/agent_settings_screen.dart';
import 'copilot_chat_screen.dart';
import 'widgets/copilot_question_card.dart';

typedef CopilotChatMessage = CopilotSessionMessage;

class CopilotMiniView extends StatefulWidget {
  final String sheetId;
  final Function(Map<String, dynamic>)? onPipelineApplied;

  const CopilotMiniView({
    Key? key,
    required this.sheetId,
    this.onPipelineApplied,
  }) : super(key: key);

  @override
  State<CopilotMiniView> createState() => _CopilotMiniViewState();
}

class _CopilotMiniViewState extends State<CopilotMiniView> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isLoading = false;
  bool _isRecording = false;
  bool _autoExecutePipeline = true;
  String _selectedProvider = 'gemini';
  late AnimationController _micPulseController;

  List<CopilotChatMessage> get _messages => CopilotSessionService.instance.taskMessages;

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
    setState(() {
      _autoExecutePipeline = prefs.getBool('ai_agent_auto_execute_pipeline') ?? true;
      _selectedProvider = prefs.getString('ai_agent_provider') ?? 'gemini';
    });
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearCurrentChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear Chat History?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to clear the chat messages for this tab?', style: TextStyle(color: Colors.white70, fontSize: 11)),
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
                const SnackBar(
                  content: Text('Chat history cleared'),
                  duration: Duration(seconds: 1),
                ),
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
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
            SizedBox(width: 6),
            Text('Stop AI Agent Execution?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to stop the active AI agent loop execution?',
          style: TextStyle(color: Colors.white70, fontSize: 11),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Agent execution stopped'), duration: Duration(seconds: 2)),
              );
            },
            child: const Text('Stop Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  void _openHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final history = CopilotSessionService.instance.sessionHistory;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(12),
              height: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.history_rounded, color: Colors.cyanAccent, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Chat History & Sessions',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Expanded(
                    child: history.isEmpty
                        ? const Center(
                            child: Text(
                              'No saved chat history yet.\nChats are automatically saved as you converse!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          )
                        : ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final session = history[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  session.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${session.timestamp.hour}:${session.timestamp.minute.toString().padLeft(2, '0')} • ${session.flashMessages.length + session.taskMessages.length} msgs',
                                  style: const TextStyle(color: Colors.grey, fontSize: 9.5),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.cyanAccent, size: 12),
                                onTap: () {
                                  setState(() {
                                    CopilotSessionService.instance.loadSession(session);
                                  });
                                  Navigator.pop(context);
                                  _scrollToBottom();
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
      },
    );
  }

  void _openSettingsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AgentSettingsScreen()),
    );
    _loadPreferences();
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
          padding: const EdgeInsets.all(12),
          height: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.list_alt_rounded, color: Colors.cyanAccent, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Agent Real-Time Action Logs',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
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
                          'No action logs yet.\nLogs appear here live as the AI Agent works!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final timeStr = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyan[900],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  log.title,
                                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.detail,
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(color: Colors.grey, fontSize: 8.5),
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
        CopilotService.addActionLog('Voice Mic', 'Transcribing audio via Whisper engine...');

        final transcribedText = await WhisperService.transcribeAudio(path);

        if (!mounted) return;

        if (transcribedText != null && transcribedText.trim().isNotEmpty) {
          CopilotService.addActionLog('Whisper Complete', 'Transcribed: "$transcribedText"');
          _inputController.text = transcribedText;
          _handleSubmitted(transcribedText);

        } else {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Whisper transcription empty or failed. Please speak again.')),
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
    // Dismiss keyboard immediately on send
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // If AI is already executing a previous task, cancel it immediately so new user command takes over!
    if (_isLoading) {
      CopilotService.stopAgentLoop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _inputController.clear();
    setState(() {
      _messages.add(CopilotChatMessage(sender: 'user', text: trimmed, mode: 'task'));
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
        _messages.add(CopilotChatMessage(
          sender: 'ai',
          text: explanation,
          aiResponse: response,
          isExecuted: pipeline != null,
          mode: 'task',
        ));

        // Always sync grid with C++ engine's updated cell values
        if (pipeline != null) {
          widget.onPipelineApplied?.call(pipeline);
        } else {
          widget.onPipelineApplied?.call({'steps': []});
        }
      } else {
        _messages.add(CopilotChatMessage(
          sender: 'ai',
          text: response.error ?? 'Failed to execute request.',
          mode: 'task',
        ));
      }
    });

    _scrollToBottom();
  }

  void _applyPipeline(CopilotChatMessage msg) {
    if (msg.aiResponse?.pipeline != null) {
      widget.onPipelineApplied?.call(msg.aiResponse!.pipeline!);
      setState(() {
        final idx = _messages.indexOf(msg);
        if (idx != -1) {
          _messages[idx] = msg.copyWith(isExecuted: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [



          // Mini Tool Bar (Status Pill | Clear Chat | History | Logs | Settings)
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder<AgentStatus>(
                  valueListenable: CopilotService.agentStatusNotifier,
                  builder: (context, status, _) {
                    Color dotColor = Colors.greenAccent;
                    String statusText = 'Idle';
                    IconData statusIcon = Icons.check_circle_outline;

                    switch (status) {
                      case AgentStatus.thinking:
                        dotColor = Colors.amberAccent;
                        statusText = 'Thinking...';
                        statusIcon = Icons.psychology_rounded;
                        break;
                      case AgentStatus.planning:
                        dotColor = Colors.cyanAccent;
                        statusText = 'Planning...';
                        statusIcon = Icons.assignment_outlined;
                        break;
                      case AgentStatus.researching:
                        dotColor = Colors.lightBlueAccent;
                        statusText = 'Researching...';
                        statusIcon = Icons.search_rounded;
                        break;
                      case AgentStatus.executing:
                        dotColor = Colors.orangeAccent;
                        statusText = 'Executing...';
                        statusIcon = Icons.flash_on_rounded;
                        break;
                      case AgentStatus.waiting:
                        dotColor = Colors.purpleAccent;
                        statusText = 'Waiting Choice';
                        statusIcon = Icons.hourglass_top_rounded;
                        break;
                      case AgentStatus.paused:
                        dotColor = Colors.redAccent;
                        statusText = 'Paused';
                        statusIcon = Icons.pause_circle_filled_rounded;
                        break;
                      case AgentStatus.completed:
                        dotColor = Colors.greenAccent;
                        statusText = 'Completed';
                        statusIcon = Icons.task_alt_rounded;
                        break;
                      case AgentStatus.failed:
                        dotColor = Colors.red;
                        statusText = 'Failed';
                        statusIcon = Icons.error_outline_rounded;
                        break;
                      default:
                        dotColor = Colors.greenAccent;
                        statusText = 'Idle';
                        statusIcon = Icons.radio_button_checked_rounded;
                        break;
                    }

                    return Row(
                      children: [
                        Icon(statusIcon, color: dotColor, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          statusText,
                          style: TextStyle(color: dotColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    if (_isLoading) ...[
                      InkWell(
                        onTap: _confirmStopAgent,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.red[900],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.redAccent, width: 0.8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.stop_circle_rounded, color: Colors.white, size: 11),
                              SizedBox(width: 2),
                              Text('STOP AI', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    // Provider Toggle Pill (Gemini / DeepSeek)
                    InkWell(
                      onTap: () async {
                        final newP = _selectedProvider == 'gemini' ? 'deepseek' : 'gemini';
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('ai_agent_provider', newP);
                        setState(() {
                          _selectedProvider = newP;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched AI Provider to ${newP == 'gemini' ? 'Google Gemini' : 'DeepSeek AI'}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _selectedProvider == 'deepseek' ? Colors.blue.withOpacity(0.25) : Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _selectedProvider == 'deepseek' ? Colors.blueAccent : Colors.amberAccent,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedProvider == 'deepseek' ? Icons.psychology : Icons.bolt,
                              color: _selectedProvider == 'deepseek' ? Colors.cyanAccent : Colors.amberAccent,
                              size: 11,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _selectedProvider == 'deepseek' ? 'DeepSeek' : 'Gemini',
                              style: TextStyle(
                                color: _selectedProvider == 'deepseek' ? Colors.cyanAccent : Colors.amberAccent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),

                    // Action Logs Icon
                    InkWell(
                      onTap: _openLogsModal,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.list_alt_rounded, color: Colors.amberAccent, size: 12),
                            SizedBox(width: 2),
                            Text('Logs', style: TextStyle(color: Colors.amberAccent, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Clear Chat Icon
                    InkWell(
                      onTap: _clearCurrentChat,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 12),
                            SizedBox(width: 2),
                            Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // History Icon
                    InkWell(
                      onTap: _openHistoryModal,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, color: Colors.cyanAccent, size: 12),
                            SizedBox(width: 2),
                            Text('History', style: TextStyle(color: Colors.cyanAccent, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Settings Icon
                    InkWell(
                      onTap: _openSettingsScreen,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, color: Colors.white70, size: 12),
                            SizedBox(width: 2),
                            Text('Settings', style: TextStyle(color: Colors.white70, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Full Screen Mode Button
                    InkWell(
                      onTap: () {
                        CopilotFullScreenChatScreen.open(
                          context,
                          sheetId: widget.sheetId,
                          onPipelineApplied: widget.onPipelineApplied,
                        ).then((_) => setState(() {}));
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.cyanAccent, width: 0.8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.open_in_full_rounded, color: Colors.cyanAccent, size: 10),
                            SizedBox(width: 3),
                            Text(
                              'Full Screen',
                              style: TextStyle(color: Colors.cyanAccent, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),


          // Messages View Area (Scrollable)
          Expanded(
            child: _buildMessageList(_messages),
          ),

          // Input Bar with Voice Mic & Send Arrow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5),
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? '🎙️ Listening... Tap mic to stop & auto-send'
                            : 'Ask AI Agent or give task instructions...',
                        hintStyle: TextStyle(
                          color: _isRecording ? Colors.redAccent : Colors.grey[500],
                          fontSize: 10,
                          fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Voice Mic Button
                AnimatedBuilder(
                  animation: _micPulseController,
                  builder: (context, child) {
                    final pulseScale = 1.0 + (_micPulseController.value * 0.25);
                    return Transform.scale(
                      scale: _isRecording ? pulseScale : 1.0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.redAccent : const Color(0xFF0F172A),
                          boxShadow: _isRecording
                              ? [BoxShadow(color: Colors.redAccent.withOpacity(0.8), blurRadius: 8, spreadRadius: 2)]
                              : null,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: _isRecording ? Colors.white : Colors.cyanAccent, size: 16),
                          onPressed: _toggleRecording,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // Send Arrow Button
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: _isLoading
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                        : const Icon(Icons.send_rounded, color: Colors.cyanAccent, size: 16),
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

  Widget _buildMessageList(List<CopilotChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg.sender == 'user';
        final isLatestAi = !isUser && index == messages.length - 1;

        final bubbleContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isUser ? Icons.person : Icons.smart_toy, size: 10, color: isUser ? Colors.white70 : Colors.cyanAccent),
                    const SizedBox(width: 3),
                    Text(isUser ? 'You' : 'AI Agent', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isUser ? Colors.white70 : Colors.cyanAccent)),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard!'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_copy_rounded, size: 10, color: isUser ? Colors.white70 : Colors.cyanAccent),
                        const SizedBox(width: 2),
                        Text('Copy', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: isUser ? Colors.white70 : Colors.cyanAccent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (!isUser && isLatestAi)
              _SparklingTypewriterText(
                text: msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 10.0, height: 1.25),
                onComplete: _scrollToBottom,
              )
            else
              SelectableText(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 10.0, height: 1.25),
              ),
            if (msg.aiResponse?.pipeline != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.aiResponse!.planSummary.isNotEmpty) ...[
                      Text('Plan: ${msg.aiResponse!.planSummary}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 22,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: msg.isExecuted ? Colors.grey[700] : Colors.green[700], padding: const EdgeInsets.symmetric(horizontal: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        onPressed: msg.isExecuted ? null : () => _applyPipeline(msg),
                        icon: Icon(msg.isExecuted ? Icons.check_circle : Icons.play_arrow_rounded, size: 12, color: Colors.white),
                        label: Text(msg.isExecuted ? 'Applied' : 'Run Action', style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (msg.aiResponse?.questionPayload != null)
              CopilotQuestionCard(
                questionPayload: msg.aiResponse!.questionPayload!,
                currentAnswer: msg.userAnswer,
                isDarkMode: true,
                onAnswerSubmitted: (answer) {
                  setState(() {
                    final idx = _messages.indexOf(msg);
                    if (idx != -1) {
                      _messages[idx] = msg.copyWith(userAnswer: answer);
                    }
                  });
                  _handleSubmitted(answer);
                },
              ),
          ],
        );


        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
            child: isUser
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(2)),
                    ),
                    child: bubbleContent,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: bubbleContent,
                  ),
          ),
        );
      },
    );
  }
}

class _TinyParticle {
  double x;
  double y;
  double vx;
  double vy;
  double opacity;
  double size;
  Color color;

  _TinyParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.opacity,
    required this.size,
    required this.color,
  });
}

class _StardustPainter extends CustomPainter {
  final List<_TinyParticle> particles;

  _StardustPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);

      final linePaint = Paint()
        ..color = p.color.withOpacity((p.opacity * 0.8).clamp(0.0, 1.0))
        ..strokeWidth = 0.8;
      canvas.drawLine(
        Offset(p.x - p.size * 1.5, p.y),
        Offset(p.x + p.size * 1.5, p.y),
        linePaint,
      );
      canvas.drawLine(
        Offset(p.x, p.y - p.size * 1.5),
        Offset(p.x, p.y + p.size * 1.5),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StardustPainter oldDelegate) => true;
}

class _SparklingTypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onComplete;

  const _SparklingTypewriterText({
    Key? key,
    required this.text,
    required this.style,
    this.onComplete,
  }) : super(key: key);

  @override
  State<_SparklingTypewriterText> createState() => _SparklingTypewriterTextState();
}

class _SparklingTypewriterTextState extends State<_SparklingTypewriterText>
    with TickerProviderStateMixin {
  String _displayedText = "";
  Timer? _typingTimer;
  bool _isTyping = true;
  bool _showEndBurst = false;

  late AnimationController _particleAnimController;
  late AnimationController _endBurstController;

  final List<_TinyParticle> _particles = [];
  final math.Random _random = math.Random();

  static const List<Color> _neonColors = [
    Colors.cyanAccent,
    Colors.amberAccent,
    Colors.pinkAccent,
    Colors.lightGreenAccent,
    Colors.purpleAccent,
    Colors.deepOrangeAccent,
  ];

  @override
  void initState() {
    super.initState();
    _particleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 30),
    )..addListener(_updateParticles);

    _endBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _particleAnimController.repeat();
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant _SparklingTypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startTyping();
    }
  }

  void _spawnTinyParticles() {
    for (int i = 0; i < 4; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 0.5 + _random.nextDouble() * 2.0;
      _particles.add(_TinyParticle(
        x: 0,
        y: 0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 0.5,
        opacity: 1.0,
        size: 1.0 + _random.nextDouble() * 1.8,
        color: _neonColors[_random.nextInt(_neonColors.length)],
      ));
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (int i = _particles.length - 1; i >= 0; i--) {
        var p = _particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.opacity -= 0.06;
        if (p.opacity <= 0) {
          _particles.removeAt(i);
        }
      }
    });
  }

  void _startTyping() {
    int index = 0;
    _typingTimer?.cancel();
    _isTyping = true;
    _showEndBurst = false;
    _particles.clear();

    _typingTimer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (index < widget.text.length) {
        if (mounted) {
          setState(() {
            _displayedText = widget.text.substring(0, index + 1);
            _spawnTinyParticles();
          });
        }
        index++;
      } else {
        _typingTimer?.cancel();
        if (mounted) {
          setState(() {
            _isTyping = false;
            _showEndBurst = true;
          });
          _endBurstController.forward(from: 0.0).then((_) {
            if (mounted) {
              setState(() {
                _showEndBurst = false;
              });
            }
          });
        }
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _particleAnimController.dispose();
    _endBurstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _endBurstController,
      builder: (context, child) {
        final isBursting = _showEndBurst && _endBurstController.isAnimating;

        Widget textWidget = SelectableText(_displayedText, style: widget.style);

        if (isBursting) {
          final progress = _endBurstController.value;
          textWidget = ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: const [
                  Colors.white,
                  Colors.cyanAccent,
                  Colors.amberAccent,
                  Colors.pinkAccent,
                  Colors.white,
                ],
                stops: [
                  (progress - 0.3).clamp(0.0, 1.0),
                  (progress - 0.15).clamp(0.0, 1.0),
                  progress.clamp(0.0, 1.0),
                  (progress + 0.15).clamp(0.0, 1.0),
                  (progress + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            child: textWidget,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                textWidget,
                if (_isTyping)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CustomPaint(
                      painter: _StardustPainter(_particles),
                    ),
                  ),
              ],
            ),
            if (isBursting)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FullTextStarSparklePainter(
                      progress: _endBurstController.value,
                      colors: _neonColors,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FullTextStarSparklePainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _FullTextStarSparklePainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random random = math.Random(42);
    const int starCount = 18;

    for (int i = 0; i < starCount; i++) {
      final rx = random.nextDouble() * size.width;
      final ry = random.nextDouble() * size.height;
      final starPhase = (progress * 2.5 - (i / starCount)).clamp(0.0, 1.0);

      if (starPhase > 0.0 && starPhase < 1.0) {
        final scale = math.sin(starPhase * math.pi) * 3.5;
        final color = colors[i % colors.length].withOpacity(math.sin(starPhase * math.pi));

        final paint = Paint()
          ..color = color
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        canvas.drawLine(Offset(rx - scale, ry), Offset(rx + scale, ry), paint);
        canvas.drawLine(Offset(rx, ry - scale), Offset(rx, ry + scale), paint);
        canvas.drawCircle(Offset(rx, ry), scale * 0.4, Paint()..color = Colors.white.withOpacity(math.sin(starPhase * math.pi)));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FullTextStarSparklePainter oldDelegate) => true;
}
