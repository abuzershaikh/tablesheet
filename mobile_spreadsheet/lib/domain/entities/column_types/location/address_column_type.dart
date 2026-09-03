import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Address column type - for physical addresses
class AddressColumnType extends ColumnType {
  const AddressColumnType() : super(
    id: 'address',
    name: 'Address',
    description: 'Physical addresses',
    icon: Icons.location_on,
  );
  
  @override
  bool validate(dynamic value) {
    // Addresses can be any string
    return true;
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    if (value is Map) {
      // If address is stored as structured data
      final street = value['street'] ?? '';
      final city = value['city'] ?? '';
      final state = value['state'] ?? '';
      final zip = value['zip'] ?? '';
      final country = value['country'] ?? '';
      
      return [street, city, state, zip, country]
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    
    return value.toString();
  }
  
  @override
  dynamic parse(String input) {
    return input;
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    return Column(
      children: [
        TextField(
          controller: TextEditingController(text: initialValue?.toString() ?? ''),
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Address',
            hintText: 'Enter full address',
            prefixIcon: Icon(Icons.home),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Get current location
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Current Location'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Open map
                },
                icon: const Icon(Icons.map),
                label: const Text('View Map'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  @override
  dynamic get defaultValue => '';
  
  @override
  Color get iconColor => Colors.red;
}
