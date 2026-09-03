import 'package:flutter/material.dart';
import '../../../../domain/entities/column_types/base/column_type.dart';
import '../../../../domain/entities/column_types/text/text_column_type.dart';
import '../../../../domain/entities/column_types/number/number_column_type.dart';
import '../../../../domain/entities/column_types/number/amount_column_type.dart';
import '../../../../domain/entities/column_types/date/date_column_type.dart';
import '../../../../domain/entities/column_types/date/time_column_type.dart';
import '../../../../domain/entities/column_types/selection/checkbox_column_type.dart';
import '../../../../domain/entities/column_types/selection/selectable_column_type.dart';
import '../../../../domain/entities/column_types/media/image_column_type.dart';
import '../../../../domain/entities/column_types/media/audio_column_type.dart';
import '../../../../domain/entities/column_types/media/pdf_column_type.dart';
import '../../../../domain/entities/column_types/contact/phone_column_type.dart';
import '../../../../domain/entities/column_types/contact/link_column_type.dart';
import '../../../../domain/entities/column_types/location/address_column_type.dart';
import '../../../../domain/entities/column_types/location/location_column_type.dart';
import 'column_type_selector.dart';

// ─── Clean Solid Colors ──────────────────────────────────────────────
const _kPrimary = Color(0xFF1E88E5);      // Solid Blue
const _kPrimaryDark = Color(0xFF1565C0);  // Dark Blue
const _kSuccess = Color(0xFF2E7D32);      // Solid Green
const _kTextDark = Color(0xFF212121);     // High Contrast Dark
const _kTextGrey = Color(0xFF757575);     // Medium Grey
const _kBorderColor = Color(0xFFCCCCCC);  // Crisp Border

/// Clean, Native & Solid Column Properties Bottom Sheet
class ColumnPropertiesSheet extends StatefulWidget {
  final int columnIndex;
  final String? columnName;
  final ColumnType? columnType;
  final double columnWidth;
  final Function(String name, ColumnType type, double width)? onSave;
  final VoidCallback? onInsertLeft;
  final VoidCallback? onInsertRight;
  final VoidCallback? onCopy;
  final VoidCallback? onAutoFill;

  const ColumnPropertiesSheet({
    Key? key,
    required this.columnIndex,
    this.columnName,
    this.columnType,
    this.columnWidth = 120.0,
    this.onSave,
    this.onInsertLeft,
    this.onInsertRight,
    this.onCopy,
    this.onAutoFill,
  }) : super(key: key);

  @override
  State<ColumnPropertiesSheet> createState() => _ColumnPropertiesSheetState();

  static Future<void> show(
    BuildContext context, {
    required int columnIndex,
    String? columnName,
    ColumnType? columnType,
    double columnWidth = 120.0,
    Function(String, ColumnType, double)? onSave,
    VoidCallback? onInsertLeft,
    VoidCallback? onInsertRight,
    VoidCallback? onCopy,
    VoidCallback? onAutoFill,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ColumnPropertiesSheet(
        columnIndex: columnIndex,
        columnName: columnName,
        columnType: columnType,
        columnWidth: columnWidth,
        onSave: onSave,
        onInsertLeft: onInsertLeft,
        onInsertRight: onInsertRight,
        onCopy: onCopy,
        onAutoFill: onAutoFill,
      ),
    );
  }
}

class _ColumnPropertiesSheetState extends State<ColumnPropertiesSheet> {
  late TextEditingController _nameController;
  late TextEditingController _widthController;
  final TextEditingController _optionController = TextEditingController();
  late ColumnType _selectedType;
  late double _width;
  List<String> _dropdownOptions = [];
  bool _isBold = false;
  bool _isItalic = false;
  TextAlign _alignment = TextAlign.left;
  bool _visibleInTable = true;

  final List<ColumnType> _availableTypes = const [
    TextColumnType(),
    NumberColumnType(),
    AmountColumnType(),
    DateColumnType(),
    TimeColumnType(),
    CheckboxColumnType(),
    SelectableColumnType(options: ['Option 1', 'Option 2', 'Option 3']),
    ImageColumnType(),
    AudioColumnType(),
    PdfColumnType(),
    PhoneColumnType(),
    LinkColumnType(),
    AddressColumnType(),
    LocationColumnType(),
  ];

  static String _getColumnLetter(int index) {
    String letter = '';
    int position = index;
    while (position >= 0) {
      letter = String.fromCharCode(65 + (position % 26)) + letter;
      position = (position ~/ 26) - 1;
    }
    return letter;
  }

