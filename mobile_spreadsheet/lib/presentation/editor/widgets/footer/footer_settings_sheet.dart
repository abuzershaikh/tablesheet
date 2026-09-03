import 'package:flutter/material.dart';
import '../../../../domain/entities/sheet_entity.dart';
import '../../../../domain/entities/theme/spreadsheet_theme_config.dart';
import '../../editor_controller.dart';

class FooterSettingsSheet extends StatefulWidget {
  final SheetFooterConfig initialConfig;
  final SpreadsheetThemeConfig themeConfig;
  final int columnCount;
  final ValueChanged<SheetFooterConfig> onApply;

  const FooterSettingsSheet({
    Key? key,
    required this.initialConfig,
    required this.themeConfig,
    this.columnCount = 26,
    required this.onApply,
  }) : super(key: key);

  static void show(BuildContext context, {
    required SheetFooterConfig initialConfig,
    required SpreadsheetThemeConfig themeConfig,
    int columnCount = 26,
    required ValueChanged<SheetFooterConfig> onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FooterSettingsSheet(
          initialConfig: initialConfig,
          themeConfig: themeConfig,
          columnCount: columnCount,
          onApply: onApply,
        ),
      ),
    );
  }

  @override
  State<FooterSettingsSheet> createState() => _FooterSettingsSheetState();
}

class _FooterSettingsSheetState extends State<FooterSettingsSheet> {
  late bool _enabled;
  late String _type;
  late int _targetColumnIndex;
  late TextEditingController _labelController;

  final List<String> _types = ['sum', 'avg', 'count', 'min', 'max'];
  final Map<String, String> _typeLabels = {
    'sum': 'Sum',
    'avg': 'Average',
    'count': 'Count',
    'min': 'Minimum',
    'max': 'Maximum',
  };

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialConfig.enabled;
    _type = widget.initialConfig.type;
    _targetColumnIndex = widget.initialConfig.targetColumnIndex ?? 0;
    _labelController = TextEditingController(text: widget.initialConfig.label);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _applyAndClose() {
    final newConfig = widget.initialConfig.copyWith(
      enabled: _enabled,
      type: _type,
      targetColumnIndex: _targetColumnIndex,
      label: _labelController.text.trim().isEmpty ? 'Total' : _labelController.text.trim(),
    );
    widget.onApply(newConfig);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final primary = widget.themeConfig.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.table_rows_rounded),
                const SizedBox(width: 8),
                Text(
                  'Summary Footer Settings',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _enabled,
                  activeColor: primary,
                  onChanged: (val) {
                    setState(() {
                      _enabled = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_enabled) ...[
            // Body
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target Column', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _targetColumnIndex.clamp(0, widget.columnCount - 1),
                        isExpanded: true,
                        items: List.generate(widget.columnCount, (index) {
                          final colLetter = EditorController.getColumnLetter(index);
                          return DropdownMenuItem<int>(
                            value: index,
                            child: Text('Column $colLetter (Index $index)'),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _targetColumnIndex = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Calculation Type', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = _type == type;
                      return ChoiceChip(
                        label: Text(_typeLabels[type]!),
                        selected: selected,
                        selectedColor: primary.withOpacity(0.2),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _type = type;
                              if (_labelController.text == 'Total' || 
                                  _types.any((t) => _typeLabels[t] == _labelController.text)) {
                                _labelController.text = _typeLabels[type]!;
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  Text('Label Text', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _labelController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Grand Total',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Footer buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _applyAndClose,
                    child: const Text('APPLY'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
