import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../domain/services/conditional_formatting_service.dart';

class CFRuleEditor extends StatefulWidget {
  final String sheetId;
  final Map<String, dynamic>? existingRule;

  const CFRuleEditor({Key? key, required this.sheetId, this.existingRule}) : super(key: key);

  @override
  State<CFRuleEditor> createState() => _CFRuleEditorState();
}

class _CFRuleEditorState extends State<CFRuleEditor> {
  String _selectedType = 'Greater Than';
  final List<String> _ruleTypes = [
    'Greater Than', 'Contains', 'Blank', 'Custom Formula', 'Data Bar', 'Color Scale', 'Icon Set'
  ];

  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _value1Controller = TextEditingController();
  final TextEditingController _value2Controller = TextEditingController();

  Color _bgColor = const Color(0xFFD4EDDA);
  Color _textColor = Colors.black;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  
  // Data Bar Specific
  bool _isGradient = true;
  Color _positiveColor = Colors.blue;
  Color _negativeColor = Colors.red;

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      _rangeController.text = widget.existingRule!['range'] ?? '';
      _selectedType = widget.existingRule!['type'] ?? 'Greater Than';
      _value1Controller.text = widget.existingRule!['value1'] ?? '';
      _value2Controller.text = widget.existingRule!['value2'] ?? '';
    }
  }

  void _saveRule() {
    final Map<String, dynamic> ruleJson = {
      'id': widget.existingRule?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'sheetId': widget.sheetId.isEmpty ? 'Sheet1' : widget.sheetId,
      'range': _rangeController.text.trim(),
      'type': _selectedType,
      'value1': _value1Controller.text.trim(),
      'value2': _value2Controller.text.trim(),
      'style': {
        'bgColor': _bgColor.value.toRadixString(16),
        'textColor': _textColor.value.toRadixString(16),
        'bold': _isBold,
        'italic': _isItalic,
        'underline': _isUnderline,
      },
      'dataBar': _selectedType == 'Data Bar' ? {
        'isGradient': _isGradient,
        'positiveColor': _positiveColor.value.toRadixString(16),
        'negativeColor': _negativeColor.value.toRadixString(16),
      } : null,
    };
    
    final targetSheetId = widget.sheetId.isEmpty ? 'Sheet1' : widget.sheetId;
    ConditionalFormattingService.addRule(targetSheetId, ruleJson);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDataBar = _selectedType == 'Data Bar';
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
        height: (MediaQuery.of(context).size.height * 0.85 - bottomInset).clamp(300.0, MediaQuery.of(context).size.height * 0.85),
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingRule == null ? 'Create Rule' : 'Edit Rule',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildLabel('Apply to range'),
                TextField(
                  controller: _rangeController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., A1:C10',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabel('Format rules'),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _ruleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 16),
                if (!['Blank', 'Color Scale', 'Icon Set'].contains(_selectedType))
                  TextField(
                    controller: _value1Controller,
                    decoration: InputDecoration(
                      hintText: _selectedType == 'Custom Formula' ? '=A1>10' : 'Value or formula',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                const SizedBox(height: 24),
                if (isDataBar) ...[
                  _buildLabel('Data Bar Settings'),
                  SwitchListTile(
                    title: const Text('Gradient Fill'),
                    value: _isGradient,
                    onChanged: (val) => setState(() => _isGradient = val),
                  ),
                  // Additional color pickers for Data Bar would go here
                ] else ...[
                  _buildLabel('Formatting style'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ToggleButtons(
                          isSelected: [_isBold, _isItalic, _isUnderline],
                          onPressed: (index) {
                            setState(() {
                              if (index == 0) _isBold = !_isBold;
                              if (index == 1) _isItalic = !_isItalic;
                              if (index == 2) _isUnderline = !_isUnderline;
                            });
                          },
                          children: const [
                            Icon(Icons.format_bold),
                            Icon(Icons.format_italic),
                            Icon(Icons.format_underlined),
                          ],
                        ),
                        const Spacer(),
                        // Text Color Picker Stub
                        IconButton(
                          icon: const Icon(Icons.format_color_text),
                          color: _textColor,
                          onPressed: () {
                            setState(() => _textColor = Colors.blue); // Stub for color picker
                          },
                        ),
                        // Background Color Picker Stub
                        IconButton(
                          icon: const Icon(Icons.format_color_fill),
                          color: _bgColor,
                          onPressed: () {
                            setState(() => _bgColor = Colors.yellow); // Stub for color picker
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
              child: ElevatedButton(
                onPressed: _saveRule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}
