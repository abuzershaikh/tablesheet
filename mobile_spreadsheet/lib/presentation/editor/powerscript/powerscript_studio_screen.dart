import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/services/storage/powerscript_storage.dart';
import '../../../domain/services/storage/sheet_data_storage.dart';
import '../../../domain/services/super_engine/ffi_bridge.dart';
import '../../../domain/services/super_engine/formula_utils.dart';

class PowerScriptStudioScreen extends StatefulWidget {
  final String sheetId;
  final String spreadsheetName;
  final VoidCallback? onSheetUpdated;

  const PowerScriptStudioScreen({
    Key? key,
    required this.sheetId,
    required this.spreadsheetName,
    this.onSheetUpdated,
  }) : super(key: key);

  @override
  State<PowerScriptStudioScreen> createState() => _PowerScriptStudioScreenState();
}

class _PowerScriptStudioScreenState extends State<PowerScriptStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PowerScriptModel> _scripts = [];
  bool _isLoading = true;

  // Editor State
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  String _currentScriptId = '';
  String _consoleOutput = '';
  bool _isExecuting = false;
  DateTime? _lastRunAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: 'My Custom Script');
    _codeController = TextEditingController(text: _defaultCodeSnippet);
    _loadScripts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  static const String _defaultCodeSnippet = '''// PowerScript Studio (Sheet Bound JS Engine)
function main() {
    var sheet = SpreadsheetApp.getActiveSheet();
    sheet.getRange("A1").setValue("Hello from PowerScript!");
    sheet.getRange("A1").setBackground("#107C41"); // Excel Green
    console.log("Successfully updated cell A1!");
}

main();''';

  Future<void> _loadScripts() async {
    setState(() => _isLoading = true);
    final loaded = await PowerScriptStorage.getScripts(widget.sheetId);
    if (mounted) {
      setState(() {
        _scripts = loaded;
        _isLoading = false;
      });
    }
  }

  void _openEditorWithScript(PowerScriptModel script) {
    setState(() {
      _currentScriptId = script.id;
      _nameController.text = script.name;
      _codeController.text = script.code;
      _consoleOutput = 'Loaded script "${script.name}"';
      _lastRunAt = script.lastRunAt;
    });
    _tabController.animateTo(1);
  }

  void _createNewScript() {
    final newId = 'script_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _currentScriptId = newId;
      _nameController.text = 'New Custom Macro ${_scripts.length + 1}';
      _codeController.text = _defaultCodeSnippet;
      _consoleOutput = 'Created new script draft';
      _lastRunAt = null;
    });
    _tabController.animateTo(1);
  }

  Future<void> _saveCurrentScript() async {
    final name = _nameController.text.trim().isEmpty ? 'Untitled Script' : _nameController.text.trim();
    final code = _codeController.text;
    final id = _currentScriptId.isEmpty ? 'script_${DateTime.now().millisecondsSinceEpoch}' : _currentScriptId;

    final model = PowerScriptModel(
      id: id,
      name: name,
      code: code,
      spreadsheetId: widget.sheetId,
      createdAt: DateTime.now(),
      lastRunAt: _lastRunAt,
    );

    await PowerScriptStorage.saveScript(widget.sheetId, model);
    NativeEngine.registerJsMacro(name, code);
    await _loadScripts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Saved "$name" to Sheet'),
            ],
          ),
          backgroundColor: const Color(0xFF107C41),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _runCurrentScript() async {
    setState(() {
      _isExecuting = true;
      _consoleOutput = '▶ Executing script...';
    });

    final stopwatch = Stopwatch()..start();
    try {
      final code = _codeController.text;
      final rawResult = await NativeEngine.evalJsScriptAsync(code);
      stopwatch.stop();

      final now = DateTime.now();
      
      String parsedResult = '';
      String consoleLogs = '';
      try {
        final decoded = jsonDecode(rawResult) as Map<String, dynamic>;
        if (decoded.containsKey('error')) {
            parsedResult = 'Error: ${decoded['error']}';
        } else {
            parsedResult = decoded['result']?.toString() ?? 'undefined';
        }
        consoleLogs = decoded['console']?.toString() ?? '';
      } catch (e) {
        parsedResult = rawResult;
      }
      
      // If there are console logs, append them to the result
      String finalOutput = '[SUCCESS] Done in ${stopwatch.elapsedMilliseconds}ms';
      if (consoleLogs.isNotEmpty) {
        finalOutput += '\n\nConsole:\n$consoleLogs';
      }
      if (parsedResult.isNotEmpty && parsedResult != "undefined") {
        finalOutput += '\n\nResult: $parsedResult';
      }

      // Fetch the updated grid and save it to file
      final rawGridJson = NativeEngine.getRawGrid();
      final Map<String, dynamic> rawGrid = jsonDecode(rawGridJson);
      
      // Load existing cell data to merge
      final currentData = await SheetDataStorage.loadCellData(widget.sheetId) ?? {};
      
      // Merge new data
      int mergedCount = 0;
      rawGrid.forEach((cellRef, rawText) {
          final coords = FormulaUtils.parseCellRef(cellRef);
          if (coords != null) {
              final key = '${coords.$1}:${coords.$2}';
              currentData[key] = rawText.toString();
              mergedCount++;
          }
      });
      
      // Save updated data
      await SheetDataStorage.saveCellData(widget.sheetId, currentData);

      if (mounted) {
        setState(() {
          _isExecuting = false;
          _lastRunAt = now;
          _consoleOutput = finalOutput;
        });
      }

      widget.onSheetUpdated?.call();

      // If saved, update lastRunAt
      if (_currentScriptId.isNotEmpty) {
        final idx = _scripts.indexWhere((s) => s.id == _currentScriptId);
        if (idx >= 0) {
          final updated = _scripts[idx].copyWith(lastRunAt: now);
          await PowerScriptStorage.saveScript(widget.sheetId, updated);
          await _loadScripts();
        }
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isExecuting = false;
          _consoleOutput = '[ERROR] ${e.toString()}';
        });
      }
    }
  }

  Future<void> _deleteScript(PowerScriptModel script) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Script?'),
        content: Text('Are you sure you want to delete "${script.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PowerScriptStorage.deleteScript(widget.sheetId, script.id);
      await _loadScripts();
    }
  }

  void _insertSnippet(String snippet) {
    final text = _codeController.text;
    final selection = _codeController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, snippet);
      _codeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + snippet.length),
      );
    } else {
      _codeController.text += '\n$snippet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900 IDE theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.code_rounded, color: Color(0xFF107C41), size: 22),
                SizedBox(width: 8),
                Text(
                  'PowerScript Studio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Linked to: ${widget.spreadsheetName} (${widget.sheetId.substring(0, widget.sheetId.length > 8 ? 8 : widget.sheetId.length)})',
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF107C41),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(
              icon: Icon(Icons.list_alt_rounded, size: 18),
              text: 'My Scripts',
            ),
            Tab(
              icon: Icon(Icons.integration_instructions_rounded, size: 18),
              text: 'Script Editor',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSavedScriptsTab(),
          _buildEditorTab(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: Saved Scripts List
  // -------------------------------------------------------------
  Widget _buildSavedScriptsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF107C41)),
      );
    }

    return Column(
      children: [
        // Header Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C41).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.javascript_rounded, color: Color(0xFF107C41), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sheet Automation Scripts',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Scripts in this list run directly on this spreadsheet.',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createNewScript,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Script', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C41),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: _scripts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _scripts.length,
                  itemBuilder: (context, index) {
                    final script = _scripts[index];
                    return _buildScriptCard(script);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code_off_rounded, size: 56, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),
          const Text(
            'No Scripts Saved Yet',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first JavaScript macro to automate this sheet',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createNewScript,
            icon: const Icon(Icons.add),
            label: const Text('Create New Script'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF107C41),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard(PowerScriptModel script) {
    final lastRunStr = script.lastRunAt != null
        ? 'Last run: ${script.lastRunAt!.hour}:${script.lastRunAt!.minute.toString().padLeft(2, '0')}'
        : 'Not run yet';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    script.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _deleteScript(script),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              lastRunStr,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditorWithScript(script),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Edit Code', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    _openEditorWithScript(script);
                    await _runCurrentScript();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Run on Sheet', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: Script Editor Tab
  // -------------------------------------------------------------
  Widget _buildEditorTab() {
    return Column(
      children: [
        // Editor Control Bar
        Container(
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Script Name...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Save Button
              IconButton(
                icon: const Icon(Icons.save_rounded, color: Colors.amber, size: 22),
                tooltip: 'Save Script',
                onPressed: _saveCurrentScript,
              ),
              const SizedBox(width: 4),
              // Run Button
              ElevatedButton.icon(
                onPressed: _isExecuting ? null : _runCurrentScript,
                icon: _isExecuting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_isExecuting ? 'Running...' : 'Run'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C41),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Quick Snippets Toolbar
        Container(
          height: 38,
          color: const Color(0xFF0F172A),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              _buildSnippetChip('SpreadsheetApp.getActiveSheet()'),
              _buildSnippetChip('sheet.getRange("A1")'),
              _buildSnippetChip('.setValue("Val")'),
              _buildSnippetChip('.getValue()'),
              _buildSnippetChip('.setBackground("#FF0000")'),
              _buildSnippetChip('fetch("URL")'),
              _buildSnippetChip('console.log()'),
            ],
          ),
        ),

        // Main Code Editor Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF020617), // Deep dark black/slate
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line numbers gutter
                Container(
                  width: 32,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: Column(
                    children: List.generate(
                      25,
                      (idx) => Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.white10),
                // Code Input Field
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      hintText: '// Type JavaScript code here...',
                      hintStyle: TextStyle(color: Colors.white24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Output & Console Bar
        Container(
          width: double.infinity,
          height: 100,
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Console Output',
                    style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 20, width: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      icon: const Icon(Icons.copy_rounded, color: Colors.white54),
                      tooltip: 'Copy output',
                      onPressed: _consoleOutput.isEmpty ? null : () {
                        Clipboard.setData(ClipboardData(text: _consoleOutput));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 20, width: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      icon: const Icon(Icons.paste_rounded, color: Colors.white54),
                      tooltip: 'Paste to editor',
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null && data!.text!.isNotEmpty) {
                          final text = _codeController.text;
                          final sel = _codeController.selection;
                          final newText = text.replaceRange(sel.start, sel.end, data.text!);
                          _codeController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(offset: sel.start + data.text!.length),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 20, width: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      icon: const Icon(Icons.clear_all_rounded, color: Colors.white54),
                      tooltip: 'Clear all',
                      onPressed: () => setState(() {
                        _codeController.clear();
                        _consoleOutput = '';
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _consoleOutput.isEmpty ? 'Ready. Tap "Run" to test on sheet.' : _consoleOutput,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSnippetChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace'),
        ),
        backgroundColor: const Color(0xFF1E293B),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
        onPressed: () => _insertSnippet(label),
      ),
    );
  }
}
