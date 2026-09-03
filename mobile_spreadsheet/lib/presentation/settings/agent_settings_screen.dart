import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_spreadsheet/domain/services/copilot/local_agent_service.dart';

class AgentSettingsScreen extends StatefulWidget {
  const AgentSettingsScreen({Key? key}) : super(key: key);

  static void navigate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AgentSettingsScreen()),
    );
  }

  @override
  State<AgentSettingsScreen> createState() => _AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _deepSeekApiKeyController = TextEditingController();
  final TextEditingController _customPromptController = TextEditingController();

  String _selectedProvider = 'gemini'; // 'gemini' or 'deepseek'
  String _selectedModel = 'gemini-2.0-flash';
  String _selectedDeepSeekModel = 'deepseek-chat';
  bool _memoryEnabled = true;
  bool _continuousLoopEnabled = true;
  bool _inspectSheetEnabled = true;
  bool _quickJsEnabled = true;
  bool _useBottomSheet = false;
  bool _autoExecutePipeline = true;
  bool _isTestingKey = false;
  String? _testResult;
  bool _isTestSuccess = false;

  bool _isTestingDeepSeekKey = false;
  String? _deepSeekTestResult;
  bool _isDeepSeekTestSuccess = false;

  final List<Map<String, String>> _models = [
    {
      'id': 'gemini-2.0-flash',
      'name': 'Gemini 2.0 Flash (Next-Gen Fast & Agentic)',
      'badge': 'RECOMMENDED',
    },
    {
      'id': 'gemini-1.5-flash',
      'name': 'Gemini 1.5 Flash (Fast & Cost Efficient)',
      'badge': 'STABLE',
    },
    {
      'id': 'gemini-2.5-flash',
      'name': 'Gemini 2.5 Flash (High Reasoning Speed)',
      'badge': 'NEW',
    },
    {
      'id': 'gemini-2.0-flash-lite',
      'name': 'Gemini 2.0 Flash Lite (Ultra Low Latency)',
      'badge': 'FAST',
    },
    {
      'id': 'gemini-2.5-pro',
      'name': 'Gemini 2.5 Pro (Deep Complex Reasoning)',
      'badge': 'PRO',
    },
    {
      'id': 'gemini-1.5-pro',
      'name': 'Gemini 1.5 Pro (Enterprise Reasoning)',
      'badge': 'PRO',
    },
  ];

  final List<Map<String, String>> _deepSeekModels = [
    {
      'id': 'deepseek-chat',
      'name': 'DeepSeek-V3 (Fast Autonomous Agent & Tools)',
      'badge': 'RECOMMENDED',
    },
    {
      'id': 'deepseek-reasoner',
      'name': 'DeepSeek-R1 (Deep Reasoning & Complex Math)',
      'badge': 'REASONING',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String savedModel = prefs.getString('ai_agent_selected_model') ?? 'gemini-2.0-flash';
    String savedProvider = prefs.getString('ai_agent_provider') ?? 'gemini';
    String savedDeepSeekModel = prefs.getString('deepseek_selected_model') ?? 'deepseek-chat';

    if (savedModel.startsWith('gemini-3.') || !_models.any((m) => m['id'] == savedModel)) {
      savedModel = 'gemini-2.0-flash';
      await prefs.setString('ai_agent_selected_model', 'gemini-2.0-flash');
    }

    final modelToUse = savedModel;

    setState(() {
      _selectedProvider = savedProvider;
      _apiKeyController.text = prefs.getString('gemini_api_key') ?? '';
      _deepSeekApiKeyController.text = prefs.getString('deepseek_api_key') ?? '';
      _selectedModel = modelToUse;
      _selectedDeepSeekModel = savedDeepSeekModel;
      _memoryEnabled = prefs.getBool('ai_agent_memory_enabled') ?? true;
      _continuousLoopEnabled = prefs.getBool('ai_agent_continuous_loop_enabled') ?? true;
      _inspectSheetEnabled = prefs.getBool('ai_agent_inspect_sheet_enabled') ?? true;
      _quickJsEnabled = prefs.getBool('ai_agent_quickjs_enabled') ?? true;
      _useBottomSheet = prefs.getBool('ai_agent_use_bottom_sheet') ?? false;
      _autoExecutePipeline = prefs.getBool('ai_agent_auto_execute_pipeline') ?? true;
      _customPromptController.text = prefs.getString('ai_agent_custom_instructions') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_agent_provider', _selectedProvider);
    await prefs.setString('gemini_api_key', _apiKeyController.text.trim());
    await prefs.setString('deepseek_api_key', _deepSeekApiKeyController.text.trim());
    await prefs.setString('ai_agent_selected_model', _selectedModel);
    await prefs.setString('deepseek_selected_model', _selectedDeepSeekModel);
    await prefs.setBool('ai_agent_memory_enabled', _memoryEnabled);
    await prefs.setBool('ai_agent_continuous_loop_enabled', _continuousLoopEnabled);
    await prefs.setBool('ai_agent_inspect_sheet_enabled', _inspectSheetEnabled);
    await prefs.setBool('ai_agent_quickjs_enabled', _quickJsEnabled);
    await prefs.setBool('ai_agent_use_bottom_sheet', _useBottomSheet);
    await prefs.setBool('ai_agent_auto_execute_pipeline', _autoExecutePipeline);
    await prefs.setString('ai_agent_custom_instructions', _customPromptController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Color(0xFF107C41),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testResult = 'Please enter a Gemini API Key first.';
        _isTestSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingKey = true;
      _testResult = null;
    });

    try {
      final cleanModel = _selectedModel.startsWith('models/') ? _selectedModel.substring(7) : _selectedModel;
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$key');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Ping'}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _testResult = 'Connected! Model "$_selectedModel" ready & operational.';
          _isTestSuccess = true;
        });
      } else {
        final errJson = jsonDecode(response.body);
        final msg = (errJson is Map) ? (errJson['error']?['message'] ?? response.body) : response.body;
        setState(() {
          _testResult = 'Error (${response.statusCode}): $msg';
          _isTestSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _testResult = 'Network Error: $e';
        _isTestSuccess = false;
      });
    } finally {
      setState(() {
        _isTestingKey = false;
      });
    }
  }

  Future<void> _testDeepSeekApiKey() async {
    final key = _deepSeekApiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _deepSeekTestResult = 'Please enter a DeepSeek API Key first.';
        _isDeepSeekTestSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingDeepSeekKey = true;
      _deepSeekTestResult = null;
    });

    try {
      final url = Uri.parse('https://api.deepseek.com/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': _selectedDeepSeekModel,
          'messages': [
            {'role': 'user', 'content': 'Ping'}
          ],
          'max_tokens': 5,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _deepSeekTestResult = 'Connected! DeepSeek model "$_selectedDeepSeekModel" ready & operational.';
          _isDeepSeekTestSuccess = true;
        });
      } else {
        final errJson = jsonDecode(response.body);
        final msg = (errJson is Map) ? (errJson['error']?['message'] ?? response.body) : response.body;
        setState(() {
          _deepSeekTestResult = 'Error (${response.statusCode}): $msg';
          _isDeepSeekTestSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _deepSeekTestResult = 'Network Error: $e';
        _isDeepSeekTestSuccess = false;
      });
    } finally {
      setState(() {
        _isTestingDeepSeekKey = false;
      });
    }
  }

  void _clearAgentMemory() {
    LocalAgentService.clearMemory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Agent conversation memory cleared'),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: AppBar(
          backgroundColor: const Color(0xFF1C2541),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: const [
              Icon(Icons.smart_toy_outlined, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Agent Settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.check, color: Colors.cyanAccent, size: 16),
              label: const Text('Save', style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. AI Provider Selector
            _buildCompactSection(
              title: 'AI Engine Provider',
              icon: Icons.hub_outlined,
              color: Colors.cyanAccent,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedProvider = 'gemini'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedProvider == 'gemini'
                              ? Colors.cyanAccent.withOpacity(0.15)
                              : const Color(0xFF0B132B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedProvider == 'gemini' ? Colors.cyanAccent : const Color(0xFF334155),
                            width: _selectedProvider == 'gemini' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Google Gemini',
                              style: TextStyle(
                                color: _selectedProvider == 'gemini' ? Colors.cyanAccent : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedProvider = 'deepseek'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedProvider == 'deepseek'
                              ? Colors.blueAccent.withOpacity(0.15)
                              : const Color(0xFF0B132B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedProvider == 'deepseek' ? Colors.blueAccent : const Color(0xFF334155),
                            width: _selectedProvider == 'deepseek' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.psychology, color: Colors.cyanAccent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'DeepSeek AI',
                              style: TextStyle(
                                color: _selectedProvider == 'deepseek' ? Colors.blueAccent : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (_selectedProvider == 'gemini') ...[
              // 1. Gemini API Key Section
              _buildCompactSection(
                title: 'Gemini API Key',
                icon: Icons.key_outlined,
                color: Colors.amberAccent,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _apiKeyController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                hintText: 'Enter Gemini API Key (AIzaSy...)',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF0B132B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF334155)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF334155)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.cyanAccent),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isTestingKey ? null : _testApiKey,
                            child: _isTestingKey
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _isTestSuccess ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. Select Gemini AI Model
              _buildCompactSection(
                title: 'Gemini Model Selection',
                icon: Icons.psychology_outlined,
                color: Colors.cyanAccent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _models.any((m) => m['id'] == _selectedModel) ? _selectedModel : _models.first['id']!,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1C2541),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _models.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Row(
                            children: [
                              Text(m['name']!, style: const TextStyle(fontSize: 13, color: Colors.white)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m['badge']!,
                                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedModel = val);
                      },
                    ),
                  ),
                ),
              ),
            ] else ...[
              // 1. DeepSeek API Key Section
              _buildCompactSection(
                title: 'DeepSeek API Key',
                icon: Icons.key_outlined,
                color: Colors.blueAccent,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _deepSeekApiKeyController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                hintText: 'Enter DeepSeek API Key (sk-...)',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF0B132B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF334155)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF334155)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.blueAccent),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isTestingDeepSeekKey ? null : _testDeepSeekApiKey,
                            child: _isTestingDeepSeekKey
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    if (_deepSeekTestResult != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _deepSeekTestResult!,
                          style: TextStyle(
                            color: _isDeepSeekTestSuccess ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. Select DeepSeek Model
              _buildCompactSection(
                title: 'DeepSeek Model Selection',
                icon: Icons.psychology_outlined,
                color: Colors.blueAccent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _deepSeekModels.any((m) => m['id'] == _selectedDeepSeekModel)
                          ? _selectedDeepSeekModel
                          : _deepSeekModels.first['id']!,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1C2541),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: _deepSeekModels.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Row(
                            children: [
                              Text(m['name']!, style: const TextStyle(fontSize: 13, color: Colors.white)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m['badge']!,
                                  style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDeepSeekModel = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),

            // 3. Agent Memory & Loop Controls
            _buildCompactSection(
              title: 'Agent Memory & Task Loop',
              icon: Icons.loop_rounded,
              color: Colors.purpleAccent,
              child: Column(
                children: [
                  _buildCompactSwitch(
                    title: 'Context & Sheet Memory',
                    subtitle: 'Remembers past prompts, grid states & multi-turn history',
                    value: _memoryEnabled,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) => setState(() => _memoryEnabled = val),
                  ),
                  const Divider(color: Color(0xFF334155), height: 12),
                  _buildCompactSwitch(
                    title: 'Continuous Task Mode (Heartbeat)',
                    subtitle: 'Runs multi-turn plan iterations continuously until task complete',
                    value: _continuousLoopEnabled,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) => setState(() => _continuousLoopEnabled = val),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: _clearAgentMemory,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.delete_sweep_outlined, size: 14, color: Colors.redAccent),
                            SizedBox(width: 4),
                            Text('Reset Conversation Memory', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 4. Engine Controls
            _buildCompactSection(
              title: 'Engine Capabilities',
              icon: Icons.settings_suggest_outlined,
              color: Colors.greenAccent,
              child: Column(
                children: [
                  _buildCompactSwitch(
                    title: 'Spatial Sheet Inspection (inspect_sheet)',
                    subtitle: 'Inspects total rows, max column & headers before actions',
                    value: _inspectSheetEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => setState(() => _inspectSheetEnabled = val),
                  ),
                  const Divider(color: Color(0xFF334155), height: 12),
                  _buildCompactSwitch(
                    title: 'QuickJS JavaScript Engine (run_script)',
                    subtitle: 'Executes Google Apps Script JS for complex data cleaning',
                    value: _quickJsEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => setState(() => _quickJsEnabled = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 5. Copilot Display & Direct Execution Mode
            _buildCompactSection(
              title: 'Copilot Display & Auto-Execute',
              icon: Icons.view_headline_rounded,
              color: Colors.cyanAccent,
              child: Column(
                children: [
                  _buildCompactSwitch(
                    title: 'Copilot Bottom Sheet Modal',
                    subtitle: 'When OFF, Copilot stays embedded in Top Drawer mini view',
                    value: _useBottomSheet,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) => setState(() => _useBottomSheet = val),
                  ),
                  const Divider(color: Color(0xFF334155), height: 12),
                  _buildCompactSwitch(
                    title: 'Direct Auto-Execute Pipeline',
                    subtitle: 'Automatically applies AI pipeline actions without confirmation',
                    value: _autoExecutePipeline,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) => setState(() => _autoExecutePipeline = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 5. System Prompt Override
            _buildCompactSection(
              title: 'Custom Prompt Tuning (Optional)',
              icon: Icons.tune,
              color: Colors.blueAccent,
              child: SizedBox(
                height: 70,
                child: TextField(
                  controller: _customPromptController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(8),
                    hintText: 'Add custom rules (e.g. Always format headers in Bold Navy Blue...)',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF0B132B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Bottom Save Button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: _saveSettings,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  'SAVE SETTINGS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildCompactSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[400], fontSize: 10.5),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
