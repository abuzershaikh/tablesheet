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
  late AnimationController _aiBreathController;

  List<CopilotSessionMessage> get _messages => CopilotSessionService.instance.taskMessages;

  // ── Premium Color Palette ──
  static const _primaryBlue = Color(0xFF2563EB);
  static const _lightBlue = Color(0xFF3B82F6);
  static const _paleBlue = Color(0xFFDBEAFE);
  static const _surfaceWhite = Color(0xFFF8FAFC);
  static const _cardWhite = Colors.white;
  static const _headerBlue = Color(0xFF1E40AF);
  static const _textDark = Color(0xFF1E293B);
  static const _textMuted = Color(0xFF64748B);
  static const _borderLight = Color(0xFFE2E8F0);
  static const _aiAccent = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    CopilotSessionService.instance.ensureInitialized();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _aiBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
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
    _aiBreathController.dispose();
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
        backgroundColor: _cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade400, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Clear Chat?', style: TextStyle(color: _textDark, fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'This will delete the entire conversation history with SheetPro AI.',
          style: TextStyle(color: _textMuted, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                CopilotSessionService.instance.clearTab('task');
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Chat cleared'),
                  backgroundColor: _primaryBlue,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmStopAgent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.pause_circle_filled_rounded, color: Colors.orange.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Stop Agent?', style: TextStyle(color: _textDark, fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'The AI agent is currently working on your spreadsheet. Are you sure you want to stop?',
          style: TextStyle(color: _textMuted, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue', style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              CopilotService.stopAgentLoop();
              setState(() {
                _isLoading = false;
              });
            },
            child: const Text('Stop Agent', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openLogsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _paleBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.terminal_rounded, color: _primaryBlue, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Live Action Logs',
                        style: TextStyle(color: _textDark, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _surfaceWhite,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close_rounded, color: _textMuted, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<List<AgentActionLog>>(
                  valueListenable: CopilotService.actionLogsNotifier,
                  builder: (context, logs, _) {
                    if (logs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insights_rounded, color: _borderLight, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No logs yet',
                              style: TextStyle(color: _textMuted, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Logs appear as the agent performs actions',
                              style: TextStyle(color: _textMuted.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderLight),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _paleBlue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.title,
                                  style: const TextStyle(color: _primaryBlue, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.detail,
                                      style: const TextStyle(color: _textDark, fontSize: 12, height: 1.3),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      timeStr,
                                      style: TextStyle(color: _textMuted.withValues(alpha: 0.5), fontSize: 10),
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
        SnackBar(
          content: const Text('Pipeline applied to sheet!'),
          backgroundColor: _primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceWhite,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_headerBlue, _primaryBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // ── Back Button ──
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Sheet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── SheetPro AI Title + Status ──
                  Expanded(
                    child: ValueListenableBuilder<AgentStatus>(
                      valueListenable: CopilotService.agentStatusNotifier,
                      builder: (context, status, _) {
                        String statusEmoji;
                        String statusText;

                        switch (status) {
                          case AgentStatus.thinking:
                            statusEmoji = '🧠';
                            statusText = 'Thinking...';
                            break;
                          case AgentStatus.planning:
                            statusEmoji = '📋';
                            statusText = 'Planning...';
                            break;
                          case AgentStatus.researching:
                            statusEmoji = '🔍';
                            statusText = 'Analyzing...';
                            break;
                          case AgentStatus.executing:
                            statusEmoji = '⚡';
                            statusText = 'Executing...';
                            break;
                          case AgentStatus.waiting:
                            statusEmoji = '⏳';
                            statusText = 'Awaiting Input';
                            break;
                          case AgentStatus.completed:
                            statusEmoji = '✅';
                            statusText = 'Completed';
                            break;
                          case AgentStatus.failed:
                            statusEmoji = '❌';
                            statusText = 'Failed';
                            break;
                          default:
                            statusEmoji = '🟢';
                            statusText = 'Ready';
                            break;
                        }

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('✨ ', style: TextStyle(fontSize: 14)),
                                const Text(
                                  'SheetPro',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                ),
                                const SizedBox(width: 4),
                                AnimatedBuilder(
                                  animation: _aiBreathController,
                                  builder: (context, child) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color.lerp(const Color(0xFF06B6D4), const Color(0xFF8B5CF6), _aiBreathController.value)!,
                                            Color.lerp(const Color(0xFF8B5CF6), const Color(0xFF06B6D4), _aiBreathController.value)!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3 + _aiBreathController.value * 0.2),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'AI',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$statusEmoji $statusText',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // ── Model Switcher (Emoji style) ──
                  InkWell(
                    onTap: () async {
                      final newProv = _selectedProvider == 'gemini' ? 'deepseek' : 'gemini';
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('ai_agent_provider', newProv);
                      setState(() {
                        _selectedProvider = newProv;
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched to ${newProv == 'deepseek' ? '🐋 DeepSeek' : '✨ Gemini'}'),
                          backgroundColor: _primaryBlue,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _selectedProvider == 'deepseek' ? '🐋' : '✨',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // ── Action Buttons ──
                  _headerIconButton(Icons.receipt_long_rounded, _openLogsModal),
                  _headerIconButton(Icons.delete_outline_rounded, _clearChat),
                  _headerIconButton(Icons.tune_rounded, () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgentSettingsScreen()),
                  ).then((_) => _loadPreferences())),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Agent Progress Bar ──
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _cardWhite,
                border: const Border(bottom: BorderSide(color: _borderLight)),
                boxShadow: [
                  BoxShadow(color: _primaryBlue.withValues(alpha: 0.06), blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _primaryBlue,
                      backgroundColor: _paleBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SheetPro AI is analyzing your spreadsheet...',
                      style: TextStyle(color: _primaryBlue, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade500,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _confirmStopAgent,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop_circle_rounded, size: 15),
                        SizedBox(width: 4),
                        Text('Stop', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Empty State / Welcome ──
          if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated logo
                      AnimatedBuilder(
                        animation: _aiBreathController,
                        builder: (context, child) {
                          return Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(_primaryBlue, _aiAccent, _aiBreathController.value)!,
                                  Color.lerp(_aiAccent, _primaryBlue, _aiBreathController.value)!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryBlue.withValues(alpha: 0.2 + _aiBreathController.value * 0.15),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('✨', style: TextStyle(fontSize: 36)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'SheetPro AI',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your intelligent spreadsheet assistant.\nAsk me to clean, calculate, format, or analyze your data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // ── Chat Messages ──
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index], index == _messages.length - 1);
                },
              ),
            ),

          // ── Bottom Input Bar ──
          Container(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: _cardWhite,
              border: const Border(top: BorderSide(color: _borderLight)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _isRecording ? Colors.red.shade300 : _borderLight, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withValues(alpha: 0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? '🎙️ Listening... Tap mic to stop'
                            : 'Ask SheetPro AI anything...',
                        hintStyle: TextStyle(
                          color: _isRecording ? Colors.red.shade400 : _textMuted,
                          fontSize: 13.5,
                          fontWeight: _isRecording ? FontWeight.w600 : FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ── Voice Mic ──
                AnimatedBuilder(
                  animation: _micPulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_micPulseController.value * 0.2);
                    return Transform.scale(
                      scale: _isRecording ? scale : 1.0,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.red.shade500 : _surfaceWhite,
                          border: Border.all(
                            color: _isRecording ? Colors.red.shade400 : _borderLight,
                            width: 1.5,
                          ),
                          boxShadow: _isRecording
                              ? [BoxShadow(color: Colors.red.shade300.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                              : null,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: _isRecording ? Colors.white : _primaryBlue,
                            size: 20,
                          ),
                          onPressed: _toggleRecording,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // ── Send Button ──
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_primaryBlue, _lightBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

  Widget _headerIconButton(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
        icon: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
        onPressed: onPressed,
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
            // ── AI Avatar ──
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryBlue, _aiAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? _primaryBlue : _cardWhite,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                border: isUser ? null : Border.all(color: _borderLight),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? _primaryBlue.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sender Header ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isUser ? '👤 You' : '✨ SheetPro AI',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isUser ? Colors.white.withValues(alpha: 0.75) : _primaryBlue,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('📋 Copied to clipboard'),
                              backgroundColor: _primaryBlue,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.content_copy_rounded,
                            size: 13,
                            color: isUser ? Colors.white.withValues(alpha: 0.5) : _textMuted.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Message Content ──
                  SelectableText(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : _textDark,
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // ── Pipeline Execution Card ──
                  if (msg.aiResponse?.pipeline != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _surfaceWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.aiResponse!.planSummary.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.route_rounded, color: _primaryBlue, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    msg.aiResponse!.planSummary,
                                    style: const TextStyle(color: _primaryBlue, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: msg.isExecuted ? const Color(0xFF94A3B8) : _primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: msg.isExecuted ? 0 : 2,
                              ),
                              onPressed: msg.isExecuted ? null : () => _applyPipeline(msg),
                              icon: Icon(
                                msg.isExecuted ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                                size: 16,
                              ),
                              label: Text(
                                msg.isExecuted ? 'Applied ✓' : '▶ Execute on Sheet',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Interactive Choice Cards ──
                  if (msg.aiResponse?.questionPayload != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _surfaceWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _paleBlue),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              const Text(
                                'Select your choice:',
                                style: TextStyle(color: _primaryBlue, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: msg.aiResponse!.questionPayload!.options.map((opt) {
                              final isDefault = opt == msg.aiResponse!.questionPayload!.defaultOption;
                              return InkWell(
                                onTap: () => _handleSubmitted(opt),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDefault ? _paleBlue : _cardWhite,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDefault ? _primaryBlue : _borderLight,
                                      width: isDefault ? 1.5 : 1,
                                    ),
                                    boxShadow: isDefault
                                        ? [BoxShadow(color: _primaryBlue.withValues(alpha: 0.1), blurRadius: 6)]
                                        : null,
                                  ),
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      color: isDefault ? _primaryBlue : _textDark,
                                      fontSize: 12,
                                      fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
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
            // ── User Avatar ──
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 10, top: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_lightBlue, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _lightBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
