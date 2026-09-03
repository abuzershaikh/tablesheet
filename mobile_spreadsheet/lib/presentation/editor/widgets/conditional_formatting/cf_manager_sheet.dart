import 'package:flutter/material.dart';
import 'cf_rule_editor.dart';
import '../../../../../domain/services/conditional_formatting_service.dart';

class CFManagerSheet extends StatefulWidget {
  final String sheetId;
  const CFManagerSheet({Key? key, required this.sheetId}) : super(key: key);

  @override
  State<CFManagerSheet> createState() => _CFManagerSheetState();
}

class _CFManagerSheetState extends State<CFManagerSheet> {
  // In a real app, you would fetch the rules for widget.sheetId from the ConditionalFormattingService.
  List<Map<String, dynamic>> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    setState(() {
      _rules = ConditionalFormattingService.getRules(widget.sheetId);
    });
  }

  void _openRuleEditor([Map<String, dynamic>? rule]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CFRuleEditor(sheetId: widget.sheetId, existingRule: rule),
    ).then((_) => _loadRules());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 16),
        height: (MediaQuery.of(context).size.height * 0.7 - bottomInset).clamp(250.0, MediaQuery.of(context).size.height * 0.7),
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Conditional Formatting',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Expanded(
            child: _rules.isEmpty
                ? const Center(
                    child: Text(
                      'No rules applied.',
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _rules.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final rule = _rules.removeAt(oldIndex);
                        _rules.insert(newIndex, rule);
                        // Reassign priorities based on list order
                        for (int i = 0; i < _rules.length; i++) {
                           ConditionalFormattingService.reorderRule(widget.sheetId, _rules[i]['id'], _rules.length - i);
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      final rule = _rules[index];
                      return ListTile(
                        key: ValueKey(rule['id'] ?? index.toString()),
                        title: Text('Range: ${rule['range'] ?? "Unknown"}'),
                        subtitle: Text('Type: ${rule['type'] ?? "Unknown"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _rules.removeAt(index);
                              ConditionalFormattingService.removeRule(widget.sheetId, rule['id']);
                            });
                          },
                        ),
                        onTap: () => _openRuleEditor(rule),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                )
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: () => _openRuleEditor(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Rule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