  @override
  void initState() {
    super.initState();
    final initialName = (widget.columnName != null && widget.columnName!.trim().isNotEmpty)
        ? widget.columnName!
        : _getColumnLetter(widget.columnIndex);
    _nameController = TextEditingController(text: initialName);
    _selectedType = widget.columnType ?? const TextColumnType();
    _width = widget.columnWidth;
    _widthController = TextEditingController(text: _width.round().toString());

    if (_selectedType is SelectableColumnType) {
      _dropdownOptions = List.from((_selectedType as SelectableColumnType).options);
    } else {
      _dropdownOptions = ['Option 1', 'Option 2', 'Option 3'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  void _updateWidth(double newWidth) {
    setState(() {
      _width = newWidth.clamp(60.0, 500.0);
      _widthController.text = _width.round().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle Bar ──
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD6D6D6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 10),

          // ── Title Bar with Solid Primary Action ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: _kTextDark, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Column Properties',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kTextDark,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _saveProperties,
                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                  label: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Body ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Column Name Section
                  _buildLabel('COLUMN NAME', Icons.title),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kPrimary, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: _kTextGrey, size: 20),
                        onPressed: () => _nameController.clear(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 2. Column Type Selector (Solid Individual Colors)
                  _buildLabel('COLUMN TYPE', Icons.category),
                  const SizedBox(height: 10),
                  ColumnTypeSelector(
                    availableTypes: _availableTypes,
                    selectedType: _selectedType,
                    onTypeSelected: (type) {
                      setState(() {
                        _selectedType = type;
                        if (type is SelectableColumnType && _dropdownOptions.isEmpty) {
                          _dropdownOptions = List.from(type.options);
                        }
                      });
                    },
                  ),

                  // Dropdown Options Editor (if Selectable)
                  if (_selectedType is SelectableColumnType) ...[
                    const SizedBox(height: 20),
                    _buildLabel('DROPDOWN OPTIONS', Icons.list),
                    const SizedBox(height: 8),
                    _buildDropdownSection(),
                  ],

                  const SizedBox(height: 22),

                  // 3. Column Width Section (Slider + Exact Number Input)
                  _buildLabel('COLUMN WIDTH (PX)', Icons.straighten),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Width:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kTextDark)),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _widthController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kPrimaryDark),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: _kPrimary, width: 2),
                                  ),
                                ),
                                onSubmitted: (val) {
                                  final parsed = double.tryParse(val);
                                  if (parsed != null) _updateWidth(parsed);
                                },
                              ),
                            ),
                            const Spacer(),
                            // Quick Increment/Decrement Buttons
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: _kPrimary, size: 28),
                              onPressed: () => _updateWidth(_width - 10),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: _kPrimary, size: 28),
                              onPressed: () => _updateWidth(_width + 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _width,
                          min: 60,
                          max: 500,
                          divisions: 44,
                          activeColor: _kPrimary,
                          inactiveColor: const Color(0xFFE0E0E0),
                          onChanged: (val) => _updateWidth(val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 4. Text Styles
                  _buildLabel('TEXT ALIGNMENT & STYLE', Icons.format_paint),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SolidIconButton(
                        icon: Icons.format_bold,
                        isSelected: _isBold,
                        onTap: () => setState(() => _isBold = !_isBold),
                      ),
                      const SizedBox(width: 8),
                      _SolidIconButton(
                        icon: Icons.format_italic,
                        isSelected: _isItalic,
                        onTap: () => setState(() => _isItalic = !_isItalic),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 32, color: _kBorderColor),
                      const SizedBox(width: 12),
                      _SolidIconButton(
                        icon: Icons.format_align_left,
                        isSelected: _alignment == TextAlign.left,
                        onTap: () => setState(() => _alignment = TextAlign.left),
                      ),
                      const SizedBox(width: 8),
                      _SolidIconButton(
                        icon: Icons.format_align_center,
                        isSelected: _alignment == TextAlign.center,
                        onTap: () => setState(() => _alignment = TextAlign.center),
                      ),
                      const SizedBox(width: 8),
                      _SolidIconButton(
                        icon: Icons.format_align_right,
                        isSelected: _alignment == TextAlign.right,
                        onTap: () => setState(() => _alignment = TextAlign.right),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 5. Quick Actions List
                  _buildLabel('COLUMN ACTIONS', Icons.settings),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.arrow_back, color: _kPrimary, size: 20),
                          ),
                          title: const Text('Insert Column on Left', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right, color: _kTextGrey),
                          onTap: () {
                            widget.onInsertLeft?.call();
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(Icons.arrow_forward, color: _kSuccess, size: 20),
                          ),
                          title: const Text('Insert Column on Right', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right, color: _kTextGrey),
                          onTap: () {
                            widget.onInsertRight?.call();
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.copy, color: _kPrimary, size: 20),
                          ),
                          title: const Text('Copy Column', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right, color: _kTextGrey),
                          onTap: () {
                            widget.onCopy?.call();
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(Icons.auto_fix_high, color: _kSuccess, size: 20),
                          ),
                          title: const Text('AutoFill Column Right', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right, color: _kTextGrey),
                          onTap: () {
                            widget.onAutoFill?.call();
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF3E0),
                            child: Icon(Icons.visibility, color: Colors.orange, size: 20),
                          ),
                          title: const Text('Visible in Table', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          value: _visibleInTable,
                          activeColor: _kPrimary,
                          onChanged: (val) => setState(() => _visibleInTable = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kPrimaryDark),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _kTextGrey,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _dropdownOptions.map((option) {
              return Chip(
                backgroundColor: const Color(0xFFE3F2FD),
                label: Text(option, style: const TextStyle(color: _kPrimaryDark, fontWeight: FontWeight.w600, fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16, color: _kPrimaryDark),
                onDeleted: () => setState(() => _dropdownOptions.remove(option)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _optionController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'New option name...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onSubmitted: _addOption,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _addOption(_optionController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addOption(String val) {
    final trimmed = val.trim();
    if (trimmed.isNotEmpty && !_dropdownOptions.contains(trimmed)) {
      setState(() {
        _dropdownOptions.add(trimmed);
        _optionController.clear();
      });
    }
  }

  void _saveProperties() {
    ColumnType typeToSave = _selectedType;
    if (_selectedType is SelectableColumnType) {
      typeToSave = SelectableColumnType(options: List.from(_dropdownOptions));
    }
    widget.onSave?.call(_nameController.text, typeToSave, _width);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved properties for "${_nameController.text}"'),
        backgroundColor: _kSuccess,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SolidIconButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SolidIconButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _kPrimaryDark : const Color(0xFFCCCCCC),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : const Color(0xFF424242),
        ),
      ),
    );
  }
}
