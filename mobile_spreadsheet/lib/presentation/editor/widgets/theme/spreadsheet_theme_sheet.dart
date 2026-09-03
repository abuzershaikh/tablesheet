import 'package:flutter/material.dart';
import '../../../../domain/entities/theme/spreadsheet_theme_config.dart';
import '../../../../domain/entities/theme/spreadsheet_theme_presets.dart';

/// Modal Bottom Sheet for Customizing Spreadsheet Header & Sheet Themes
class SpreadsheetThemeSheet extends StatefulWidget {
  final SpreadsheetThemeConfig initialConfig;
  final ValueChanged<SpreadsheetThemeConfig> onApply;

  const SpreadsheetThemeSheet({
    Key? key,
    required this.initialConfig,
    required this.onApply,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required SpreadsheetThemeConfig initialConfig,
    required ValueChanged<SpreadsheetThemeConfig> onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpreadsheetThemeSheet(
        initialConfig: initialConfig,
        onApply: onApply,
      ),
    );
  }

  @override
  State<SpreadsheetThemeSheet> createState() => _SpreadsheetThemeSheetState();
}

class _SpreadsheetThemeSheetState extends State<SpreadsheetThemeSheet> {
  late SpreadsheetThemeConfig _tempConfig;
  late bool _isHeaderOnly;

  final List<Color> _swatchColors = const [
    Color(0xFFF5F5F5), Color(0xFF18181B), Color(0xFF1E293B),
    Color(0xFF047857), Color(0xFF0D9488), Color(0xFF1E3A8A),
    Color(0xFF2563EB), Color(0xFF6D28D9), Color(0xFF991B1B),
    Color(0xFFDC2626), Color(0xFFD97706), Color(0xFF059669),
    Color(0xFFE11D48), Color(0xFF7C3AED), Color(0xFF475569),
    Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _tempConfig = widget.initialConfig;
    _isHeaderOnly = widget.initialConfig.isHeaderOnly;
  }

  void _selectPreset(ThemePresetItem item) {
    setState(() {
      if (_isHeaderOnly) {
        _tempConfig = _tempConfig.copyWith(
          presetId: item.id,
          headerBgColor: item.config.headerBgColor,
          headerTextColor: item.config.headerTextColor,
          borderColor: item.config.borderColor,
          isHeaderOnly: true,
        );
      } else {
        _tempConfig = item.config.copyWith(isHeaderOnly: false);
      }
    });
    widget.onApply(_tempConfig);
  }

