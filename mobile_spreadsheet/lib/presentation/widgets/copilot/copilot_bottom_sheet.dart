import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/services/copilot/copilot_service.dart';
import '../../../domain/services/copilot/local_agent_service.dart';
import '../../settings/agent_settings_screen.dart';

class CopilotChatMessage {
  final String sender; // 'user' or 'ai'
  final String text;
  final CopilotResponse? aiResponse;
  final bool isExecuted;
  final String? userAnswer;

  CopilotChatMessage({
    required this.sender,
    required this.text,
    this.aiResponse,
    this.isExecuted = false,
    this.userAnswer,
  });

  CopilotChatMessage copyWith({bool? isExecuted, String? userAnswer}) {
    return CopilotChatMessage(
      sender: sender,
      text: text,
      aiResponse: aiResponse,
      isExecuted: isExecuted ?? this.isExecuted,
      userAnswer: userAnswer ?? this.userAnswer,
    );
  }
}

class CopilotBottomSheet extends StatefulWidget {
  final String sheetId;
  final Function(Map<String, dynamic>)? onPipelineApplied;

  const CopilotBottomSheet({
    Key? key,
    required this.sheetId,
    this.onPipelineApplied,
  }) : super(key: key);

  static void show(BuildContext context, {required String sheetId, Function(Map<String, dynamic>)? onPipelineApplied}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CopilotBottomSheet(
        sheetId: sheetId,
        onPipelineApplied: onPipelineApplied,
      ),
    );
  }

  @override
  State<CopilotBottomSheet> createState() => _CopilotBottomSheetState();
}

class _CopilotBottomSheetState extends State<CopilotBottomSheet> {
  final TextEditingController _inputController = TextEditingController();
  final List<CopilotChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isRecording = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String _selectedProvider = "gemini"; // "gemini" or "deepseek"

  @override
  void initState() {
    super.initState();
    _loadSelectedProvider();
    // Welcome message
    _messages.add(CopilotChatMessage(
      sender: 'ai',
      text: 'Namaste! Main **Sheet Copilot** hoon 🤖\nAap mujhse bol kar 🎤 ya likh kar apni sheet par filters, data cleaning, formulas aur transformations apply karwa sakte hain.\nModel: Google Gemini aur DeepSeek supported!',
    ));
  }

