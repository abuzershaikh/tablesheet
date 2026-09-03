import 'package:flutter/material.dart';
import '../base/column_type.dart';

/// Location column type - for GPS coordinates
class LocationColumnType extends ColumnType {
  const LocationColumnType() : super(
    id: 'location',
    name: 'Location',
    description: 'GPS coordinates (lat, lng)',
    icon: Icons.gps_fixed,
  );
  
  @override
  bool validate(dynamic value) {
    if (value == null) return true;
    
    if (value is Map) {
      final lat = value['lat'];
      final lng = value['lng'];
      if (lat is num && lng is num) {
        return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
      }
    }
    
    if (value is String && value.contains(',')) {
      final parts = value.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
        }
      }
    }
    
    return false;
  }
  
  @override
  String format(dynamic value) {
    if (value == null) return '';
    
    if (value is Map) {
      final lat = value['lat'];
      final lng = value['lng'];
      return '$lat, $lng';
    }
    
    return value.toString();
  }
  
  @override
  dynamic parse(String input) {
    final parts = input.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng};
      }
    }
    return null;
  }
  
  @override
  Widget getInputWidget({
    required dynamic initialValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    double? lat;
    double? lng;
    
    if (initialValue is Map) {
      lat = initialValue['lat']?.toDouble();
      lng = initialValue['lng']?.toDouble();
    }
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: TextEditingController(text: lat?.toString() ?? ''),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Latitude',
                  hintText: '0.0',
                ),
                onChanged: (value) {
                  final newLat = double.tryParse(value);
                  if (newLat != null) {
                    onChanged({'lat': newLat, 'lng': lng ?? 0.0});
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: lng?.toString() ?? ''),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Longitude',
                  hintText: '0.0',
                ),
                onChanged: (value) {
                  final newLng = double.tryParse(value);
                  if (newLng != null) {
                    onChanged({'lat': lat ?? 0.0, 'lng': newLng});
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Get current GPS location
            onChanged({'lat': 37.7749, 'lng': -122.4194});
          },
          icon: const Icon(Icons.my_location),
          label: const Text('Use Current Location'),
        ),
        if (lat != null && lng != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Open in maps
              },
              icon: const Icon(Icons.map),
              label: const Text('View on Map'),
            ),
          ),
      ],
    );
  }
  
  @override
  dynamic get defaultValue => {'lat': 0.0, 'lng': 0.0};
  
  @override
  Color get iconColor => Colors.brown;
}