  void _showColorPicker({
    required String title,
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _swatchColors.map((color) {
            final isSelected = color.value == currentColor.value;
            return GestureDetector(
              onTap: () {
                onColorSelected(color);
                Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[400]!,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePresets = _isHeaderOnly
        ? SpreadsheetThemePresets.headerOnlyPresets
        : SpreadsheetThemePresets.fullSheetPresets;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle & Title
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.palette, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Theme Customization',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scope Switcher (Header Only vs Full Sheet)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isHeaderOnly = true;
                        _tempConfig = _tempConfig.copyWith(isHeaderOnly: true);
                      });
                      widget.onApply(_tempConfig);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isHeaderOnly ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isHeaderOnly
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Header Only',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isHeaderOnly ? Colors.blue : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isHeaderOnly = false;
                        _tempConfig = _tempConfig.copyWith(isHeaderOnly: false);
                      });
                      widget.onApply(_tempConfig);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isHeaderOnly ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isHeaderOnly
                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Full Sheet Theme',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: !_isHeaderOnly ? Colors.blue : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Miniature Grid Preview Card
          _buildLivePreviewCard(),
          const SizedBox(height: 16),

          // Scrollable Content Options
          Expanded(
            child: ListView(
              children: [
                // Preset Theme Gallery Section
                const Text(
                  'PRESET THEMES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: activePresets.length,
                    itemBuilder: (context, index) {
                      final item = activePresets[index];
                      final isSelected = _tempConfig.presetId == item.id;

                      return GestureDetector(
                        onTap: () => _selectPreset(item),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[50] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: item.config.headerBgColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.blue[900] : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Custom Color Selectors
                const Text(
                  'CUSTOM COLOR PALETTE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Header Bg Color Tile
                _buildColorTile(
                  title: 'Header Background',
                  color: _tempConfig.headerBgColor,
                  onTap: () {
                    _showColorPicker(
                      title: 'Pick Header Background Color',
                      currentColor: _tempConfig.headerBgColor,
                      onColorSelected: (col) {
                        setState(() {
                          final isDark = col.computeLuminance() < 0.4;
                          _tempConfig = _tempConfig.copyWith(
                            headerBgColor: col,
                            headerTextColor: isDark ? Colors.white : Colors.black87,
                            presetId: 'custom',
                          );
                        });
                        widget.onApply(_tempConfig);
                      },
                    );
                  },
                ),

                if (!_isHeaderOnly) ...[
                  _buildColorTile(
                    title: 'Row Header Background',
                    color: _tempConfig.rowHeaderBgColor,
                    onTap: () {
                      _showColorPicker(
                        title: 'Pick Row Header Color',
                        currentColor: _tempConfig.rowHeaderBgColor,
                        onColorSelected: (col) {
                          setState(() {
                            final isDark = col.computeLuminance() < 0.4;
                            _tempConfig = _tempConfig.copyWith(
                              rowHeaderBgColor: col,
                              rowHeaderTextColor: isDark ? Colors.white : Colors.black87,
                              presetId: 'custom',
                            );
                          });
                          widget.onApply(_tempConfig);
                        },
                      );
                    },
                  ),
                  _buildColorTile(
                    title: 'Grid Cell Background',
                    color: _tempConfig.gridBgColor,
                    onTap: () {
                      _showColorPicker(
                        title: 'Pick Grid Background Color',
                        currentColor: _tempConfig.gridBgColor,
                        onColorSelected: (col) {
                          setState(() {
                            _tempConfig = _tempConfig.copyWith(
                              gridBgColor: col,
                              presetId: 'custom',
                            );
                          });
                          widget.onApply(_tempConfig);
                        },
                      );
                    },
                  ),
                  _buildColorTile(
                    title: 'Grid Lines & Borders',
                    color: _tempConfig.borderColor,
                    onTap: () {
                      _showColorPicker(
                        title: 'Pick Border Color',
                        currentColor: _tempConfig.borderColor,
                        onColorSelected: (col) {
                          setState(() {
                            _tempConfig = _tempConfig.copyWith(
                              borderColor: col,
                              presetId: 'custom',
                            );
                          });
                          widget.onApply(_tempConfig);
                        },
                      );
                    },
                  ),
                  _buildColorTile(
                    title: 'Selection Highlight',
                    color: _tempConfig.selectionColor,
                    onTap: () {
                      _showColorPicker(
                        title: 'Pick Selection Highlight Color',
                        currentColor: _tempConfig.selectionColor,
                        onColorSelected: (col) {
                          setState(() {
                            _tempConfig = _tempConfig.copyWith(
                              selectionColor: col,
                              presetId: 'custom',
                            );
                          });
                          widget.onApply(_tempConfig);
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Reset Default Button
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _tempConfig = SpreadsheetThemeConfig.defaultTheme;
                });
                widget.onApply(_tempConfig);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restored default theme'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Restore Default Excel Theme'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final cfg = _tempConfig;

    final headerBg = cfg.headerBgColor;
    final headerText = cfg.headerTextColor;
    final rowBg = cfg.isHeaderOnly ? const Color(0xFFF5F5F5) : cfg.rowHeaderBgColor;
    final rowText = cfg.isHeaderOnly ? const Color(0xFF212121) : cfg.rowHeaderTextColor;
    final gridBg = cfg.isHeaderOnly ? const Color(0xFFFFFFFF) : cfg.gridBgColor;
    final borderCol = cfg.borderColor;
    final selBg = cfg.isHeaderOnly ? const Color(0xFFE3F2FD) : cfg.selectionColor;
    final accentCol = cfg.accentColor;

    final isGridDark = gridBg.computeLuminance() < 0.4;
    final cellTextColor = isGridDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: gridBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          // Header Row (Col A, Col B, Col C)
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: borderCol)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.apps, size: 14, color: headerText.withOpacity(0.7)),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: borderCol)),
                    ),
                    alignment: Alignment.center,
                    child: Text('A', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: headerText)),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: borderCol)),
                    ),
                    alignment: Alignment.center,
                    child: Text('B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: headerText)),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text('C', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: headerText)),
                  ),
                ),
              ],
            ),
          ),

          // Row 1
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  color: rowBg,
                  alignment: Alignment.center,
                  child: Text('1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: rowText)),
                ),
                // Cell A1 (Selected)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: selBg,
                      border: Border.all(color: accentCol, width: 2),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('100', style: TextStyle(fontSize: 12, color: cellTextColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                // Cell B1
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderCol))),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('Sales', style: TextStyle(fontSize: 12, color: cellTextColor)),
                  ),
                ),
                // Cell C1
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('500', style: TextStyle(fontSize: 12, color: cellTextColor)),
                  ),
                ),
              ],
            ),
          ),

          // Row 2
          Container(
            height: 32,
            child: Row(
              children: [
                Container(
                  width: 36,
                  color: rowBg,
                  alignment: Alignment.center,
                  child: Text('2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: rowText)),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderCol))),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('200', style: TextStyle(fontSize: 12, color: cellTextColor)),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border(right: BorderSide(color: borderCol))),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('Profit', style: TextStyle(fontSize: 12, color: cellTextColor)),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('800', style: TextStyle(fontSize: 12, color: cellTextColor)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorTile({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[400]!, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