  Future<void> _loadSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString('ai_agent_provider') ?? 'gemini';
    if (mounted) {
      setState(() {
        _selectedProvider = p;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  void _showApiKeyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final geminiKey = prefs.getString('gemini_api_key') ?? '';
    final deepSeekKey = prefs.getString('deepseek_api_key') ?? '';
    final geminiController = TextEditingController(text: geminiKey);
    final deepSeekController = TextEditingController(text: deepSeekKey);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2541),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.vpn_key, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text('AI API Settings', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: geminiController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key',
                    labelStyle: TextStyle(color: Colors.amberAccent),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deepSeekController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'DeepSeek API Key',
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                AgentSettingsScreen.navigate(context);
              },
              child: const Text('All Settings', style: TextStyle(color: Colors.cyanAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                await prefs.setString('gemini_api_key', geminiController.text.trim());
                await prefs.setString('deepseek_api_key', deepSeekController.text.trim());
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Keys Saved')));
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  void _sendMessage() async {
    // Dismiss keyboard immediately on send
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    // If AI is already executing a previous task, cancel it immediately so new user command takes over!
    if (_isLoading) {
      LocalAgentService.cancelLoop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _messages.add(CopilotChatMessage(sender: 'user', text: text));
      _inputController.clear();
      _isLoading = true;
    });

    final resp = await CopilotService.sendPrompt(
      prompt: text,
      sheetId: widget.sheetId,
      provider: _selectedProvider,
    );

    setState(() {
      _isLoading = false;
      if (resp.success) {
        final pipeline = resp.pipeline;
        _messages.add(CopilotChatMessage(
          sender: 'ai',
          text: resp.explanation,
          aiResponse: resp,
          isExecuted: pipeline != null,
        ));
        
        // Trigger a grid refresh & auto-execute pipeline
        if (widget.onPipelineApplied != null) {
          if (pipeline != null) {
            widget.onPipelineApplied!(pipeline);
          } else {
            widget.onPipelineApplied!({'steps': []});
          }
        }
      } else {
        _messages.add(CopilotChatMessage(
          sender: 'ai',
          text: 'Error: ${resp.error ?? "Failed to process request"}',
        ));
      }
    });
  }

  void _toggleRecording() async {
    if (!_isRecording) {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/stt_audio.wav';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: filePath,
        );
        setState(() {
          _isRecording = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
        }
      }
    } else {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isLoading = true;
      });

      if (path != null) {
        try {
          final bytes = await File(path).readAsBytes();
          final text = await CopilotService.transcribeAudioBytes(bytes);
          if (mounted) {
            if (text != null && text.isNotEmpty) {
              setState(() {
                _inputController.text = text;
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not transcribe audio. Please try again.')),
              );
            }
          }
        } catch (e) {
          debugPrint("Audio read error: $e");
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _executePipeline(CopilotChatMessage message, int index) {
    if (message.aiResponse == null || message.aiResponse!.pipeline == null) {
      debugPrint("[CopilotSheet] _executePipeline: aiResponse or pipeline is null");
      return;
    }

    final pipeline = message.aiResponse!.pipeline!;
    debugPrint("[CopilotSheet] _executePipeline: pipeline keys=${pipeline.keys.toList()}, steps count=${(pipeline['steps'] as List?)?.length ?? 'NO STEPS KEY'}");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Executing AI Pipeline...'),
        backgroundColor: Colors.blue,
      ),
    );

    setState(() {
      _messages[index] = message.copyWith(isExecuted: true);
    });

    if (widget.onPipelineApplied != null) {
      widget.onPipelineApplied!(pipeline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF252538),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Sheet Copilot AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.vpn_key, color: Colors.purpleAccent, size: 20),
                  onPressed: _showApiKeyDialog,
                  tooltip: 'Set API Key',
                ),
                // Provider Selector (Gemini / DeepSeek)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProvider,
                      dropdownColor: const Color(0xFF252538),
                      style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(
                          value: 'gemini',
                          child: Row(
                            children: [
                              Icon(Icons.bolt, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text('Gemini'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'deepseek',
                          child: Row(
                            children: [
                              Icon(Icons.psychology, color: Colors.cyanAccent, size: 16),
                              SizedBox(width: 4),
                              Text('DeepSeek'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('ai_agent_provider', val);
                          setState(() {
                            _selectedProvider = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.sender == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.purple.shade700
                          : const Color(0xFF2D2D44),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser
                            ? Colors.purpleAccent.withOpacity(0.5)
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isUser ? 'You' : 'Sheet Copilot',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isUser ? Colors.white70 : Colors.purpleAccent,
                              ),
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
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.content_copy_rounded,
                                      size: 12,
                                      color: isUser ? Colors.white70 : Colors.purpleAccent,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Copy',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isUser ? Colors.white70 : Colors.purpleAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          msg.text,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                        ),
                        if (msg.aiResponse != null && msg.aiResponse!.pipeline != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.schema, color: Colors.amber, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Plan: ${msg.aiResponse!.planSummary}',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: msg.isExecuted
                                      ? null
                                      : () => _executePipeline(msg, index),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: msg.isExecuted
                                        ? Colors.grey
                                        : Colors.purpleAccent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 36),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: Icon(
                                    msg.isExecuted
                                        ? Icons.check_circle
                                        : Icons.play_arrow,
                                    size: 18,
                                  ),
                                  label: Text(
                                    msg.isExecuted
                                        ? 'Applied to C++ Engine'
                                        : 'Run Pipeline (C++ Engine)',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                  ),
                  SizedBox(width: 8),
                  Text('Sheet Copilot is thinking...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

          // Input Bar (Text + Microphone Speech Button)
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: 12,
              top: 8,
            ),
            child: Row(
              children: [
                // Mic button for STT
                GestureDetector(
                  onTap: _toggleRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent : Colors.purple.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording ? Colors.red : Colors.purpleAccent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Listening...' : 'Ask Copilot or dictate...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF252538),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.purpleAccent, size: 28),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
