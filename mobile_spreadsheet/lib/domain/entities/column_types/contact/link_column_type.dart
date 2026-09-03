import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Link column type - for URLs and hyperlinks
class LinkColumnType extends ColumnType {
  const LinkColumnType() : super(
    id: 'link',
    name: 'Link',
    description: 'URLs and hyperlinks',
    icon: Icons.link,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    final str = value.toString();
    if (str.isEmpty) return true;
    
    // Basic URL validation
    return str.startsWith('http://') || 
           str.startsWith('https://') || 
           str.startsWith('www.') ||
           str.contains('.');
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
  
  @override
  dynamic parse(String input) {
    // Ensure URL has protocol
    if (input.isNotEmpty && !input.startsWith('http')) {
      return 'https://$input';
    }
    return input;
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: TextEditingController(text: initialValue?.toString() ?? ''),
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'URL',
            prefixIcon: Icon(Icons.link),
            hintText: 'https://example.com',
          ),
          onChanged: onChanged,
        ),
        if (initialValue != null && initialValue.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Open URL in browser
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Link'),
            ),
          ),
      ],
    );
  }
  
  @override
  dynamic get defaultValue => '';
  
  @override
  Color get iconColor => Colors.lightBlue;
}
