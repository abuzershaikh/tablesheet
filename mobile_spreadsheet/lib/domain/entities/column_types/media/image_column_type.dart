import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Image column type - for image URLs or file paths
class ImageColumnType extends ColumnType {
  final bool allowMultiple;
  
  const ImageColumnType({
    this.allowMultiple = false,
  }) : super(
    id: 'image',
    name: 'Image',
    description: 'Image files or URLs',
    icon: Icons.image,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    if (allowMultiple && value is List) {
      return value.every((item) => _isValidImageUrl(item.toString()));
    }
    
    return _isValidImageUrl(value.toString());
  }
  
  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return true;
    // Check if it's a valid URL or file path
    return url.contains('http') || 
           url.endsWith('.jpg') || 
           url.endsWith('.jpeg') || 
           url.endsWith('.png') || 
           url.endsWith('.gif') || 
           url.endsWith('.webp');
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    if (allowMultiple && value is List) {
      return '${value.length} images';
    }
    
    return value.toString();
  }
  
  @override
  dynamic parse(String input) {
    if (allowMultiple) {
      return input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
        if (initialValue != null && initialValue.toString().isNotEmpty)
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: initialValue.toString().startsWith('http')
                ? Image.network(initialValue.toString(), fit: BoxFit.cover)
                : const Center(child: Icon(Icons.image, size: 64)),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement image picker
            onChanged('https://example.com/image.jpg');
          },
          icon: const Icon(Icons.upload),
          label: const Text('Upload Image'),
        ),
      ],
    );
  }
  
  @override
  dynamic get defaultValue => '';
  
  @override
  Color get iconColor => Colors.pink;
}
