import 'package:flutter/material.dart';
import 'package:mobile_spreadsheet/domain/services/formatting_action_service.dart';

class FormattingBottomSheet extends StatelessWidget {
  final int minRow;
  final int minCol;
  final int maxRow;
  final int maxCol;
  final VoidCallback onFormattingApplied;

  const FormattingBottomSheet({
    Key? key,
    required this.minRow,
    required this.minCol,
    required this.maxRow,
    required this.maxCol,
    required this.onFormattingApplied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Format Selected Cells',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    FormattingActionService.clearFormat(
                        minRow, minCol, maxRow, maxCol);
                    onFormattingApplied();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear Format',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                const Text('Text Style',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconButton(
                      icon: Icons.format_bold,
                      label: 'Bold',
                      onTap: () {
                        FormattingActionService.applyFormat(
                            minRow, minCol, maxRow, maxCol, 'setFontWeight', 'bold');
                        onFormattingApplied();
                      },
                    ),
                    _buildIconButton(
                      icon: Icons.format_italic,
                      label: 'Italic',
                      onTap: () {
                        FormattingActionService.applyFormat(
                            minRow, minCol, maxRow, maxCol, 'setFontStyle', 'italic');
                        onFormattingApplied();
                      },
                    ),
                    _buildIconButton(
                      icon: Icons.format_underlined,
                      label: 'Underline',
                      onTap: () {
                        FormattingActionService.applyFormat(
                            minRow, minCol, maxRow, maxCol, 'setFontLine', 'underline');
                        onFormattingApplied();
                      },
                    ),
                    _buildIconButton(
                      icon: Icons.format_strikethrough,
                      label: 'Strike',
                      onTap: () {
                        FormattingActionService.applyFormat(
                            minRow, minCol, maxRow, maxCol, 'setFontLine', 'line-through');
                        onFormattingApplied();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Quick Table Styles',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildTableStyleOption(
                        name: 'Blue',
                        headerColor: const Color(0xFF4285F4),
                        headerText: '#FFFFFF',
                        oddColor: '#F8F9FA',
                        evenColor: '#FFFFFF',
                        onTap: () {
                          FormattingActionService.applyTableStyle(
                              minRow, minCol, maxRow, maxCol, 
                              '#4285F4', '#FFFFFF', '#F8F9FA', '#FFFFFF');
                          onFormattingApplied();
                          Navigator.pop(context);
                        },
                      ),
                      _buildTableStyleOption(
                        name: 'Green',
                        headerColor: const Color(0xFF34A853),
                        headerText: '#FFFFFF',
                        oddColor: '#F1F8F4',
                        evenColor: '#FFFFFF',
                        onTap: () {
                          FormattingActionService.applyTableStyle(
                              minRow, minCol, maxRow, maxCol, 
                              '#34A853', '#FFFFFF', '#F1F8F4', '#FFFFFF');
                          onFormattingApplied();
                          Navigator.pop(context);
                        },
                      ),
                      _buildTableStyleOption(
                        name: 'Dark',
                        headerColor: const Color(0xFF202124),
                        headerText: '#FFFFFF',
                        oddColor: '#3C4043',
                        evenColor: '#202124',
                        onTap: () {
                          FormattingActionService.applyTableStyle(
                              minRow, minCol, maxRow, maxCol, 
                              '#202124', '#FFFFFF', '#3C4043', '#202124');
                          onFormattingApplied();
                          Navigator.pop(context);
                        },
                      ),
                      _buildTableStyleOption(
                        name: 'Orange',
                        headerColor: const Color(0xFFF29900),
                        headerText: '#FFFFFF',
                        oddColor: '#FFF8E1',
                        evenColor: '#FFFFFF',
                        onTap: () {
                          FormattingActionService.applyTableStyle(
                              minRow, minCol, maxRow, maxCol, 
                              '#F29900', '#FFFFFF', '#FFF8E1', '#FFFFFF');
                          onFormattingApplied();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Colors',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.format_color_fill, size: 18),
                      label: const Text('Yellow Fill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[200],
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {
                        FormattingActionService.applyFormat(
                            minRow, minCol, maxRow, maxCol, 'setBackground', '#FFF59D');
                        onFormattingApplied();
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.format_color_text, size: 18),
                      label: const Text('Red Text'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        FormattingActionService.applyFormat(
                            minRow, minCol, maxRow, maxCol, 'setFontColor', '#EA4335');
                        onFormattingApplied();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.blueGrey[700]),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableStyleOption({
    required String name,
    required Color headerColor,
    required String headerText,
    required String oddColor,
    required String evenColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: headerColor.withOpacity(0.1),
          border: Border.all(color: headerColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: headerColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
